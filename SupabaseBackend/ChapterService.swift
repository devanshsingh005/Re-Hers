import Foundation
import Supabase
import Auth
internal import PostgREST

class ChapterService {
    static let shared = ChapterService()
    
    private let client = SupabaseManager.shared.client
    
    func fetchChapters() async throws -> [MusicChapter] {
        // In a real implementation, we'd fetch from 'learning_chapters' table
        // For now, we will use the existing allChapters as a fallback if the table doesn't exist
        // or during the transition period.
        
        /* 
        let rawChapters: [MusicChapter] = try await client
            .from("learning_chapters")
            .select("*")
            .order("chapterIndex", ascending: true)
            .execute()
            .value
        return rawChapters
        */
        
        // Returning the static ones for now but structured to be dynamic
        return allChapters 
    }
    
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
