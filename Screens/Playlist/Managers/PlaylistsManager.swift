import Foundation
import UIKit
import Supabase
import Auth
internal import PostgREST

public enum PlaylistError: Error {
    case invalidData
    case uploadFailed
    case missingDefaultArtwork
    case invalidName
}

public final class PlaylistsManager {
    public static let shared = PlaylistsManager()
    private let playlistCoverBucket = "PlayListCover"
    private let coverSignedURLTTL = 60 * 60
    private let resolvedCoverURLCacheLock = NSLock()
    private var resolvedCoverURLCache: [String: (url: String, expiresAt: Date)] = [:]
    private let playlistCacheLock = NSLock()
    private var playlistCache: [PlaylistData] = []
    private var playlistCacheWarmTask: Task<Void, Never>?
    
    private init() {}
    
    // MARK: - Fetch All Playlists
    
    public func fetchRemotePlaylists() async throws -> [PlaylistData] {
        let session = try await SupabaseManager.shared.client.auth.session
        let userId = session.user.id
        
        let dbPlaylists: [DBPlaylist] = try await SupabaseManager.shared.client
            .from("playlists")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        var remotePlaylists: [PlaylistData] = []
        
        for dbPlaylist in dbPlaylists {
            // Fetch tracks for this playlist
            let dbItems: [DBPlaylistItem] = try await SupabaseManager.shared.client
                .from("playlist_items")
                .select()
                .eq("playlist_id", value: dbPlaylist.id.uuidString)
                .order("position", ascending: false)
                .execute()
                .value
            
            let tracks = dbItems.map { item in
                PlaylistTrack(
                    id: UUID(),
                    trackId: item.trackId,
                    title: item.trackTitle,
                    artist: item.artistName,
                    playlistItemId: item.id,
                    sheetScanId: item.sheetScanId
                )
            }
            
            // Sign the URL or load local data
            let storedCoverReference = dbPlaylist.coverImageUrl?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            var displayImageUrl = storedCoverReference
            var displayImageData: Data? = nil
            
            if let path = storedCoverReference {
                if path.hasPrefix("doc_") {
                    // Local document storage fallback
                    if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let url = documentsURL.appendingPathComponent(path)
                        displayImageData = try? Data(contentsOf: url)
                    }
                } else {
                    displayImageUrl = try await resolveCoverImageURL(from: path)
                }
            }
            
            let data = PlaylistData(
                id: dbPlaylist.id,
                title: dbPlaylist.name,
                tags: dbPlaylist.description ?? "",
                imageUrl: displayImageUrl,
                imageData: displayImageData,
                tracks: tracks,
                createdAt: dbPlaylist.createdAt,
                isPublic: dbPlaylist.isPublic
            )
            remotePlaylists.append(data)
        }

