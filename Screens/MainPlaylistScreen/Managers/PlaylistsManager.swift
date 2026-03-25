import Foundation
import UIKit
import Supabase
import Auth
internal import PostgREST

public enum PlaylistError: Error {
    case invalidData
    case uploadFailed
    case missingDefaultArtwork
}

public final class PlaylistsManager {
    public static let shared = PlaylistsManager()
    
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
                .order("position")
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
            var displayImageUrl = dbPlaylist.coverImageUrl
            var displayImageData: Data? = nil
            
            if let path = displayImageUrl, !path.contains("://") {
                if path.hasPrefix("doc_") {
                    // Local document storage fallback
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                        .first!.appendingPathComponent(path)
                    displayImageData = try? Data(contentsOf: url)
                } else {
                    // Remote Supabase storage
                    do {
                        if let signedUrl = try? await SupabaseManager.shared.client.storage
                            .from("PlayListCover")
                            .createSignedURL(path: path, expiresIn: 60 * 60 * 24 * 7) { // 7 days
                            displayImageUrl = signedUrl.absoluteString
                        }
                    } catch {
                        print("❌ Failed to sign URL for path \(path):", error)
                    }
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
        
        return remotePlaylists
    }
    
    // MARK: - Fetch Tracks for a Specific Playlist
    
    public func fetchPlaylistTracks(playlistId: UUID) async throws -> [PlaylistTrack] {
        let dbItems: [DBPlaylistItem] = try await SupabaseManager.shared.client
            .from("playlist_items")
            .select()
            .eq("playlist_id", value: playlistId.uuidString)
            .order("position")
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
    
    public func addTrackToPlaylist(playlistId: UUID, title: String, artist: String) async throws -> PlaylistTrack {
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
            trackId: UUID().uuidString,
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
        
        print("✅ Added track '\(title)' to playlist \(playlistId)")
        
        return PlaylistTrack(
            id: UUID(),
            trackId: inserted.trackId,
            title: inserted.trackTitle,
            artist: inserted.artistName,
            playlistItemId: inserted.id
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
        
        print("✅ Added scan \(scan.id) '\(scan.title)' to playlist \(playlistId)")
        
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
        
        print("✅ Removed playlist item \(playlistItemId)")
    }
    
    // MARK: - Update Methods
    
    public func updatePlaylistName(id: UUID, newName: String) async throws {
        try await SupabaseManager.shared.client
            .from("playlists")
            .update(["name": newName])
            .eq("id", value: id.uuidString)
            .execute()
        
        print("✅ Updated playlist \(id) name to: \(newName)")
    }
    
    public func updateTrackName(playlistItemId: Int64, newTitle: String) async throws {
        try await SupabaseManager.shared.client
            .from("playlist_items")
            .update(["track_title": newTitle])
            .eq("id", value: Int(playlistItemId))
            .execute()
        
        print("✅ Updated track \(playlistItemId) title to: \(newTitle)")
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
            
            print("✅ Deleted playlist \(id)")
        } catch {
            print("❌ Delete error: \(error)")
        }
    }
    
    // MARK: - Create Playlist
    
    public func createPlaylist(name: String, image: UIImage?) async throws -> UUID {
        let session = try await SupabaseManager.shared.client.auth.session
        let userId = session.user.id

        
        var coverImageUrl: String? = nil
        
        // Use provided image or fallback to a default app asset
        let finalImage: UIImage
        if let userImg = image {
            finalImage = userImg
        } else {
            let defaultNames = (1...16).map { "trackimage_\($0)" }
            let randomName = defaultNames.randomElement()!
            finalImage = UIImage(named: randomName) ?? UIImage(named: "trackimage_1")!
        }
        
        do {
            coverImageUrl = try await uploadImageToStorage(image: finalImage)
        } catch {
            print("⚠️ Image upload failed, falling back to local cache")
            if let localFile = saveImageToDocuments(image: finalImage) {
                coverImageUrl = localFile

     

            }
        } else {
            // No image provided — store a stable local asset name (same approach as songs)
            let assetIndex = Int.random(in: 1...16)
            coverImageUrl = "trackimage_\(assetIndex)"
        }

        let newPlaylist = DBPlaylist(
            id: UUID(),
            userId: userId,
            name: name,
            description: "Custom Playlist",
            coverImageUrl: coverImageUrl,
            isPublic: false,
            createdAt: Date(),
            updatedAt: Date()
        )

        let inserted: DBPlaylist = try await SupabaseManager.shared.client
            .from("playlists")
            .insert(newPlaylist)
            .select()
            .single()
            .execute()
            .value

        print("✅ Created playlist with ID: \(inserted.id)")
        return inserted.id
    }
    
    // MARK: - Image Upload
    
    private func uploadImageToStorage(image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw PlaylistError.invalidData
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        
        let client = SupabaseManager.shared.client.storage.from("PlayListCover")
        let options = FileOptions(contentType: "image/jpeg")
        
        do {
            try await client.upload(fileName, data: imageData, options: options)
        } catch let nsError as NSError where nsError.domain == NSURLErrorDomain && nsError.code == -1005 {
            // Known iOS Simulator networking bug: "Network connection lost."
            print("⚠️ Re-attempting upload due to Simulator HTTP -1005 bug...")
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try await client.upload(fileName, data: imageData, options: options)
        }
        
        // Return the fileName (path) instead of a signed URL.
        // This ensures we store the persistent path in the database.
        return fileName
    }
    
    private func saveImageToDocuments(image: UIImage) -> String? {
        guard let data = image.pngData() else { return nil }
        let filename = "doc_\(UUID().uuidString).png"
        let url = FileManager.default.urls(for: .documentDirectory,
                                           in: .userDomainMask).first!.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return filename
        } catch {
            print("❌ Failed to save image to documents:", error)
            return nil
        }
    }
}
