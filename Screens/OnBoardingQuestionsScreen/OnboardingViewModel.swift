import Foundation
import Supabase
import Auth
internal import PostgREST
import UIKit
import Combine

// MARK: - Codable payload matching the DB schema
private struct OnboardingPayload: Encodable {
    let id: String
    let level: String
    let genres: [String]
    let practice_mins: Int
}

class OnboardingViewModel: ObservableObject {

    // Q1 — level
    @Published var selectedLevel: String?

    // Q2 — genres (multi-select)
    @Published var selectedGenres: Set<String> = []

    // Q3 — practice minutes
    @Published var practiceMins: Int = 10

    @Published var isSaving = false
    @Published var errorMessage: String?

    // MARK: - Genre display → DB value map
    static let genreDBMap: [String: String] = [
        "Classical":          "classical",
        "Jazz & Blues":       "jazz_blues",
        "Contemporary":       "contemporary",
        "Film Scores":        "film_scores",
        "Pop Ballads":        "pop_ballads",
        "Ambient":            "ambient",
        "Gospel & Sacred":    "gospel_sacred"
    ]

    // MARK: - Level display → DB value map
    static let levelDBMap: [String: String] = [
        "Absolute beginner": "beginner",
        "Some basics":       "some_basics",
        "Intermediate":      "intermediate",
        "Advanced":          "advanced"
    ]
    
    func skipOnboarding(userId: String? = nil) {
        if let userId = userId {
            Task {
                // Use actual selections even on skip if they exist
                let level = selectedLevel ?? "skipped"
                let genres = selectedGenres.isEmpty ? ["skipped"] : Array(selectedGenres)
                
                await finalizeOnboarding(
                    userId: userId,
                    level: level,
                    genres: genres,
                    mins: 10 // Default for skip
                )
            }
        } else {
            navigateToHome()
        }
    }
    
    private func finalizeOnboarding(userId: String, level: String, genres: [String], mins: Int) async {
        let client = SupabaseManager.shared.client
        let randomIcon = "icon_\(Int.random(in: 1...9))"
        
        let dbLevel = OnboardingViewModel.levelDBMap[level] ?? level
        
        let payload = OnboardingPayload(
            id: userId,
            level: dbLevel,
            genres: genres,
            practice_mins: mins
        )
        
        do {
            // 1. Update Profile (Avatar) first to ensure existence
            try await client
                .from("profiles")
                .upsert(["id": userId, "avatar_url": randomIcon])
                .execute()
            
            // 2. Update Onboarding state
            try await client
                .from("user_onboarding")
                .upsert(payload)
                .execute()
            
            print("Successfully finalized onboarding for \(userId) with icon \(randomIcon)")
        } catch {
            print("Database error during onboarding finalization: \(error.localizedDescription)")
        }
        
        // Always navigate Home if we have a userId, even if DB updates failed 
        // (to not get the user stuck, though icon might be missing)
        await MainActor.run {
            self.navigateToHome()
        }
    }
    
    private func navigateToHome() {
        let home = MainTabBarController()
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.keyWindow else { return }

        UIView.transition(with: window,
                          duration: 0.35,
                          options: .transitionCrossDissolve,
                          animations: { window.rootViewController = home },
                          completion: nil)
    }

    func saveToSupabase(userId: String, completion: @escaping (Bool) -> Void) {
        isSaving = true
        errorMessage = nil

        let level = selectedLevel ?? "Absolute beginner"
        let genres = Array(selectedGenres)
        
        Task {
            await finalizeOnboarding(
                userId: userId,
                level: level,
                genres: genres,
                mins: practiceMins
            )
            
            await MainActor.run {
                self.isSaving = false
                completion(true)
            }
        }
    }
}
