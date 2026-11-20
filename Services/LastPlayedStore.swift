//
//  LastPlayedStore.swift
//  Re-Hearse_v1
//
//  Remembers the sheet the user last opened in Play Along or Animation, per account, so the
//  mini player above the tab bar can show it and take the user straight back.
//

import Foundation
import Supabase

struct LastPlayedItem: Codable {
    enum Mode: String, Codable {
        case playAlong, animation

        var title: String { self == .playAlong ? "Play Along" : "Animation" }
    }

    /// Set for an upload stored on this device.
    var uploadId: UUID?
    /// Set for a Library song.
    var song: Song?
    var title: String
    var detail: String
    var mode: Mode
    var playedAt: Date
}

final class LastPlayedStore {
    static let shared = LastPlayedStore()
    static let didChangeNotification = Notification.Name("LastPlayedStoreDidChange")

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The last-played sheet, or nil when there is none (or its upload has since been deleted).
    /// An upload's title is read from the library so a rename shows up straight away.
    var current: LastPlayedItem? {
        guard let data = defaults.data(forKey: key),
              var item = try? JSONDecoder().decode(LastPlayedItem.self, from: data) else { return nil }
        if let uploadId = item.uploadId {
            guard let upload = LocalSheetLibrary.shared.upload(id: uploadId) else { return nil }
            item.title = upload.title
        }
        return item
    }

    func record(upload: LocalSheetLibrary.Upload, mode: LastPlayedItem.Mode, tempo: String?) {
        let parts = ["My upload", mode.title, tempo].compactMap { $0 }.filter { !$0.isEmpty }
        save(LastPlayedItem(uploadId: upload.id, song: nil, title: upload.title,
                            detail: parts.joined(separator: " · "), mode: mode, playedAt: Date()))
    }

    func record(song: Song, mode: LastPlayedItem.Mode) {
        save(LastPlayedItem(uploadId: nil, song: song, title: song.title,
                            detail: Self.detail(for: song), mode: mode, playedAt: Date()))
    }

    func clear() {
        defaults.removeObject(forKey: key)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    /// "Level 1 · Right hand · Slow"
    static func detail(for song: Song) -> String {
        let hands: String
        switch song.hands {
        case "right_only": hands = "Right hand"
        case "left_only":  hands = "Left hand"
        default:           hands = "Both hands"
        }
        let tempo: String
        switch song.tempo {
        case "slow": tempo = "Slow"
        case "fast": tempo = "Fast"
        case "medium": tempo = "Medium"
        default: tempo = song.tempo
        }
        return ["Level \(song.level)", hands, tempo].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func save(_ item: LastPlayedItem) {
        guard let data = try? JSONEncoder().encode(item) else { return }
        defaults.set(data, forKey: key)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    private var key: String {
        let owner = SupabaseManager.shared.client.auth.currentUser?.id.uuidString.lowercased() ?? "guest"
        return "lastPlayed.\(owner)"
    }
}
