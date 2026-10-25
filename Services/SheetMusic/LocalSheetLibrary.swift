//
//  LocalSheetLibrary.swift
//  Re-Hearse_v1
//
//  The user's uploaded sheets and their conversions, kept only on this device in
//  Application Support/SheetLibrary/<account>/. This replaces the old server pipeline: the
//  /convert API, the Supabase `jobs` and `scans` rows, the storage buckets and the polling.
//
//  Each upload has a folder with input.pdf, and once converted output.json (the score JSON
//  Play Along and Animation read), labeled.pdf (note names under the notes) and score.musicxml.
//

import Foundation
import Supabase

@MainActor
final class LocalSheetLibrary {
    static let shared = LocalSheetLibrary()

    /// Posted when an upload is added, renamed, deleted, makes progress or finishes.
    /// `userInfo["id"]` is the upload's UUID.
    static let didChangeNotification = Notification.Name("LocalSheetLibraryDidChange")

    enum Status: String, Codable {
        case processing, completed, failed
    }

    struct Upload: Codable, Identifiable {
        /// Identifies the upload everywhere (screens pass it on as `jobId`, like the old job id).
        let id: UUID
        /// Numeric id for list rows and menus (the old `scans.id`).
        let scanId: Int64
        var title: String
        let originalFilename: String
        let fileSizeBytes: Int
        let uploadedAt: Date
        var updatedAt: Date
        var status: Status
        var errorMessage: String?
        var noteCount: Int?
        var pageCount: Int?
        var skippedPages: [Int]?
        var conversionSeconds: Double?
    }

    /// Playlists (stored in Supabase) point at an upload on this device through their
    /// `track_id`: "local-upload:<uuid>".
    nonisolated static func playlistTrackId(for id: UUID) -> String {
        "local-upload:" + id.uuidString.lowercased()
    }

    nonisolated static func uploadId(fromPlaylistTrackId trackId: String) -> UUID? {
        guard trackId.hasPrefix("local-upload:") else { return nil }
        return UUID(uuidString: String(trackId.dropFirst("local-upload:".count)))
    }

    enum LibraryError: LocalizedError {
        case notFound

        var errorDescription: String? { "This upload is no longer on this device." }
    }

    /// Conversion progress 0...1 of uploads being converted right now.
    private(set) var progress: [UUID: Double] = [:]
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var lists: [String: [Upload]] = [:]
    private let root: URL

