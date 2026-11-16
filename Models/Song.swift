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
    let userId: UUID?
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
    let jsonUrl: String?
    let originalPdfPath: String?
    let labeledPdfPath: String?
    let outputJsonPath: String?
    let coverImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", title, composer, level, tempo, hands, initials
        case skillTags        = "skill_tags"
        case skillDescription = "skill_description"
        case sheetFileId      = "sheet_file_id"
        case isFree           = "is_free"
        case isActive         = "is_active"
        case sortOrder        = "sort_order"
        case sheetUrl         = "sheet_url"
        case jsonUrl          = "json_url"
        case originalPdfPath  = "original_pdf_path"
        case labeledPdfPath   = "labeled_pdf_path"
        case outputJsonPath   = "output_json_path"
        case coverImageUrl    = "cover_image_url"
    }

    /// Columns that exist on `songs`; userId, sheetFileId, sheetUrl and jsonUrl are no longer in the table and decode as nil.
    static let listColumns = "id, title, composer, level, tempo, hands, initials, skill_tags, skill_description, is_free, is_active, sort_order, original_pdf_path, labeled_pdf_path, output_json_path, cover_image_url"
}

extension Song {
    struct DiscoverAssetSource: Equatable {
        let rawValue: String
        let fallbackBucket: String
    }

    var discoverCoverFallbackBucket: String {
        "Sheets"
    }

    var discoverPDFSource: DiscoverAssetSource? {
        if let labeledPdfPath = labeledPdfPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !labeledPdfPath.isEmpty {
            return DiscoverAssetSource(rawValue: labeledPdfPath, fallbackBucket: "pdf_uploads")
        }

        if let sheetUrl = sheetUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sheetUrl.isEmpty {
            return DiscoverAssetSource(rawValue: sheetUrl, fallbackBucket: "Sheets")
        }

        return nil
    }

    func discoverJSONSources(prefersPublicSource: Bool = false) -> [DiscoverAssetSource] {
        let privateSource: DiscoverAssetSource? = {
            guard let outputJsonPath = outputJsonPath?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !outputJsonPath.isEmpty else { return nil }
            return DiscoverAssetSource(rawValue: outputJsonPath, fallbackBucket: "sheet_data")
        }()

        let publicSource: DiscoverAssetSource? = {
            guard let jsonUrl = jsonUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !jsonUrl.isEmpty else { return nil }
            return DiscoverAssetSource(rawValue: jsonUrl, fallbackBucket: "Sheets")
        }()

        let orderedSources = prefersPublicSource
            ? [publicSource, privateSource]
            : [privateSource, publicSource]

        return orderedSources.compactMap { $0 }
    }

    var discoverJSONSource: DiscoverAssetSource? {
        discoverJSONSources().first
    }

    /// Main-actor isolated because the default resolver comes from `SupabaseManager.shared`.
    @MainActor
    func resolvedCoverImageURL(
        using resolver: SignedAssetResolver? = nil,
        fallbackBucket: String? = nil
    ) async throws -> URL? {
        let resolver = resolver ?? SupabaseManager.shared.signedAssetResolver
        return try await resolver.maybeSignedURL(
            for: coverImageUrl,
            fallbackBucket: fallbackBucket ?? discoverCoverFallbackBucket
        )
    }
}

/// The Library's song list. Launch, Library, Search and Notifications all ask for it, so it is
/// kept for a few minutes and concurrent requests share one fetch. Signing in or out clears it.
final class SongService {
    static let shared = SongService()
    private static let maxAge: TimeInterval = 5 * 60

    private var cached: (songs: [Song], fetchedAt: Date)?
    private var inFlight: Task<[Song], Error>?

    private init() {
        NotificationCenter.default.addObserver(
            forName: SupabaseManager.authStatusChangedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.cached = nil }
        }
    }

    func fetchSongs(forceRefresh: Bool = false) async throws -> [Song] {
        if !forceRefresh, let cached, Date().timeIntervalSince(cached.fetchedAt) < Self.maxAge {
            return cached.songs
        }
        if let inFlight { return try await inFlight.value }

        let task = Task {
            try await SupabaseManager.shared.client
                .from("songs")
                .select(Song.listColumns)
                .order("level", ascending: true)
                .order("sort_order", ascending: true)
                .execute().value as [Song]
        }
        inFlight = task
        defer { inFlight = nil }
        let songs = try await task.value
        cached = (songs, Date())
        return songs
    }
}
