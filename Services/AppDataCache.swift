//
//  AppDataCache.swift
//  Re-Hearse_v1
//
//  Saved copies of what the app fetches, so pages open instantly, refresh quietly in the
//  background and keep working offline:
//
//  - AppDataCache: server data (songs, playlists, profile, stats, lesson progress) as JSON,
//    in memory and in Caches/RehearseData. Account data sits in a folder per signed-in user
//    and is removed on sign-out; the song list is shared by everyone.
//  - SheetFileCache: sheet files downloaded for Library songs (PDFs, score JSON), in
//    Caches/RehearseSheets, at most 200 MB; the least recently used go first.
//  - Connectivity: whether the device is online, for the "Offline" note.
//
//  Everything here can be rebuilt from the server, so it lives in Caches (iOS may clear it
//  when space runs low) and every read tolerates a missing or unreadable file.
//

import Foundation
import Network
import CryptoKit
import Supabase

// MARK: - Data

@MainActor
final class AppDataCache {
    static let shared = AppDataCache()

    private let root: URL
    private var memory: [String: Data] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        root = caches.appendingPathComponent("RehearseData", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        // An account's saved data is removed when it signs out (or the account is deleted).
        NotificationCenter.default.addObserver(
            forName: SupabaseManager.authStatusChangedNotification, object: nil, queue: .main
        ) { note in
            guard let event = note.userInfo?["event"] as? AuthChangeEvent,
                  event == .signedOut || event == .userDeleted else { return }
            MainActor.assumeIsolated { AppDataCache.shared.removeAccountData() }
        }
    }

    enum Scope {
        /// The signed-in user's data (a guest's when nobody is signed in).
        case account
        /// The same for everyone (the Library's song list).
        case shared
    }

    /// The saved value, or nil if there is none (or it no longer decodes).
    func value<T: Decodable>(_ type: T.Type, for key: String, scope: Scope = .account) -> T? {
        let url = fileURL(key, scope: scope)
        let data: Data
        if let inMemory = memory[url.path] {
            data = inMemory
        } else if let onDisk = try? Data(contentsOf: url) {
            memory[url.path] = onDisk
            data = onDisk
        } else {
            return nil
        }
        return try? decoder.decode(T.self, from: data)
    }

    func store<T: Encodable>(_ value: T, for key: String, scope: Scope = .account) {
        guard let data = try? encoder.encode(value) else { return }
        let url = fileURL(key, scope: scope)
        memory[url.path] = data
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    func remove(_ key: String, scope: Scope = .account) {
        let url = fileURL(key, scope: scope)
        memory[url.path] = nil
        try? FileManager.default.removeItem(at: url)
    }

    /// Removes every account's saved data (kept: the shared song list).
    func removeAccountData() {
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        for folder in folders where folder.lastPathComponent != "shared" {
            try? FileManager.default.removeItem(at: folder)
        }
        memory = memory.filter { $0.key.contains("/shared/") }
    }

    private var owner: String {
        SupabaseManager.shared.client.auth.currentUser?.id.uuidString.lowercased() ?? "guest"
    }

    private func fileURL(_ key: String, scope: Scope) -> URL {
        let folder = scope == .shared ? "shared" : owner
        return root.appendingPathComponent(folder, isDirectory: true).appendingPathComponent(key + ".json")
    }
}

// MARK: - Sheet files

/// Downloaded sheet files, keyed by their storage path. Thread-safe; file work runs on the
/// caller's thread (callers are async tasks).
nonisolated final class SheetFileCache: @unchecked Sendable {
    static let shared = SheetFileCache()
    static let maxBytes = 200 * 1024 * 1024

    private let folder: URL
    private let lock = NSLock()

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        folder = caches.appendingPathComponent("RehearseSheets", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func data(for key: String) -> Data? {
        let url = fileURL(key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        // reading counts as use, for the least-recently-used trim
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return data
    }

    func store(_ data: Data, for key: String) {
        lock.lock(); defer { lock.unlock() }
        try? data.write(to: fileURL(key), options: .atomic)
        trim()
    }

    /// Keeps the folder under `maxBytes`, removing the least recently used files first.
    private func trim() {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)
        else { return }
        let entries = files.compactMap { url -> (url: URL, size: Int, used: Date)? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(0) { $0 + $1.size }
        guard total > Self.maxBytes else { return }
        for entry in entries.sorted(by: { $0.used < $1.used }) where total > Self.maxBytes {
            try? FileManager.default.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    private func fileURL(_ key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent(digest)
    }
}

// MARK: - Cached sheet downloads

/// Library sheet files (PDFs, score JSON) through `SheetFileCache`: a file opened before comes
/// from the device at once (and works offline) while a quiet download refreshes the saved copy
/// for next time; a new one is downloaded and saved.
@MainActor
enum SheetDownloads {
    struct DownloadFailed: LocalizedError {
        let statusCode: Int
        var errorDescription: String? { "Remote asset fetch failed with status \(statusCode)" }
    }

    static func data(for rawValue: String, fallbackBucket: String) async throws -> Data {
        let key = fallbackBucket + "/" + rawValue
        if let saved = SheetFileCache.shared.data(for: key) {
            Task {
                if let fresh = try? await download(rawValue, fallbackBucket: fallbackBucket) {
                    SheetFileCache.shared.store(fresh, for: key)
                }
            }
            return saved
        }
        let data = try await download(rawValue, fallbackBucket: fallbackBucket)
        SheetFileCache.shared.store(data, for: key)
        return data
    }

    private static func download(_ rawValue: String, fallbackBucket: String) async throws -> Data {
        let url = try await SupabaseManager.shared.signedAssetResolver.signedURL(
            for: rawValue,
            fallbackBucket: fallbackBucket
        )
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(statusCode) else { throw DownloadFailed(statusCode: statusCode) }
        return data
    }
}

// MARK: - Connectivity

/// Whether the device is online. Posts `didChangeNotification` (on the main queue) when it
/// changes; pages refresh themselves when the connection comes back.
@MainActor
final class Connectivity {
    static let shared = Connectivity()
    static let didChangeNotification = Notification.Name("ConnectivityDidChange")

    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { path in
            let online = path.status == .satisfied
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    let shared = Connectivity.shared
                    guard shared.isOnline != online else { return }
                    shared.isOnline = online
                    NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "rehearse.connectivity"))
    }

    /// Starts watching (call once at launch).
    func start() {}
}
