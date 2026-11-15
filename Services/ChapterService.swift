import Foundation
import Supabase
import Auth
internal import PostgREST

class ChapterService {
    static let shared = ChapterService()
    
    private let client = SupabaseManager.shared.client
    
    func fetchUserProgress() async throws -> (currentChapter: Int, stars: [Int: Int]) {
        guard let userURL = client.auth.currentUser?.id else {
            return (1, [:])
        }
        
        let profile: UserProfile = try await client
            .from("profiles")
            .select("*")
            .eq("id", value: userURL)
            .single()
            .execute()
            .value
            
        // Also fetch stars from lesson_events if tracked there
        // For now returning defaults
        return (profile.current_chapter ?? 1, [:])
    }
}