        cachePlaylists(remotePlaylists)
        return remotePlaylists
    }

    public func cachedPlaylistsSnapshot() -> [PlaylistData] {
        playlistCacheLock.lock()
        defer { playlistCacheLock.unlock() }
        return playlistCache
    }

    public func prewarmPlaylistCacheIfNeeded() {
        playlistCacheLock.lock()
        let hasCachedPlaylists = !playlistCache.isEmpty
        let hasWarmTask = playlistCacheWarmTask != nil
        playlistCacheLock.unlock()

        guard !hasCachedPlaylists, !hasWarmTask else { return }

        let warmTask = Task { [weak self] in
            defer {
                self?.playlistCacheLock.lock()
                self?.playlistCacheWarmTask = nil
                self?.playlistCacheLock.unlock()
            }
            _ = try? await self?.fetchRemotePlaylists()
        }

        playlistCacheLock.lock()
        playlistCacheWarmTask = warmTask
        playlistCacheLock.unlock()
    }
    
    // MARK: - Fetch Tracks for a Specific Playlist
    
    public func fetchPlaylistTracks(playlistId: UUID) async throws -> [PlaylistTrack] {
        let dbItems: [DBPlaylistItem] = try await SupabaseManager.shared.client
            .from("playlist_items")
            .select()
            .eq("playlist_id", value: playlistId.uuidString)
            .order("position", ascending: false)
            .execute()
            .value
        
        return dbItems.map { item in
            PlaylistTrack(
                id: UUID(),
                trackId: item.trackId,
                title: item.trackTitle,
                artist: item.artistName,
                playlistItemId: item.id,
                sheetScanId: item.sheetScanId
            )
        }
    }
    
    // MARK: - Add Track to Playlist
    
    public func addTrackToPlaylist(
        playlistId: UUID,
        title: String,
        artist: String,
        trackId: String? = nil
    ) async throws -> PlaylistTrack {
        let session = try await SupabaseManager.shared.client.auth.session
        let userId = session.user.id
        
        // Get current max position
        let existingItems: [DBPlaylistItem] = try await SupabaseManager.shared.client
            .from("playlist_items")
            .select()
            .eq("playlist_id", value: playlistId.uuidString)
            .order("position", ascending: false)
            .limit(1)
            .execute()
            .value
        
        let nextPosition = (existingItems.first?.position ?? -1) + 1
        
        let insertItem = DBPlaylistItemInsert(
            playlistId: playlistId,
            userId: userId,
            trackId: trackId ?? UUID().uuidString,
            trackTitle: title,
            artistName: artist,
            sheetScanId: nil,
            position: nextPosition
        )
        
        let inserted: DBPlaylistItem = try await SupabaseManager.shared.client
            .from("playlist_items")
            .insert(insertItem)
            .select()
            .single()
            .execute()
            .value
        
        debugLog("✅ Added track '\(title)' to playlist \(playlistId)")
        
        return PlaylistTrack(
            id: UUID(),
            trackId: inserted.trackId,
            title: inserted.trackTitle,
            artist: inserted.artistName,
            playlistItemId: inserted.id,
            sheetScanId: inserted.sheetScanId
        )
    }
    
    // MARK: - Add Upload Scan to Playlist
    
    /// Inserts a user's existing upload (scan) as a track into the playlist.
    /// Links via `sheet_scan_id` so data is always recoverable from Supabase.
    public func addScanToPlaylist(playlistId: UUID, scan: UploadScanItem) async throws -> PlaylistTrack {
        let session = try await SupabaseManager.shared.client.auth.session
        let userId = session.user.id
        
        let existingItems: [DBPlaylistItem] = try await SupabaseManager.shared.client
            .from("playlist_items")
            .select()
            .eq("playlist_id", value: playlistId.uuidString)
            .order("position", ascending: false)
            .limit(1)
            .execute()
            .value
        
        let nextPosition = (existingItems.first?.position ?? -1) + 1
        
        let insertItem = DBPlaylistItemInsert(
            playlistId: playlistId,
            userId: userId,
            trackId: String(scan.id),     // use scan id as trackId
            trackTitle: scan.title,
            artistName: "My Upload",       // uploads don't have an artist field
            sheetScanId: scan.id,
            position: nextPosition
        )
        
        let inserted: DBPlaylistItem = try await SupabaseManager.shared.client
            .from("playlist_items")
            .insert(insertItem)
            .select()
            .single()
            .execute()
            .value
        
        debugLog("✅ Added scan \(scan.id) '\(scan.title)' to playlist \(playlistId)")
        
        return PlaylistTrack(
            id: UUID(),
            trackId: inserted.trackId,
            title: inserted.trackTitle,
            artist: inserted.artistName,
            playlistItemId: inserted.id,
            sheetScanId: inserted.sheetScanId
        )
    }
    
    // MARK: - Fetch labeled PDF URL for a scan

    /// Reads `json_data.output_url` from the `scans` table for the given scan ID.
    /// Returns `nil` gracefully when no output URL exists yet.
    public func fetchPDFURL(forScanId scanId: Int64) async throws -> URL? {
        struct ScanRow: Codable {
            let jsonData: AnyScan?
            enum CodingKeys: String, CodingKey { case jsonData = "json_data" }
        }
        struct AnyScan: Codable {
            let outputUrl: String?
            enum CodingKeys: String, CodingKey { case outputUrl = "output_url" }
        }

        let rows: [ScanRow] = try await SupabaseManager.shared.client
            .from("scans")
            .select("json_data")
            .eq("id", value: Int(scanId))
            .limit(1)
            .execute()
            .value

        guard let urlString = rows.first?.jsonData?.outputUrl,
              !urlString.isEmpty,
              let url = URL(string: urlString) else { return nil }
        return url
    }

    /// Fetches the labeled PDF URL string from the scans table for a given scan ID.
    /// Returns the result URL string (may be relative path or full URL).
    public func fetchJobPDFURLString(forScanId scanId: Int64) async throws -> String? {
        struct ScanRow: Codable {
            let jobId: String?
            let jsonData: AnyScan?
            enum CodingKeys: String, CodingKey {
                case jobId = "job_id"
                case jsonData = "json_data"
            }
        }
        struct AnyScan: Codable {
            let outputUrl: String?
            enum CodingKeys: String, CodingKey { case outputUrl = "output_url" }
        }

        let rows: [ScanRow] = try await SupabaseManager.shared.client
            .from("scans")
            .select("job_id, json_data")
            .eq("id", value: Int(scanId))
            .limit(1)
            .execute()
            .value

        // Try to get output_url from json_data first
        if let urlString = rows.first?.jsonData?.outputUrl, !urlString.isEmpty {
            return urlString
        }
        
        // If that doesn't work, try to fetch from jobs table if we have a job_id
        if let jobId = rows.first?.jobId, !jobId.isEmpty {
            struct JobRow: Codable {
                let resultUrl: String?
                enum CodingKeys: String, CodingKey {
                    case resultUrl = "result_url"
                }
            }
            
            let jobRows: [JobRow] = try await SupabaseManager.shared.client
                .from("jobs")
                .select("result_url")
                .eq("id", value: jobId)
                .limit(1)
                .execute()
                .value
            
            if let resultUrl = jobRows.first?.resultUrl, !resultUrl.isEmpty {
                return resultUrl
            }
        }
        
        return nil
    }

    // MARK: - Fetch User Uploads

    /// Fetches all scans for the current user, mapped to lightweight UploadScanItem models.
    public func fetchUserUploads() async throws -> [UploadScanItem] {
        let session = try await SupabaseManager.shared.client.auth.session
        let userId = session.user.id
        
        struct ScanRow: Codable {
            let id: Int64
            let jsonData: ScanJSON?
            let originalFilename: String?
            let fileType: String?
            let processedAt: String?
            let updatedAt: String?
            enum CodingKeys: String, CodingKey {
                case id
                case jsonData = "json_data"
                case originalFilename = "original_filename"
                case fileType = "file_type"
                case processedAt = "processed_at"
                case updatedAt = "updated_at"
            }
        }
        struct ScanJSON: Codable {
            let title: String?
            let originalFilename: String?
            let uploadedAt: String?
            let fileSizeBytes: Int?
            let fileSize: Int?
            enum CodingKeys: String, CodingKey {
                case title
                case originalFilename = "original_filename"
                case uploadedAt = "uploaded_at"
                case fileSizeBytes = "file_size_bytes"
                case fileSize = "file_size"
            }
        }
        
        let rows: [ScanRow] = try await SupabaseManager.shared.client
            .from("scans")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("updated_at", ascending: false)
            .limit(100)
            .execute()
            .value
        
        // De-duplicate by id
        var seen = Set<Int64>()
        let unique = rows.filter { seen.insert($0.id).inserted }
        
        return unique.map { row -> UploadScanItem in
            let json = row.jsonData
            
            let title: String = {
                if let t = json?.title, !t.isEmpty { return t }
                if let f = json?.originalFilename { return f.hasSuffix(".pdf") ? String(f.dropLast(4)) : f }
                if let f = row.originalFilename { return f.hasSuffix(".pdf") ? String(f.dropLast(4)) : f }
                return "Upload #\(row.id)"
            }()
            
            let fileType = (row.fileType ?? "").contains("pdf") ? "PDF" : "FILE"
            let dateStr = Self.formatUploadDate(json?.uploadedAt ?? row.processedAt ?? row.updatedAt)
            let sizeStr = Self.formatUploadSize(fileSizeBytes: json?.fileSizeBytes ?? json?.fileSize)
            
            return UploadScanItem(id: row.id, title: title, fileType: fileType,
                                  dateString: dateStr, sizeString: sizeStr)
        }
    }
    
    private static func formatUploadDate(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return relativeUploadDate(d) }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return relativeUploadDate(d) }
        return ""
    }
    private static func relativeUploadDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: date)
    }
    private static func formatUploadSize(fileSizeBytes: Int?) -> String {
        guard let b = fileSizeBytes else { return "" }
        let kb = Double(b) / 1024.0
        return kb < 1024 ? String(format: "%.0f KB", kb) : String(format: "%.1f MB", kb / 1024.0)
    }
    
    // MARK: - Remove Track from Playlist
    
    public func removeTrackFromPlaylist(playlistItemId: Int64) async throws {
        try await SupabaseManager.shared.client
            .from("playlist_items")
            .delete()
            .eq("id", value: Int(playlistItemId))
            .execute()
        
        debugLog("✅ Removed playlist item \(playlistItemId)")
    }
    
    // MARK: - Update Methods
    
    public func updatePlaylistName(id: UUID, newName: String) async throws {
        let validatedName = InputValidator.limit(
            InputValidator.trimOnSubmit(newName),
            maxLength: InputValidator.nameMaxLength
        )
        guard InputValidator.validateRequired(validatedName, message: "Playlist name is required.") == nil else {
            throw PlaylistError.invalidName
        }

        try await SupabaseManager.shared.client
            .from("playlists")
            .update(["name": validatedName])
            .eq("id", value: id.uuidString)
            .execute()
        
        debugLog("✅ Updated playlist \(id) name to: \(validatedName)")
    }
    
    public func updateTrackName(playlistItemId: Int64, newTitle: String) async throws {
        let validatedTitle = InputValidator.limit(
            InputValidator.trimOnSubmit(newTitle),
            maxLength: InputValidator.nameMaxLength
        )
        guard InputValidator.validateRequired(validatedTitle, message: "Track title is required.") == nil else {
            throw PlaylistError.invalidName
        }

        try await SupabaseManager.shared.client
            .from("playlist_items")
            .update(["track_title": validatedTitle])
            .eq("id", value: Int(playlistItemId))
            .execute()
        
        debugLog("✅ Updated track \(playlistItemId) title to: \(validatedTitle)")
    }
    
    // MARK: - Delete Playlist
    
    public func deletePlaylist(id: UUID) async {
        do {
            // Delete all items first (in case no cascade)
            try await SupabaseManager.shared.client
                .from("playlist_items")
                .delete()
                .eq("playlist_id", value: id.uuidString)
                .execute()
            
            try await SupabaseManager.shared.client
                .from("playlists")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            
            debugLog("✅ Deleted playlist \(id)")
        } catch {
            debugLog("❌ Delete error: \(error)")
        }
    }
    
    // MARK: - Create Playlist
    
    public func createPlaylist(name: String, image: UIImage?) async throws -> UUID {
        let session = try await SupabaseManager.shared.client.auth.session
        let userId = session.user.id

        let sanitizedName = InputValidator.limit(
            InputValidator.trimOnSubmit(name),
            maxLength: InputValidator.nameMaxLength
        )
        guard InputValidator.validateRequired(sanitizedName, message: "Playlist name is required.") == nil else {
            throw PlaylistError.invalidName
        }

        var coverImageUrl: String? = nil
        
        // Use provided image or fallback to a default app asset
        let finalImage: UIImage
        if let userImg = image {
            finalImage = userImg
        } else {
            let defaultNames = (1...16).map { "trackimage_\($0)" }
            guard let randomName = defaultNames.randomElement() else {
                throw PlaylistError.missingDefaultArtwork
            }
            guard let fallbackImage = UIImage(named: randomName) ?? UIImage(named: "trackimage_1") else {
                throw PlaylistError.missingDefaultArtwork
            }
            finalImage = fallbackImage
        }

        do {
            coverImageUrl = try await uploadImageToStorage(image: finalImage, userId: userId)
        } catch {
            debugLog("⚠️ Image upload failed, falling back to local cache")
            if let localFile = saveImageToDocuments(image: finalImage) {
                coverImageUrl = localFile
            }
        }

        let newPlaylist = DBPlaylistInsert(
            userId: userId,
            name: sanitizedName,
            description: "Custom Playlist",
            coverImageUrl: coverImageUrl,
            isPublic: false
        )

        let inserted: DBPlaylist = try await SupabaseManager.shared.client
            .from("playlists")
            .insert(newPlaylist)
            .select()
            .single()
            .execute()
            .value

        if let coverImageUrl,
           inserted.coverImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines) != coverImageUrl {
            do {
                try await persistCoverImageReference(coverImageUrl, forPlaylistID: inserted.id)
            } catch {
                debugLog("❌ Failed to persist cover path for playlist \(inserted.id):", error)
            }
        }

        debugLog("✅ Created playlist with ID: \(inserted.id)")
        return inserted.id
    }
    
    // MARK: - Image Upload
    
    private func uploadImageToStorage(image: UIImage, userId: UUID) async throws -> String {
        guard let sourceData = image.normalized().pngData() ?? image.normalized().jpegData(compressionQuality: 1.0) else {
            throw PlaylistError.invalidData
        }

        let prepared: PreparedImage
        switch ImageValidator.validateAndPrepareImageData(sourceData, typeIdentifier: nil) {
        case .success(let result):
            prepared = result
        case .failure:
            throw PlaylistError.invalidData
        }
        
        let fileName = "\(UUID().uuidString).\(prepared.fileExtension)"
        let storagePath = "\(userId.uuidString)/\(fileName)"
        
        let client = SupabaseManager.shared.client.storage.from(playlistCoverBucket)
        let options = FileOptions(contentType: prepared.mimeType)
        
        do {
            try await client.upload(storagePath, data: prepared.data, options: options)
        } catch let nsError as NSError where nsError.domain == NSURLErrorDomain && nsError.code == -1005 {
            // Known iOS Simulator networking bug: "Network connection lost."
            debugLog("⚠️ Re-attempting upload due to Simulator HTTP -1005 bug...")
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try await client.upload(storagePath, data: prepared.data, options: options)
        }
        // Always return the storage path so the DB stores the exact object location.
        // It will be resolved to a short-lived signed URL during fetch.
        return storagePath
    }
    
    private func saveImageToDocuments(image: UIImage) -> String? {
        guard let data = image.normalized().pngData() else { return nil }
        let filename = "doc_\(UUID().uuidString).png"
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory,
                                                          in: .userDomainMask).first else {
            return nil
        }
        let url = documentsURL.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return filename
        } catch {
            debugLog("❌ Failed to save image to documents:", error)
            return nil
        }
    }

    public func resolveCoverImageURL(from storedValue: String) async throws -> String {
        let trimmedValue = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return storedValue }

        if let cachedURL = cachedResolvedCoverURL(for: trimmedValue) {
            return cachedURL
        }

        let candidatePaths = normalizedRemoteCoverPaths(from: trimmedValue)
        guard !candidatePaths.isEmpty else {
            return trimmedValue
        }

        let storage = SupabaseManager.shared.client.storage.from(playlistCoverBucket)

        for remotePath in candidatePaths {
            do {
                let resolvedURL = try await storage
                    .createSignedURL(path: remotePath, expiresIn: coverSignedURLTTL)
                    .absoluteString
                cacheResolvedCoverURL(resolvedURL, for: trimmedValue)
                return resolvedURL
            } catch {
                debugLog("⚠️ Failed to create signed cover URL for path \(remotePath):", error)
            }
        }

        if let fallbackPath = candidatePaths.first {
            do {
                let resolvedURL = try storage
                    .getPublicURL(path: fallbackPath)
                    .absoluteString
                cacheResolvedCoverURL(resolvedURL, for: trimmedValue)
                return resolvedURL
            } catch {
                debugLog("❌ Failed to resolve cover URL for path \(fallbackPath):", error)
            }
        }

        return trimmedValue
    }

    private func persistCoverImageReference(_ coverImageUrl: String, forPlaylistID playlistID: UUID) async throws {
        try await SupabaseManager.shared.client
            .from("playlists")
            .update(["cover_image_url": coverImageUrl])
            .eq("id", value: playlistID.uuidString)
            .execute()
    }

    private func normalizedRemoteCoverPaths(from storedValue: String) -> [String] {
        let trimmedValue = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return [] }
        guard !trimmedValue.hasPrefix("doc_") else { return [] }

        if let url = URL(string: trimmedValue), url.scheme != nil {
            if let extracted = extractBucketObjectPath(from: url) {
                return [extracted]
            }
            return []
        }

        let withoutLeadingSlash = trimmedValue.hasPrefix("/") ? String(trimmedValue.dropFirst()) : trimmedValue
        let bucketPrefix = "\(playlistCoverBucket)/"
        if withoutLeadingSlash.hasPrefix(bucketPrefix) {
            return [String(withoutLeadingSlash.dropFirst(bucketPrefix.count))]
        }

        if UIImage(named: withoutLeadingSlash) != nil {
            return []
        }

        if !withoutLeadingSlash.contains("/") && !withoutLeadingSlash.contains(".") {
            return []
        }

        var candidates: [String] = []

        if withoutLeadingSlash.contains("/") || withoutLeadingSlash.contains(".") {
            candidates.append(withoutLeadingSlash)
        }

        if !withoutLeadingSlash.contains("/"),
           let userId = SupabaseManager.shared.client.auth.currentUser?.id.uuidString {
            candidates.append("\(userId)/\(withoutLeadingSlash)")
        }

        var uniqueCandidates: [String] = []
        var seen = Set<String>()
        for candidate in candidates where seen.insert(candidate).inserted {
            uniqueCandidates.append(candidate)
        }
        return uniqueCandidates
    }

    private func extractBucketObjectPath(from url: URL) -> String? {
        let decodedPath = url.path.removingPercentEncoding ?? url.path
        let marker = "/\(playlistCoverBucket)/"
        guard let range = decodedPath.range(of: marker) else { return nil }
        return String(decodedPath[range.upperBound...])
    }

    private func cachedResolvedCoverURL(for storedValue: String) -> String? {
        resolvedCoverURLCacheLock.lock()
        defer { resolvedCoverURLCacheLock.unlock() }

        guard let cachedEntry = resolvedCoverURLCache[storedValue] else { return nil }
        if cachedEntry.expiresAt <= Date() {
            resolvedCoverURLCache.removeValue(forKey: storedValue)
            return nil
        }
        return cachedEntry.url
    }

    private func cacheResolvedCoverURL(_ url: String, for storedValue: String) {
        resolvedCoverURLCacheLock.lock()
        defer { resolvedCoverURLCacheLock.unlock() }

        resolvedCoverURLCache[storedValue] = (
            url: url,
            expiresAt: Date().addingTimeInterval(TimeInterval(coverSignedURLTTL - 60))
        )
    }

    private func cachePlaylists(_ playlists: [PlaylistData]) {
        playlistCacheLock.lock()
        defer { playlistCacheLock.unlock() }
        playlistCache = playlists
    }
}
