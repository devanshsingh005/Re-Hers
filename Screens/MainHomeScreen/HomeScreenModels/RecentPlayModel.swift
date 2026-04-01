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
    private init() {}

    /// Fetch the most recent plays for the current user, joined with song data.
    func fetchRecents(limit: Int = 10) async throws -> [RecentPlay] {
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
            debugLog("[RecentPlayService] ❌ No current user, skipping recordPlay")
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
            print("[RecentPlayService] ✅ Play recorded successfully")
        } catch {
            print("[RecentPlayService] ❌ Failed to record play: \(error)")
            throw error
        }
    }
}
