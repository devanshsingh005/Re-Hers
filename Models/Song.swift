//
//  Song.swift
//  Re-Hearse
//
//  Shared data model for songs.
//

import Foundation
import Supabase

struct Song: Codable, Identifiable {
    let id: UUID
    let title: String
    let composer: String
    let level: Int
    let tempo: String
    let hands: String
    let skillTags: [String]
    let skillDescription: String
    let initials: String
    let sheetFileId: UUID?
    let isFree: Bool
    let isActive: Bool
    let sortOrder: Int
    let sheetUrl: String?
    let coverImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, title, composer, level, tempo, hands, initials
        case skillTags        = "skill_tags"
        case skillDescription = "skill_description"
        case sheetFileId      = "sheet_file_id"
        case isFree           = "is_free"
        case isActive         = "is_active"
        case sortOrder        = "sort_order"
        case sheetUrl         = "sheet_url"
        case coverImageUrl    = "cover_image_url"
    }
}

final class SongService {
    static let shared = SongService()
    private init() {}

    func fetchSongs() async throws -> [Song] {
        try await SupabaseManager.shared.client
            .from("songs").select()
            .order("level", ascending: true)
            .order("sort_order", ascending: true)
            .execute().value
    }
}
