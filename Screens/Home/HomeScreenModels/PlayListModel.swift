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

    private static let cacheKey = "playlists"

    /// The signed-in user's playlists as last fetched (saved on the device), to show at once
    /// while fresh ones load. nil before the first fetch.
    var savedPlaylists: [Playlist]? {
        AppDataCache.shared.value([Playlist].self, for: Self.cacheKey)
    }

    /// Fresh playlists from the server, saved for next time. Offline, or if the server fails,
    /// it returns the saved ones when there are any.
    func fetchPlaylists() async throws -> [Playlist] {
        do {
            let playlists = try await fetchFromServer()
            AppDataCache.shared.store(playlists, for: Self.cacheKey)
            return playlists
        } catch {
            if !(error is CancellationError), let saved = savedPlaylists { return saved }
            throw error
        }
    }

    private func fetchFromServer() async throws -> [Playlist] {
        let dbPlaylists: [Playlist] = try await SupabaseManager.shared.client
            .from("playlists")
            .select()
            .order("created_at", ascending: false)
            .execute().value
            
        var resolvedPlaylists: [Playlist] = []

        for p in dbPlaylists {
            var updated = p
            // Only a photo the user picked needs a signed URL; other covers draw as gradients.
            if let urlStr = updated.coverImageURL,
               PlaylistCover.isUserPhoto(urlStr),
               !urlStr.contains("://"),
               !urlStr.hasPrefix("doc_") {
                do {
                    updated.coverImageURL = try await PlaylistsManager.shared.resolveCoverImageURL(from: urlStr)
                } catch {
                    // Keep the stored path if resolution fails.
                }
            }
            resolvedPlaylists.append(updated)
        }

        return resolvedPlaylists
    }
}
