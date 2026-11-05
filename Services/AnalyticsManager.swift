import Foundation
import FirebaseAnalytics

enum AnalyticsManager {
    static func logEvent(_ name: String, parameters: [String: Any?] = [:]) {
        Analytics.logEvent(name, parameters: sanitized(parameters))
    }

    static func logAuthStarted(mode: String) {
        logEvent("\(mode)_started", parameters: ["method": "email"])
    }

    static func logAuthFailed(mode: String, reason: String) {
        logEvent("\(mode)_failed", parameters: [
            "method": "email",
            "reason": normalized(reason)
        ])
    }

    static func logLoginSuccess() {
        logEvent("login_success", parameters: ["method": "email"])
    }

    static func logOTPSent() {
        logEvent("otp_sent", parameters: ["method": "email"])
    }

    static func logOTPResent() {
        logEvent("otp_resent", parameters: ["method": "email"])
    }

    static func logOTPVerified() {
        logEvent("otp_verified", parameters: ["method": "email"])
    }

    static func logPlaylistCreated() {
        logEvent("playlist_created")
    }

    static func logPlaylistOpened(playlistId: UUID) {
        logEvent("playlist_opened", parameters: ["playlist_id": playlistId.uuidString])
    }

    static func logTrackAddedToPlaylist(playlistId: UUID) {
        logEvent("track_added_to_playlist", parameters: ["playlist_id": playlistId.uuidString])
    }

    static func logUploadStarted(source: String, fileType: String) {
        logEvent("upload_started", parameters: [
            "source": source,
            "file_type": fileType
        ])
    }

    static func logUploadCompleted(source: String, fileType: String, fileSizeBytes: Int) {
        logEvent("upload_completed", parameters: [
            "source": source,
            "file_type": fileType,
            "file_size_bytes": fileSizeBytes
        ])
    }

    static func logUploadFailed(source: String, reason: String) {
        logEvent("upload_failed", parameters: [
            "source": source,
            "reason": normalized(reason)
        ])
    }

    private static func sanitized(_ parameters: [String: Any?]) -> [String: Any] {
        var sanitized: [String: Any] = [:]

        for (key, value) in parameters {
            guard let value else { continue }

            switch value {
            case let string as String:
                sanitized[key] = String(string.prefix(100))
            case let bool as Bool:
                sanitized[key] = bool ? 1 : 0
            case let int as Int:
                sanitized[key] = int
            case let double as Double:
                sanitized[key] = double
            case let float as Float:
                sanitized[key] = Double(float)
            case let uuid as UUID:
                sanitized[key] = uuid.uuidString
            default:
                sanitized[key] = String(describing: value).prefix(100).description
            }
        }

        return sanitized
    }

    private static func normalized(_ value: String) -> String {
        let lowered = value.lowercased()
        let allowed = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "_"
        }
        let collapsed = String(allowed)
            .replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return String((collapsed.isEmpty ? "unknown" : collapsed).prefix(100))
    }
}




