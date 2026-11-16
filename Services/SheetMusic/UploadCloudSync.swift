//
//  UploadCloudSync.swift
//  Re-Hearse_v1
//
//  Backs up converted uploads to the signed-in account and brings them to the account's other
//  devices (and back after a reinstall).
//
//  Rows: public.user_uploads (one per upload, same id as on the device that made it).
//  Files: private bucket user_sheets at <user id>/<upload id>/, compressed with raw DEFLATE:
//    input.pdf.z        the PDF the user picked
//    score.musicxml.z   the converted score; output.json is rebuilt from it
//    labels.json.z      note-name positions; labeled.pdf is redrawn from input.pdf + these
//    labeled.pdf.z      instead of labels.json.z, for uploads converted before labels were saved
//  The server enforces 10 uploads per user (trigger), 10 MB per file (bucket) and owner-only
//  access (RLS). Only converted uploads sync; failed ones stay on the device.
//

import Foundation
import Supabase

@MainActor
final class UploadCloudSync {
    static let shared = UploadCloudSync()

    private static let bucket = "user_sheets"
    private static let table = "user_uploads"
    private static let columns = "id, title, original_filename, file_size_bytes, note_count, page_count, "
        + "skipped_pages, conversion_seconds, labeled_format, files_ready, uploaded_at, updated_at"

    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var library: LocalSheetLibrary { LocalSheetLibrary.shared }
    private var isSyncing = false
    private var syncAgain = false
    private var scheduled: Task<Void, Never>?
    private var downloads: [UUID: Task<Void, Never>] = [:]
    private var authObserver: NSObjectProtocol?

    private init() {}

    // MARK: - Triggers

    /// Syncs now and after every sign-in. Call once when the app starts.
    func start() {
        if authObserver == nil {
            authObserver = NotificationCenter.default.addObserver(
                forName: SupabaseManager.authStatusChangedNotification, object: nil, queue: .main
            ) { [weak self] note in
                guard let event = note.userInfo?["event"] as? AuthChangeEvent else { return }
                switch event {
                case .initialSession, .signedIn:
                    MainActor.assumeIsolated { self?.syncSoon() }
                default:
                    break
                }
            }
        }
        syncSoon()
    }

