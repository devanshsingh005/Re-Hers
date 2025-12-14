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

        let client = SupabaseManager.shared.client

        Task {
            do {
                // NEW SDK SYNTAX — FIXED
                try await client
                    .from("user_onboarding")
                    .insert([
                        "id": userId,
                        "genre": genre,
                        "artist": artist,
                        "level": level
                    ])
                    .execute()

                DispatchQueue.main.async {
                    self.isSaving = false
                    completion(true)
                }

            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isSaving = false
                    completion(false)
                }
            }
        }
    }
}
