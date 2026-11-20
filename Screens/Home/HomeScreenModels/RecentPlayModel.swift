//
//  RecentPlayModel.swift
//  Re-Hearse_v1
//

import Foundation
internal import PostgREST
import Supabase

/// Records Library songs a signed-in user opens in the `recent_plays` table.
final class RecentPlayService {
    static let shared = RecentPlayService()
    private init() {}

    /// Records (or refreshes) a play; the upsert just updates `last_played_at` for a repeat.
    /// Guests have no account to record against, so nothing is stored for them.
    func recordPlay(song: Song) async throws {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else { return }

        struct PlayRow: Encodable {
            let user_id: UUID
            let song_id: UUID
            let last_played_at: String
        }

        let row = PlayRow(user_id: userId, song_id: song.id,
                          last_played_at: ISO8601DateFormatter().string(from: Date()))
        try await SupabaseManager.shared.client
            .from("recent_plays")
            .upsert(row, onConflict: "user_id,song_id")
            .execute()
    }
}