    private init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        root = base.appendingPathComponent("SheetLibrary", isDirectory: true)
    }

    // MARK: - Reading

    /// The signed-in account's uploads, most recently changed first.
    func uploads() -> [Upload] {
        list(for: owner).sorted { $0.updatedAt > $1.updatedAt }
    }

    func upload(id: UUID) -> Upload? {
        list(for: owner).first { $0.id == id }
    }

    func upload(scanId: Int64) -> Upload? {
        list(for: owner).first { $0.scanId == scanId }
    }

    func inputPDF(id: UUID) -> Data? { try? Data(contentsOf: file("input.pdf", of: id, owner: owner)) }
    func labeledPDF(id: UUID) -> Data? { try? Data(contentsOf: file("labeled.pdf", of: id, owner: owner)) }
    func musicXML(id: UUID) -> String? { try? String(contentsOf: file("score.musicxml", of: id, owner: owner), encoding: .utf8) }

    /// The converted score in the JSON shape Play Along and Animation read.
    func scoreJSON(id: UUID) -> [String: Any]? {
        guard let data = try? Data(contentsOf: file("output.json", of: id, owner: owner)) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// `base`, or `base 2`, `base 3`, … if that title is taken.
    func uniqueTitle(base: String) -> String {
        let taken = Set(list(for: owner).map { $0.title })
        if !taken.contains(base) { return base }
        var n = 2
        while taken.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    // MARK: - Changing

    /// Stores a new upload and starts converting it on the device.
    @discardableResult
    func add(pdfData: Data, title: String, originalFilename: String) throws -> Upload {
        let owner = self.owner
        let id = UUID()
        try FileManager.default.createDirectory(at: folder(of: id, owner: owner), withIntermediateDirectories: true)
        try pdfData.write(to: file("input.pdf", of: id, owner: owner), options: .atomic)
        let now = Date()
        let upload = Upload(id: id, scanId: nextScanId(owner: owner), title: title,
                            originalFilename: originalFilename, fileSizeBytes: pdfData.count,
                            uploadedAt: now, updatedAt: now, status: .processing)
        var all = list(for: owner)
        all.append(upload)
        try save(all, owner: owner)
        startConversion(of: upload, owner: owner)
        notify(id)
        return upload
    }

    func rename(scanId: Int64, to title: String) throws {
        let owner = self.owner
        var all = list(for: owner)
        guard let i = all.firstIndex(where: { $0.scanId == scanId }) else { throw LibraryError.notFound }
        all[i].title = title
        all[i].updatedAt = Date()
        try save(all, owner: owner)
        notify(all[i].id)
    }

    func delete(scanId: Int64) throws {
        let owner = self.owner
        var all = list(for: owner)
        guard let i = all.firstIndex(where: { $0.scanId == scanId }) else { throw LibraryError.notFound }
        let id = all.remove(at: i).id
        tasks.removeValue(forKey: id)?.cancel()
        progress[id] = nil
        try save(all, owner: owner)
        try? FileManager.default.removeItem(at: folder(of: id, owner: owner))
        notify(id)
    }

    /// Converts the upload again (e.g. after a failure).
    func retry(id: UUID) {
        let owner = self.owner
        var all = list(for: owner)
        guard let i = all.firstIndex(where: { $0.id == id }), tasks[id] == nil else { return }
        all[i].status = .processing
        all[i].errorMessage = nil
        try? save(all, owner: owner)
        startConversion(of: all[i], owner: owner)
        notify(id)
    }

    /// Waits for the upload's conversion if one is running and returns the upload.
    func waitForConversion(id: UUID) async -> Upload? {
        if let task = tasks[id] { await task.value }
        return upload(id: id)
    }

    /// Restarts conversions that were cut off because the app was closed while converting.
    func resumeInterruptedConversions() {
        let owner = self.owner
        for upload in list(for: owner) where upload.status == .processing && tasks[upload.id] == nil {
            startConversion(of: upload, owner: owner)
        }
    }

    // MARK: - Conversion

    private func startConversion(of upload: Upload, owner: String) {
        let id = upload.id
        let title = upload.title
        let folder = folder(of: id, owner: owner)
        progress[id] = 0
        tasks[id] = Task { [weak self] in
            let outcome = await Task.detached(priority: .userInitiated) { () -> Result<SheetConversionResult, Error> in
                do {
                    let pdf = try Data(contentsOf: folder.appendingPathComponent("input.pdf"))
                    let result = try await OnDeviceSheetConverter.shared.convert(pdfData: pdf, title: title) { p in
                        Task { @MainActor in self?.report(progress: p, for: id) }
                    }
                    try result.scoreJSON.write(to: folder.appendingPathComponent("output.json"), options: .atomic)
                    try result.labeledPDF.write(to: folder.appendingPathComponent("labeled.pdf"), options: .atomic)
                    try result.musicXML.write(to: folder.appendingPathComponent("score.musicxml"),
                                              atomically: true, encoding: .utf8)
                    return .success(result)
                } catch {
                    return .failure(error)
                }
            }.value
            self?.finish(id: id, owner: owner, outcome: outcome)
        }
    }

    private func report(progress value: Double, for id: UUID) {
        guard tasks[id] != nil else { return }
        progress[id] = value
        notify(id)
    }

    private func finish(id: UUID, owner: String, outcome: Result<SheetConversionResult, Error>) {
        tasks[id] = nil
        progress[id] = nil
        var all = list(for: owner)
        guard let i = all.firstIndex(where: { $0.id == id }) else { return }  // deleted meanwhile
        switch outcome {
        case .success(let result):
            all[i].status = .completed
            all[i].errorMessage = nil
            all[i].noteCount = result.noteCount
            all[i].pageCount = result.pageCount
            all[i].skippedPages = result.skippedPages
            all[i].conversionSeconds = result.seconds
            debugLog("[OnDevice] \(id): \(result.noteCount) notes, \(result.pageCount) page(s), "
                     + "skipped \(result.skippedPages), \(String(format: "%.1f", result.seconds))s")
        case .failure(let error):
            if error is CancellationError { return }
            all[i].status = .failed
            all[i].errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "We couldn't finish converting this sheet. Please try again."
            debugLog("[OnDevice] \(id) failed: \(error)")
        }
        all[i].updatedAt = Date()
        try? save(all, owner: owner)
        notify(id)
    }

    // MARK: - Storage

    /// Uploads belong to the signed-in account, read from the stored session (no network).
    private var owner: String {
        SupabaseManager.shared.client.auth.currentUser?.id.uuidString.lowercased() ?? "guest"
    }

    private func folder(of id: UUID, owner: String) -> URL {
        root.appendingPathComponent(owner, isDirectory: true)
            .appendingPathComponent(id.uuidString.lowercased(), isDirectory: true)
    }

    private func file(_ name: String, of id: UUID, owner: String) -> URL {
        folder(of: id, owner: owner).appendingPathComponent(name)
    }

    private func indexURL(owner: String) -> URL {
        root.appendingPathComponent(owner, isDirectory: true).appendingPathComponent("index.json")
    }

    private func list(for owner: String) -> [Upload] {
        if let cached = lists[owner] { return cached }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = (try? Data(contentsOf: indexURL(owner: owner)))
            .flatMap { try? decoder.decode([Upload].self, from: $0) } ?? []
        lists[owner] = loaded
        return loaded
    }

    private func save(_ uploads: [Upload], owner: String) throws {
        lists[owner] = uploads
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = indexURL(owner: owner)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(uploads).write(to: url, options: .atomic)
    }

    /// Milliseconds since 1970: unique on this device and far above the small ids of old
    /// server-side scans, so the two can never be confused.
    private func nextScanId(owner: String) -> Int64 {
        let taken = Set(list(for: owner).map { $0.scanId })
        var id = Int64(Date().timeIntervalSince1970 * 1000)
        while taken.contains(id) { id += 1 }
        return id
    }

    private func notify(_ id: UUID) {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self, userInfo: ["id": id])
    }
}
