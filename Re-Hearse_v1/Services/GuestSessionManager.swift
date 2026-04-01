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

    enum InitialScreen {
        case infoCard
        case onboarding
        case home
    }

    private struct GuestOnboardingPayload: Encodable {
        let id: String
        let level: String
        let genres: [String]
        let practice_mins: Int
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

    func migrateGuestIfNeeded() async {
        guard let onboardingData = loadGuestOnboardingData() else {
            return
        }

        guard let session = try? await SupabaseManager.shared.client.auth.session else {
            debugLog("[GuestSessionManager] Missing auth session during guest migration")
            return
        }

        guard let level = onboardingData["level"] as? String,
              let genres = onboardingData["genres"] as? [String],
              let practiceMins = onboardingData["practice_mins"] as? Int else {
            debugLog("[GuestSessionManager] Guest onboarding payload was incomplete")
            return
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
            try await SupabaseManager.shared.client
                .from("profiles")
                .upsert(["id": userId, "avatar_url": avatarUrl])
                .execute()

            try await SupabaseManager.shared.client
                .from("user_onboarding")
                .upsert(payload)
                .execute()

            clearGuestState()
        } catch {
            debugLog("[GuestSessionManager] Guest migration failed: \(error.localizedDescription)")
        }
    }

    func resolveInitialScreen() -> InitialScreen {
        if isAuthenticated() {
            return .home
        }

        if !UserDefaults.standard.bool(forKey: kHasSeenInfoCard) {
            return .infoCard
        }

        if !UserDefaults.standard.bool(forKey: kHasCompletedOnboarding) {
            return .onboarding
        }

        return .home
    }

    func clearGuestState() {
        UserDefaults.standard.removeObject(forKey: kGuestID)
        UserDefaults.standard.removeObject(forKey: kHasCompletedOnboarding)
        UserDefaults.standard.removeObject(forKey: kGuestOnboardingData)
    }
}
