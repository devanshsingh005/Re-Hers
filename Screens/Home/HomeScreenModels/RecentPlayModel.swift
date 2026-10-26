//
//  RecentPlayModel.swift
//  Re-Hearse_v1
//

import Foundation
internal import PostgREST
import Supabase

// MARK: - Model

/// Represents a row from the `recent_plays` table joined with the `songs` table.
struct RecentPlay: Codable {
    let id: UUID
    let userId: UUID
    let songId: UUID
    let lastPlayedAt: Date
    let songs: Song  // joined via `songs(*)`

    enum CodingKeys: String, CodingKey {
        case id
        case userId       = "user_id"
        case songId       = "song_id"
        case lastPlayedAt = "last_played_at"
        case songs
    }
}

// MARK: - Service

final class RecentPlayService {
    static let shared = RecentPlayService()
    static let recentPlaysUpdatedNotification = Notification.Name("RecentPlaysUpdatedNotification")

    private let guestStorageKey = "guest_recent_songs_v1"
    private let guestUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private init() {}

    private struct GuestRecentPlay: Codable {
        let song: Song
        let lastPlayedAt: Date
    }

    /// Fetch the most recent plays for the current user, joined with song data.
    func fetchRecents(limit: Int = 10) async throws -> [RecentPlay] {
        guard SupabaseManager.shared.client.auth.currentUser != nil else {
            let stored = loadGuestRecents()
            return Array(stored.prefix(limit)).map { item in
                RecentPlay(
                    id: UUID(),
                    userId: guestUserId,
                    songId: item.song.id,
                    lastPlayedAt: item.lastPlayedAt,
                    songs: item.song
                )
            }
        }

        let result: [RecentPlay] = try await SupabaseManager.shared.client
            .from("recent_plays")
            .select("*, songs(*)")
            .order("last_played_at", ascending: false)
            .limit(limit)
            .execute().value
        debugLog("[RecentPlayService] Fetched \(result.count) recent plays")
        return result
    }

    /// Record (or refresh) a play for the given song.
    /// Uses upsert so the same song just updates `last_played_at`.
    func recordPlay(songId: UUID) async throws {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else {
            return
        }

        struct PlayRow: Codable {
            let user_id: UUID
            let song_id: UUID
            let last_played_at: String
        }

        let dateStr = ISO8601DateFormatter().string(from: Date())
        let row = PlayRow(
            user_id: userId,
            song_id: songId,
            last_played_at: dateStr
        )

        debugLog("[RecentPlayService] Recording play for song: \(songId), user: \(userId)")

        do {
            try await SupabaseManager.shared.client
                .from("recent_plays")
                .upsert(row, onConflict: "user_id,song_id")
                .execute()
            await MainActor.run {
                NotificationCenter.default.post(name: Self.recentPlaysUpdatedNotification, object: nil)
            }
            print("[RecentPlayService] ✅ Play recorded successfully")
        } catch {
            print("[RecentPlayService] ❌ Failed to record play: \(error)")
            throw error
        }
    }

    func recordPlay(song: Song) async throws {
        guard SupabaseManager.shared.client.auth.currentUser != nil else {
            saveGuestRecent(song)
            await MainActor.run {
                NotificationCenter.default.post(name: Self.recentPlaysUpdatedNotification, object: nil)
            }
            return
        }

        try await recordPlay(songId: song.id)
    }

    private func loadGuestRecents() -> [GuestRecentPlay] {
        guard let data = UserDefaults.standard.data(forKey: guestStorageKey) else { return [] }
        return (try? JSONDecoder().decode([GuestRecentPlay].self, from: data)) ?? []
    }

    private func saveGuestRecent(_ song: Song) {
        var items = loadGuestRecents()
        items.removeAll { $0.song.id == song.id }
        items.insert(GuestRecentPlay(song: song, lastPlayedAt: Date()), at: 0)
        items = Array(items.prefix(20))
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: guestStorageKey)
        }
    }
}