    /// Runs one sync shortly after the last call (bursts of changes become one sync).
    func syncSoon() {
        scheduled?.cancel()
        scheduled = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            // a separate task, so a later syncSoon() can't cancel a sync that is already running
            Task { @MainActor in await self?.sync() }
        }
    }

    func uploadRenamed(_ upload: LocalSheetLibrary.Upload, owner: String) {
        guard owner != "guest", upload.cloud == .synced else { return }
        Task {
            do {
                try await client.from(Self.table)
                    .update(TitleUpdate(title: upload.title, updated_at: upload.updatedAt))
                    .eq("id", value: upload.id.uuidString.lowercased())
                    .execute()
            } catch {
                debugLog("[UploadSync] rename not sent, will retry: \(error)")
                syncSoon()
            }
        }
    }

    /// Removes the upload from the account too (now, or at the next sync when offline).
    func uploadDeleted(_ upload: LocalSheetLibrary.Upload, owner: String) {
        guard owner != "guest", upload.status == .completed else { return }
        var pending = pendingDeletes(owner)
        pending.insert(upload.id)
        setPendingDeletes(pending, owner: owner)
        syncSoon()
    }

    // MARK: - Sync

    func sync() async {
        guard let userId = currentUserId else { return }
        if isSyncing {
            syncAgain = true
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        repeat {
            syncAgain = false
            do {
                try await syncOnce(userId: userId)
            } catch {
                debugLog("[UploadSync] sync failed: \(error)")
            }
        } while syncAgain && currentUserId == userId
    }

    private func syncOnce(userId: String) async throws {
        try await flushPendingDeletes(userId: userId)

        let remote: [RemoteUpload] = try await client.from(Self.table)
            .select(Self.columns)
            .execute()
            .value
        let remoteById = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let titlesToSend = applyRemoteChanges(remote, remoteById: remoteById, owner: userId)

        for upload in titlesToSend {
            _ = try? await client.from(Self.table)
                .update(TitleUpdate(title: upload.title, updated_at: upload.updatedAt))
                .eq("id", value: upload.id.uuidString.lowercased())
                .execute()
        }

        // Back up the newest converted uploads while the account has room; the rest stay here.
        var slots = LocalSheetLibrary.maxUploads - remote.count
        let candidates = library.list(for: userId)
            .filter { $0.status == .completed && $0.cloud != .synced && $0.filesOnDevice != false }
            .sorted { $0.uploadedAt > $1.uploadedAt }
        for upload in candidates {
            if remoteById[upload.id] != nil {
                await backUp(upload, owner: userId, rowExists: true)  // an earlier attempt was cut off
            } else if slots > 0 {
                slots -= 1
                await backUp(upload, owner: userId, rowExists: false)
            } else if upload.cloud != .notBackedUp {
                update(upload.id, owner: userId) { $0.cloud = .notBackedUp }
            }
        }

        // Bring the files of uploads made on other devices here, so they open instantly and offline.
        for upload in library.list(for: userId) where upload.filesOnDevice == false {
            guard currentUserId == userId else { return }
            await downloadFiles(of: upload.id)
        }
    }

    /// Adds uploads made on other devices, removes ones deleted there, and takes newer titles.
    /// Synchronous on the main actor, so nothing else changes the list while it runs.
    /// Returns uploads whose newer title is on this device.
    private func applyRemoteChanges(_ remote: [RemoteUpload], remoteById: [UUID: RemoteUpload],
                                    owner: String) -> [LocalSheetLibrary.Upload] {
        var all = library.list(for: owner)
        let before = all.map(\.id)
        var changed = false
        var titlesToSend: [LocalSheetLibrary.Upload] = []

        let deletedElsewhere = Set(all.filter { $0.cloud == .synced && remoteById[$0.id] == nil }.map(\.id))
        if !deletedElsewhere.isEmpty {
            for id in deletedElsewhere {
                try? FileManager.default.removeItem(at: library.folder(of: id, owner: owner))
            }
            all.removeAll { deletedElsewhere.contains($0.id) }
            changed = true
        }

        let pending = pendingDeletes(owner)
        var known = Set(all.map(\.id))
        var takenScanIds = Set(all.map(\.scanId))
        var nextScanId = Int64(Date().timeIntervalSince1970 * 1000)
        for row in remote where row.files_ready && !known.contains(row.id) && !pending.contains(row.id) {
            while takenScanIds.contains(nextScanId) { nextScanId += 1 }
            takenScanIds.insert(nextScanId)
            known.insert(row.id)
            all.append(LocalSheetLibrary.Upload(
                id: row.id, scanId: nextScanId, title: row.title, originalFilename: row.original_filename,
                fileSizeBytes: row.file_size_bytes, uploadedAt: row.uploaded_at, updatedAt: row.updated_at,
                status: .completed, errorMessage: nil, noteCount: row.note_count, pageCount: row.page_count,
                skippedPages: row.skipped_pages, conversionSeconds: row.conversion_seconds,
                cloud: .synced, filesOnDevice: false))
            changed = true
        }

        for i in all.indices {
            guard all[i].cloud == .synced, let row = remoteById[all[i].id], row.title != all[i].title else { continue }
            if row.updated_at > all[i].updatedAt {
                all[i].title = row.title
                all[i].updatedAt = row.updated_at
                changed = true
            } else {
                titlesToSend.append(all[i])
            }
        }

        if changed {
            try? library.save(all, owner: owner)
            for id in Set(before).union(all.map(\.id)) { library.notify(id) }
        }
        return titlesToSend
    }

    // MARK: - Backing up

    private func backUp(_ upload: LocalSheetLibrary.Upload, owner: String, rowExists: Bool) async {
        let folder = library.folder(of: upload.id, owner: owner)
        let packed: PackedFiles
        do {
            packed = try await Task.detached(priority: .utility) { try Self.pack(folder: folder) }.value
        } catch {
            debugLog("[UploadSync] \(upload.id) not backed up, files unreadable: \(error)")
            return
        }
        guard packed.files.allSatisfy({ $0.data.count <= LocalSheetLibrary.maxFileBytes }) else {
            update(upload.id, owner: owner) { $0.cloud = .notBackedUp }
            return
        }

        let id = upload.id.uuidString.lowercased()
        do {
            if !rowExists {
                try await client.from(Self.table).insert(NewRemoteUpload(
                    id: upload.id, title: upload.title, original_filename: upload.originalFilename,
                    file_size_bytes: upload.fileSizeBytes, note_count: upload.noteCount,
                    page_count: upload.pageCount, skipped_pages: upload.skippedPages,
                    conversion_seconds: upload.conversionSeconds, labeled_format: packed.labeledFormat,
                    uploaded_at: upload.uploadedAt, updated_at: upload.updatedAt
                )).execute()
            }
            let storage = client.storage.from(Self.bucket)
            for file in packed.files {
                try await storage.upload("\(owner)/\(id)/\(file.name)", data: file.data,
                                         options: FileOptions(contentType: "application/octet-stream", upsert: true))
            }
            try await client.from(Self.table)
                .update(ReadyUpdate(files_ready: true, labeled_format: packed.labeledFormat))
                .eq("id", value: id)
                .execute()
            // deleted while backing up: the next sync removes it from the account
            guard library.list(for: owner).contains(where: { $0.id == upload.id }) else {
                uploadDeleted(upload, owner: owner)
                return
            }
            update(upload.id, owner: owner) { $0.cloud = .synced }
            debugLog("[UploadSync] backed up \(id): \(packed.files.map { "\($0.name) \($0.data.count)B" })")
        } catch {
            if String(describing: error).contains("upload_limit_reached") {
                update(upload.id, owner: owner) { $0.cloud = .notBackedUp }
            } else {
                debugLog("[UploadSync] backup of \(id) failed, will retry: \(error)")
            }
        }
    }

    private struct PackedFiles: Sendable {
        let files: [(name: String, data: Data)]
        let labeledFormat: String
    }

    private enum SyncError: Error {
        case missingFiles
        case unreadableScore
    }

    nonisolated private static func pack(folder: URL) throws -> PackedFiles {
        func read(_ name: String) -> Data? { try? Data(contentsOf: folder.appendingPathComponent(name)) }
        guard let input = read("input.pdf"), let xml = read("score.musicxml") else { throw SyncError.missingFiles }
        var files = [(name: "input.pdf.z", data: try deflate(input)),
                     (name: "score.musicxml.z", data: try deflate(xml))]
        if let labels = read("labels.json") {
            files.append((name: "labels.json.z", data: try deflate(labels)))
            return PackedFiles(files: files, labeledFormat: "labels")
        }
        if let labeled = read("labeled.pdf") {
            files.append((name: "labeled.pdf.z", data: try deflate(labeled)))
        }
        return PackedFiles(files: files, labeledFormat: "pdf")
    }

    // MARK: - Downloading

    /// Downloads an upload backed up from another device and rebuilds its files here.
    /// Concurrent calls for the same upload share one download.
    func downloadFiles(of id: UUID) async {
        if let running = downloads[id] {
            await running.value
            return
        }
        guard let owner = currentUserId,
              library.list(for: owner).first(where: { $0.id == id })?.filesOnDevice == false else { return }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.download(id, owner: owner)
        }
        downloads[id] = task
        await task.value
        downloads[id] = nil
    }

    private func download(_ uploadId: UUID, owner: String) async {
        let base = "\(owner)/\(uploadId.uuidString.lowercased())"
        let storage = client.storage.from(Self.bucket)
        do {
            let input = try await storage.download(path: "\(base)/input.pdf.z")
            let xml = try await storage.download(path: "\(base)/score.musicxml.z")
            var labels: Data?
            var labeledPDF: Data?
            do {
                labels = try await storage.download(path: "\(base)/labels.json.z")
            } catch {
                labeledPDF = try? await storage.download(path: "\(base)/labeled.pdf.z")
            }
            let folder = library.folder(of: uploadId, owner: owner)
            let (labelsFile, labeledFile) = (labels, labeledPDF)
            try await Task.detached(priority: .userInitiated) {
                try Self.unpack(into: folder, input: input, xml: xml, labels: labelsFile, labeledPDF: labeledFile)
            }.value
            update(uploadId, owner: owner) { $0.filesOnDevice = nil }
        } catch {
            debugLog("[UploadSync] download of \(uploadId) failed: \(error)")
        }
    }

    nonisolated private static func unpack(into folder: URL, input: Data, xml: Data,
                                           labels: Data?, labeledPDF: Data?) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        func write(_ data: Data, _ name: String) throws {
            try data.write(to: folder.appendingPathComponent(name), options: .atomic)
        }
        let pdf = try inflate(input)
        let xmlData = try inflate(xml)
        guard let xmlString = String(data: xmlData, encoding: .utf8) else { throw SyncError.unreadableScore }
        let score = MusicXMLDocument.jsonObject(try MusicXMLDocument.parse(xmlString))
        try write(pdf, "input.pdf")
        try write(xmlData, "score.musicxml")
        try write(try JSONSerialization.data(withJSONObject: score), "output.json")
        if let labels {
            let raw = try inflate(labels)
            try write(raw, "labels.json")
            if let sheet = try? JSONDecoder().decode(LabelSheet.self, from: raw),
               let redrawn = OnDeviceSheetConverter.labeledPDF(pdfData: pdf, sheet: sheet) {
                try write(redrawn, "labeled.pdf")
            }
        } else if let labeledPDF {
            try write(try inflate(labeledPDF), "labeled.pdf")
        }
    }

    // MARK: - Deletes made while offline

    private func flushPendingDeletes(userId: String) async throws {
        var pending = pendingDeletes(userId)
        guard !pending.isEmpty else { return }
        let storage = client.storage.from(Self.bucket)
        for id in pending {
            let folder = "\(userId)/\(id.uuidString.lowercased())"
            let files = try await storage.list(path: folder)
            if !files.isEmpty {
                _ = try await storage.remove(paths: files.map { "\(folder)/\($0.name)" })
            }
            try await client.from(Self.table).delete().eq("id", value: id.uuidString.lowercased()).execute()
            pending.remove(id)
            setPendingDeletes(pending, owner: userId)
        }
    }

    private func pendingDeletes(_ owner: String) -> Set<UUID> {
        let ids = UserDefaults.standard.stringArray(forKey: "uploadSync.pendingDeletes.\(owner)") ?? []
        return Set(ids.compactMap(UUID.init(uuidString:)))
    }

    private func setPendingDeletes(_ ids: Set<UUID>, owner: String) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: "uploadSync.pendingDeletes.\(owner)")
    }

    // MARK: - Helpers

    private var currentUserId: String? {
        client.auth.currentUser?.id.uuidString.lowercased()
    }

    /// Changes one upload's sync fields; doesn't touch `updatedAt` (it orders lists and titles).
    private func update(_ id: UUID, owner: String, _ change: (inout LocalSheetLibrary.Upload) -> Void) {
        var all = library.list(for: owner)
        guard let i = all.firstIndex(where: { $0.id == id }) else { return }
        change(&all[i])
        try? library.save(all, owner: owner)
        library.notify(id)
    }

    nonisolated static func deflate(_ data: Data) throws -> Data {
        try (data as NSData).compressed(using: .zlib) as Data
    }

    nonisolated static func inflate(_ data: Data) throws -> Data {
        try (data as NSData).decompressed(using: .zlib) as Data
    }

    private struct RemoteUpload: Decodable {
        let id: UUID
        let title: String
        let original_filename: String
        let file_size_bytes: Int
        let note_count: Int?
        let page_count: Int?
        let skipped_pages: [Int]?
        let conversion_seconds: Double?
        let labeled_format: String
        let files_ready: Bool
        let uploaded_at: Date
        let updated_at: Date
    }

    private struct NewRemoteUpload: Encodable {
        let id: UUID
        let title: String
        let original_filename: String
        let file_size_bytes: Int
        let note_count: Int?
        let page_count: Int?
        let skipped_pages: [Int]?
        let conversion_seconds: Double?
        let labeled_format: String
        let uploaded_at: Date
        let updated_at: Date
    }

    private struct TitleUpdate: Encodable {
        let title: String
        let updated_at: Date
    }

    private struct ReadyUpdate: Encodable {
        let files_ready: Bool
        let labeled_format: String
    }
}
