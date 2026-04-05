//
//  PlayListModel.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 22/03/26.
//

import Foundation
import Supabase
struct Playlist: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    var name: String
    var description: String?
    var coverImageURL: String?
    var isPublic: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case coverImageURL = "cover_image_url"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Default Init
extension Playlist {
    init(userId: UUID, name: String) {
        self.id = UUID()
        self.userId = userId
        self.name = name
        self.description = nil
        self.coverImageURL = nil
        self.isPublic = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Service
final class PlaylistService {
    static let shared = PlaylistService()
    private init() {}

    func fetchPlaylists() async throws -> [Playlist] {
        let dbPlaylists: [Playlist] = try await SupabaseManager.shared.client
            .from("playlists")
            .select()
            .order("created_at", ascending: false)
            .execute().value
            
        var resolvedPlaylists: [Playlist] = []

        for p in dbPlaylists {
            var updated = p
            do {
                updated.coverImageURL = try await SupabaseManager.shared.signedAssetResolver
                    .maybeSignedURL(for: updated.coverImageURL, fallbackBucket: "PlayListCover")?
                    .absoluteString
                    ?? updated.coverImageURL
            } catch {
                // Ignore and keep original path if error
            }
            resolvedPlaylists.append(updated)
        }

        return resolvedPlaylists
    }
}
