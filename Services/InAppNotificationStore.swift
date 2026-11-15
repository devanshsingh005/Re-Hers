//
//  InAppNotificationStore.swift
//  Re-Hearse_v1
//
//  The in-app activity feed behind the bell on Home: uploads that finished or failed
//  converting, the daily practice goal being reached, and new songs in the Library.
//  Stored on this device, per account.
//

import Foundation
import Supabase

struct InAppNotification: Codable, Identifiable {
    enum Kind: String, Codable {
        case welcome, uploadReady, uploadFailed, goalReached, newSongs

        var symbolName: String {
            switch self {
            case .welcome:      return "hand.wave.fill"
            case .uploadReady:  return "checkmark.circle.fill"
            case .uploadFailed: return "exclamationmark.triangle.fill"
            case .goalReached:  return "flame.fill"
            case .newSongs:     return "music.note.list"
            }
        }
    }

    let id: UUID
    let kind: Kind
    var title: String
    var body: String
    let date: Date
    var isRead: Bool
    var uploadId: UUID?
    var songId: UUID?
}

final class InAppNotificationStore {
    static let shared = InAppNotificationStore()
    static let didChangeNotification = Notification.Name("InAppNotificationStoreDidChange")

    private let defaults: UserDefaults
    private let maxCount = 50
    /// Upload status last seen, to notice when a conversion finishes.
    private var knownUploadStatus: [UUID: LocalSheetLibrary.Status] = [:]
    private var knownOwner: String?
    private var isStarted = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Starts listening for the events the feed reports. Safe to call more than once.
    func start() {
        // Unit tests run inside the app and convert sample sheets; keep those out of the feed.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        guard !isStarted else { return }
        isStarted = true
        seedUploadStatuses()
        postWelcomeIfNeeded()

        let center = NotificationCenter.default
        center.addObserver(forName: LocalSheetLibrary.didChangeNotification, object: nil, queue: .main) { [weak self] note in
            let id = note.userInfo?["id"] as? UUID
            MainActor.assumeIsolated { self?.uploadDidChange(id: id) }
        }
        center.addObserver(forName: DailyGoalManager.dailyGoalUpdatedNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkDailyGoal() }
        }
        center.addObserver(forName: SupabaseManager.authStatusChangedNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.seedUploadStatuses()
                self?.postWelcomeIfNeeded()
                self?.notifyChange()
            }
        }
    }

    // MARK: - Reading

    func all() -> [InAppNotification] {
        guard let data = defaults.data(forKey: key("items")),
              let items = try? JSONDecoder().decode([InAppNotification].self, from: data) else { return [] }
        return items
    }

    var unreadCount: Int { all().filter { !$0.isRead }.count }

    // MARK: - Writing

    func post(kind: InAppNotification.Kind, title: String, body: String,
              uploadId: UUID? = nil, songId: UUID? = nil) {
        var items = all()
        items.insert(InAppNotification(id: UUID(), kind: kind, title: title, body: body, date: Date(),
                                       isRead: false, uploadId: uploadId, songId: songId), at: 0)
        save(Array(items.prefix(maxCount)))
    }

    func markRead(id: UUID) {
        var items = all()
        guard let i = items.firstIndex(where: { $0.id == id }), !items[i].isRead else { return }
        items[i].isRead = true
        save(items)
    }

    func markAllRead() {
        save(all().map { var n = $0; n.isRead = true; return n })
    }

    func delete(id: UUID) {
        save(all().filter { $0.id != id })
    }

    func deleteAll() {
        save([])
    }

    /// Compares the Library's songs with the ones seen before and reports new ones.
    /// The first time, it only remembers them.
    func noteLibrarySongs(_ songs: [Song]) {
        let active = songs.filter(\.isActive)
        let ids = Set(active.map { $0.id.uuidString })
        let seenKey = key("seenSongs")
        guard let seen = defaults.stringArray(forKey: seenKey) else {
            defaults.set(Array(ids), forKey: seenKey)
            return
        }
        let new = active.filter { !Set(seen).contains($0.id.uuidString) }
        defaults.set(Array(ids.union(seen)), forKey: seenKey)
        guard let first = new.first else { return }
        if new.count == 1 {
            post(kind: .newSongs, title: "New in the Library",
                 body: "\(first.title) by \(first.composer) is ready to practise.", songId: first.id)
        } else {
            post(kind: .newSongs, title: "\(new.count) new songs in the Library",
                 body: new.prefix(3).map(\.title).joined(separator: ", ") + (new.count > 3 ? "…" : ""))
        }
    }

    // MARK: - Event sources

    private func uploadDidChange(id: UUID?) {
        if owner != knownOwner { seedUploadStatuses() }
        guard let id else { return }
        let previous = knownUploadStatus[id]
        guard let upload = LocalSheetLibrary.shared.upload(id: id) else {
            knownUploadStatus[id] = nil
            return
        }
        knownUploadStatus[id] = upload.status
        // Only a conversion seen running reports its end, so a retry reports again
        // and nothing is posted for uploads that were already finished.
        guard previous == .processing || (previous == nil && upload.status != .processing) else { return }
        switch upload.status {
        case .processing:
            return
        case .completed:
            post(kind: .uploadReady, title: "\(upload.title) is ready",
                 body: "Your sheet was converted. Tap to play along or watch the animation.", uploadId: id)
        case .failed:
            post(kind: .uploadFailed, title: "Couldn't convert \(upload.title)",
                 body: upload.errorMessage ?? "Tap to try again.", uploadId: id)
        }
    }

    private func checkDailyGoal() {
        let goals = DailyGoalManager.shared
        guard goals.dailyGoalMinutes > 0, goals.practiceTimeMinutesToday >= goals.dailyGoalMinutes else { return }
        let today = Self.dayFormatter.string(from: Date())
        let dayKey = key("goalReachedDay")
        guard defaults.string(forKey: dayKey) != today else { return }
        defaults.set(today, forKey: dayKey)
        post(kind: .goalReached, title: "Daily goal reached",
             body: "You practised \(goals.practiceTimeMinutesToday) minutes today. Keep the streak going!")
    }

    private func seedUploadStatuses() {
        knownOwner = owner
        knownUploadStatus = Dictionary(LocalSheetLibrary.shared.uploads().map { ($0.id, $0.status) },
                                       uniquingKeysWith: { a, _ in a })
    }

    private func postWelcomeIfNeeded() {
        let welcomeKey = key("welcomed")
        guard !defaults.bool(forKey: welcomeKey) else { return }
        defaults.set(true, forKey: welcomeKey)
        post(kind: .welcome, title: "Welcome to Rehearse",
             body: "Scan or upload a page of sheet music to hear it and start playing along.")
    }

    // MARK: - Storage

    private func save(_ items: [InAppNotification]) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key("items"))
        }
        notifyChange()
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    private var owner: String {
        SupabaseManager.shared.client.auth.currentUser?.id.uuidString.lowercased() ?? "guest"
    }

    private func key(_ name: String) -> String { "notifications.\(owner).\(name)" }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
