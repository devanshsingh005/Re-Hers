import Foundation
import Supabase
import UIKit
import Combine   // ← REQUIRED FIX

class OnboardingViewModel: ObservableObject {
    @Published var selectedGenre: String?
    @Published var selectedArtist: String?
    @Published var selectedLevel: String?

    @Published var isSaving = false
    @Published var errorMessage: String?

    func saveToSupabase(userId: String, completion: @escaping (Bool) -> Void) {
        guard let genre = selectedGenre,
              let artist = selectedArtist,
              let level = selectedLevel else {
            completion(false)
            return
        }

        isSaving = true
        errorMessage = nil // Reset error state

        let client = SupabaseManager.shared.client
        let randomIcon = "icon_\(Int.random(in: 1...9))"

        Task {
            do {
                print("Starting onboarding save for user: \(userId)")
                // 1. Save onboarding answers
                try await client
                    .from("user_onboarding")
                    .upsert([
                        "id": userId,
                        "genre": genre,
                        "artist": artist,
                        "level": level
                    ])
                    .execute()

                print("Onboarding table updated.")

                // 2. Also update profiles table so NavBar and Profile screen see the new icon
                try await client
                    .from("profiles")
                    .upsert([
                        "id": userId,
                        "avatar_url": randomIcon
                    ])
                    .execute()

                print("Profiles table updated with icon: \(randomIcon)")

                DispatchQueue.main.async {
                    self.isSaving = false
                    completion(true)
                }

            } catch {
                print("Onboarding save failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to save: \(error.localizedDescription)"
                    self.isSaving = false
                    completion(false)
                }
            }
        }
    }
}
