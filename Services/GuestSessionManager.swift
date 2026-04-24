import Foundation
import Supabase
import Auth
internal import PostgREST

final class GuestSessionManager {
    static let shared = GuestSessionManager()

    let kGuestID = "guestID"
    let kHasSeenInfoCard = "hasSeenInfoCard"
    let kHasCompletedOnboarding = "hasCompletedOnboarding"
    let kGuestOnboardingData = "guestOnboardingData"
    let kGuestDisplayName = "guestDisplayName"
    let kGuestUsername = "guestUsername"

    private struct GuestOnboardingPayload: Encodable {
        let id: String
        let level: String
        let genres: [String]
        let practice_mins: Int
    }

    private struct ExistingOnboardingRow: Decodable {
        let id: String
    }

    private init() {}

    func getOrCreateGuestID() -> String {
        if let guestID = UserDefaults.standard.string(forKey: kGuestID), !guestID.isEmpty {
            return guestID
        }

        let guestID = UUID().uuidString
        UserDefaults.standard.set(guestID, forKey: kGuestID)
        return guestID
    }

    var hasSeenInfoCard: Bool {
        get { UserDefaults.standard.bool(forKey: kHasSeenInfoCard) }
        set { UserDefaults.standard.set(newValue, forKey: kHasSeenInfoCard) }
    }

    func isAuthenticated() -> Bool {
        SupabaseManager.shared.client.auth.currentSession != nil
    }

    func isGuest() -> Bool {
        !isAuthenticated()
    }

    func saveGuestOnboardingData(_ data: [String: Any]) {
        UserDefaults.standard.set(data, forKey: kGuestOnboardingData)
    }

    func loadGuestOnboardingData() -> [String: Any]? {
        UserDefaults.standard.dictionary(forKey: kGuestOnboardingData)
    }

    func guestDisplayName() -> String? {
        if let storedName = UserDefaults.standard.string(forKey: kGuestDisplayName)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !storedName.isEmpty {
            return storedName
        }

        if let onboardingName = loadGuestOnboardingData()?["full_name"] as? String {
            let trimmedName = onboardingName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedName.isEmpty ? nil : trimmedName
        }

        return nil
    }

    func saveGuestDisplayName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            UserDefaults.standard.removeObject(forKey: kGuestDisplayName)
        } else {
            UserDefaults.standard.set(trimmedName, forKey: kGuestDisplayName)
        }

        var onboardingData = loadGuestOnboardingData() ?? [:]
        onboardingData["full_name"] = trimmedName
        saveGuestOnboardingData(onboardingData)
    }

    func guestUsername() -> String? {
        if let storedUsername = UserDefaults.standard.string(forKey: kGuestUsername)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !storedUsername.isEmpty {
            return storedUsername
        }

        if let onboardingUsername = loadGuestOnboardingData()?["username"] as? String {
            let trimmedUsername = onboardingUsername.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedUsername.isEmpty ? nil : trimmedUsername
        }

        return nil
    }

    func saveGuestUsername(_ username: String) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedUsername.isEmpty {
            UserDefaults.standard.removeObject(forKey: kGuestUsername)
        } else {
            UserDefaults.standard.set(trimmedUsername, forKey: kGuestUsername)
        }

        var onboardingData = loadGuestOnboardingData() ?? [:]
        onboardingData["username"] = trimmedUsername
        saveGuestOnboardingData(onboardingData)
    }

    func guestAvatarIdentifier() -> String? {
        loadGuestOnboardingData()?["avatar_url"] as? String
    }

    func guestPracticeGoalMinutes() -> Int? {
        loadGuestOnboardingData()?["practice_mins"] as? Int
    }

    @discardableResult
    func migrateGuestIfNeeded() async -> Bool {
        guard let onboardingData = loadGuestOnboardingData() else {
            return false
        }

        guard let session = try? await SupabaseManager.shared.client.auth.session else {
            debugLog("[GuestSessionManager] Missing auth session during guest migration")
            return false
        }

        guard let level = onboardingData["level"] as? String,
              let genres = onboardingData["genres"] as? [String],
              let practiceMins = onboardingData["practice_mins"] as? Int else {
            debugLog("[GuestSessionManager] Guest onboarding payload was incomplete")
            return false
        }

        let userId = session.user.id.uuidString
        let avatarUrl = onboardingData["avatar_url"] as? String ?? "icon_1"
        let payload = GuestOnboardingPayload(
            id: userId,
            level: level,
            genres: genres,
            practice_mins: practiceMins
        )

        do {
            let existingOnboarding: ExistingOnboardingRow? = try await SupabaseManager.shared.client
                .from("user_onboarding")
                .select("id")
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            if existingOnboarding != nil {
                clearGuestState()
                return false
            }

            try await SupabaseManager.shared.client
                .from("profiles")
                .upsert(["id": userId, "avatar_url": avatarUrl])
                .execute()

            try await SupabaseManager.shared.client
                .from("user_onboarding")
                .upsert(payload)
                .execute()

            clearGuestState()
            return true
        } catch {
            debugLog("[GuestSessionManager] Guest migration failed: \(error.localizedDescription)")
            return false
        }
    }

    func clearGuestState() {
        UserDefaults.standard.removeObject(forKey: kGuestID)
        UserDefaults.standard.removeObject(forKey: kHasCompletedOnboarding)
        UserDefaults.standard.removeObject(forKey: kGuestOnboardingData)
        UserDefaults.standard.removeObject(forKey: kGuestDisplayName)
        UserDefaults.standard.removeObject(forKey: kGuestUsername)
        SupabaseProgressManager.clearGuestProgressData()
    }
}
