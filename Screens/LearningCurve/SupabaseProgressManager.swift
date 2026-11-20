//
//  SupabaseProgressManager.swift
//  Re-Hearse_v1
//
//  Central service for writing lesson progress to Supabase.
//  Uses SupabaseManager.shared.client — no raw URLSession or manual headers.
//  All calls are async Tasks (fire-and-forget) so the UI never blocks.
//
//  Schema: supabase/migrations. Study time is added atomically by add_my_study_time().

// @preconcurrency suppresses the main-actor isolation leak that UIKit projects
// inject onto file-scope types when the app entry point is @MainActor.
@preconcurrency import Foundation
@preconcurrency import Supabase

// MARK: - Payload structs
// Declared at file scope with explicit nonisolated(unsafe) so the compiler
// never tries to attach main-actor isolation to them, regardless of project
// wide concurrency settings.

private struct LessonEventInsert: Encodable, Sendable {
    let user_id:          UUID
    let chapter_index:    Int
    let part_index:       Int
    let event_type:       String
    let stars:            Int?
    let attempts:         Int?
    let duration_seconds: Int?
    let score_points:     Int
}

private struct ProfileProgressUpdate: Encodable, Sendable {
    let current_chapter: Int
    let current_part: Int
    let last_active_at: String
}

private struct ExistingProfileProgress: Codable, Sendable {
    let current_chapter: Int?
    let current_part: Int?
    let total_study_seconds: Int?
}

enum PracticeSessionKind: String, Sendable {
    case practicePage = "practice_page_session"
    case playAlong = "play_along_session"
    case animation = "animation_session"
}

struct GuestLessonEvent: Codable, Sendable {
    let chapterIndex: Int
    let partIndex: Int
    let eventType: String
    let stars: Int?
    let attempts: Int?
    let durationSeconds: Int?
    let scorePoints: Int
    let occurredAt: String
}

struct GuestProgressSnapshot: Codable, Sendable {
    let currentChapter: Int
    let currentPart: Int
    let totalStudySeconds: Int
}

// MARK: - Manager

final class SupabaseProgressManager: Sendable {
    
    private static var db: SupabaseClient { SupabaseManager.shared.client }
    private static let guestLessonEventsKey = "guestLessonEvents"
    private static let guestProgressSnapshotKey = "guestProgressSnapshot"
    private static let minimumTrackedPracticeDurationSeconds = 5
    
    // MARK: - Public API
    
    /// Call when the user taps "Done Practicing" on any variant/part.
    static func recordPartCompleted(
        chapterIndex: Int,
        partIndex:    Int,
        attempts:     Int,
        scorePoints:  Int
    ) async {
        if GuestSessionManager.shared.isGuest() {
            saveGuestPartCompleted(
                chapterIndex: chapterIndex,
                partIndex: partIndex,
                attempts: attempts,
                scorePoints: scorePoints
            )
            return
        }

        guard let userID = await currentUserID() else {
            debugLog("[SupabaseProgressManager] recordPartCompleted: no logged-in user")
            return
        }
        
        do {
            let event = LessonEventInsert(
                user_id: userID,
                chapter_index: chapterIndex,
                part_index: partIndex,
                event_type: "part_completed",
                stars: nil,
                attempts: attempts,
                duration_seconds: nil,
                score_points: scorePoints
            )
            
            try await db
                .from("lesson_events")
                .insert(event)
                .execute()
            
            let existingProgress = try await fetchExistingProgress(for: userID)
            let currentChapter = existingProgress?.current_chapter ?? 1
            let currentPart = existingProgress?.current_part ?? 0
            let mergedChapter = max(currentChapter, chapterIndex)
            let mergedPart: Int
            if mergedChapter > chapterIndex {
                mergedPart = currentPart
            } else if mergedChapter > currentChapter {
                mergedPart = partIndex
            } else {
                mergedPart = max(currentPart, partIndex)
            }
            
            try await updateProgress(userID: userID, chapter: mergedChapter, part: mergedPart)
            
            debugLog("[SupabaseProgressManager] Part saved — ch:\(chapterIndex) part:\(partIndex)")
        } catch {
            debugLog("[SupabaseProgressManager] recordPartCompleted error: \(error)")
        }
    }
    
    /// Call once when 100% of variants are done and the completion popup appears.
    static func recordLessonCompleted(
        chapterIndex:    Int,
        stars:           Int,
        durationSeconds: Int,
        scorePoints:     Int
    ) async {
        if GuestSessionManager.shared.isGuest() {
            saveGuestLessonCompleted(
                chapterIndex: chapterIndex,
                stars: stars,
                durationSeconds: durationSeconds,
                scorePoints: scorePoints
            )
            return
        }

        guard let userID = await currentUserID() else {
            debugLog("[SupabaseProgressManager] recordLessonCompleted: no logged-in user")
            return
        }
        
        do {
            let event = LessonEventInsert(
                user_id: userID,
                chapter_index: chapterIndex,
                part_index: -1,
                event_type: "lesson_completed",
                stars: stars,
                attempts: nil,
                duration_seconds: durationSeconds,
                score_points: scorePoints
            )
            
            try await db
                .from("lesson_events")
                .insert(event)
                .execute()
            
            let existingProgress = try await fetchExistingProgress(for: userID)
            let currentChapter = existingProgress?.current_chapter ?? 1
            let currentPart = existingProgress?.current_part ?? 0
            let completedChapter = chapterIndex + 1
            let mergedChapter = max(currentChapter, completedChapter)
            let mergedPart = mergedChapter == completedChapter ? 0 : currentPart
            
            try await updateProgress(userID: userID, chapter: mergedChapter, part: mergedPart)
            try await addStudyTime(seconds: durationSeconds)
            
            debugLog("[SupabaseProgressManager] Lesson saved — ch:\(chapterIndex) ⭐\(stars) \(durationSeconds)s")
            
        } catch {
            debugLog("[SupabaseProgressManager] recordLessonCompleted error: \(error)")
        }
    }

    static func beginTrackedPracticeSessionIfNeeded(_ startDate: inout Date?) {
        guard startDate == nil else { return }
        startDate = Date()
    }

    static func endTrackedPracticeSession(
        _ startDate: inout Date?,
        kind: PracticeSessionKind
    ) {
        guard let sessionStart = startDate else { return }
        startDate = nil

        let durationSeconds = max(Int(Date().timeIntervalSince(sessionStart)), 0)
        guard durationSeconds >= minimumTrackedPracticeDurationSeconds else { return }

        Task {
            await recordPracticeSession(kind: kind, durationSeconds: durationSeconds)
        }
    }

    static func recordPracticeSession(
        kind: PracticeSessionKind,
        durationSeconds: Int
    ) async {
        guard durationSeconds >= minimumTrackedPracticeDurationSeconds else { return }

        await MainActor.run {
            DailyGoalManager.shared.addPracticeDuration(seconds: durationSeconds)
        }

        if GuestSessionManager.shared.isGuest() {
            saveGuestPracticeSession(kind: kind, durationSeconds: durationSeconds)
            return
        }

        guard let userID = await currentUserID() else {
            debugLog("[SupabaseProgressManager] recordPracticeSession: no logged-in user")
            return
        }

        do {
            let event = LessonEventInsert(
                user_id: userID,
                chapter_index: -1,
                part_index: -1,
                event_type: kind.rawValue,
                stars: nil,
                attempts: nil,
                duration_seconds: durationSeconds,
                score_points: 0
            )

            try await db
                .from("lesson_events")
                .insert(event)
                .execute()

            try await addStudyTime(seconds: durationSeconds)

            debugLog("[SupabaseProgressManager] Practice session saved — \(kind.rawValue) \(durationSeconds)s")
        } catch {
            debugLog("[SupabaseProgressManager] recordPracticeSession error: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private static func iso8601Now() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: Date())
    }

    /// Writes only chapter/part, so it never overwrites study time written from another device.
    private static func updateProgress(userID: UUID, chapter: Int, part: Int) async throws {
        try await db
            .from("profiles")
            .update(ProfileProgressUpdate(current_chapter: chapter, current_part: part, last_active_at: iso8601Now()))
            .eq("id", value: userID.uuidString)
            .execute()
    }

    /// Atomic increment on the server (also stamps last_active_at). Capped at 6 hours per call, like the function.
    private static func addStudyTime(seconds: Int) async throws {
        let clamped = min(max(seconds, 0), 21_600)
        guard clamped > 0 else { return }
        try await db
            .rpc("add_my_study_time", params: ["p_seconds": clamped])
            .execute()
    }

    private static func fetchExistingProgress(for userID: UUID) async throws -> ExistingProfileProgress? {
        let response: [ExistingProfileProgress] = try await db
            .from("profiles")
            .select("current_chapter, current_part, total_study_seconds")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value
        return response.first
    }

    static func guestProgressSnapshot() -> GuestProgressSnapshot {
        if let data = UserDefaults.standard.data(forKey: guestProgressSnapshotKey),
           let snapshot = try? JSONDecoder().decode(GuestProgressSnapshot.self, from: data) {
            return snapshot
        }

        return GuestProgressSnapshot(currentChapter: 1, currentPart: 0, totalStudySeconds: 0)
    }

    static func guestLessonEvents() -> [GuestLessonEvent] {
        guard let data = UserDefaults.standard.data(forKey: guestLessonEventsKey),
              let events = try? JSONDecoder().decode([GuestLessonEvent].self, from: data) else {
            return []
        }

        return events
    }

    static func guestCompletedPartIndexes(for chapterIndex: Int) -> Set<Int> {
        Set(
            guestLessonEvents()
                .filter { $0.chapterIndex == chapterIndex && $0.eventType == "part_completed" && $0.partIndex >= 0 }
                .map(\.partIndex)
        )
    }

    /// Parts of a chapter already practised, for guests and signed-in users.
    static func completedPartIndexes(for chapterIndex: Int) async -> Set<Int> {
        if GuestSessionManager.shared.isGuest() { return guestCompletedPartIndexes(for: chapterIndex) }
        struct Row: Decodable { let part_index: Int }
        guard let userID = await currentUserID() else { return [] }
        let rows: [Row] = (try? await db.from("lesson_events")
            .select("part_index")
            .eq("user_id", value: userID.uuidString)
            .eq("chapter_index", value: chapterIndex)
            .eq("event_type", value: "part_completed")
            .execute().value) ?? []
        return Set(rows.map(\.part_index).filter { $0 >= 0 })
    }

    /// Best stars per completed chapter for a signed-in user.
    static func chapterStars() async -> [Int: Int] {
        if GuestSessionManager.shared.isGuest() { return guestChapterStars() }
        struct Row: Decodable { let chapter_index: Int; let stars: Int? }
        guard let userID = await currentUserID() else { return [:] }
        let rows: [Row] = (try? await db.from("lesson_events")
            .select("chapter_index, stars")
            .eq("user_id", value: userID.uuidString)
            .eq("event_type", value: "lesson_completed")
            .execute().value) ?? []
        var stars: [Int: Int] = [:]
        for row in rows { stars[row.chapter_index] = max(stars[row.chapter_index] ?? 0, row.stars ?? 1) }
        return stars
    }

    static func guestChapterStars() -> [Int: Int] {
        var starsMap: [Int: Int] = [:]
        for event in guestLessonEvents() where event.eventType == "lesson_completed" {
            let stars = event.stars ?? 1
            starsMap[event.chapterIndex] = max(starsMap[event.chapterIndex] ?? 0, stars)
        }
        return starsMap
    }

    static func clearGuestProgressData() {
        UserDefaults.standard.removeObject(forKey: guestLessonEventsKey)
        UserDefaults.standard.removeObject(forKey: guestProgressSnapshotKey)
    }

    private static func saveGuestPartCompleted(
        chapterIndex: Int,
        partIndex: Int,
        attempts: Int,
        scorePoints: Int
    ) {
        let event = GuestLessonEvent(
            chapterIndex: chapterIndex,
            partIndex: partIndex,
            eventType: "part_completed",
            stars: nil,
            attempts: attempts,
            durationSeconds: nil,
            scorePoints: scorePoints,
            occurredAt: iso8601Now()
        )
        appendGuestLessonEvent(event)

        let existingSnapshot = guestProgressSnapshot()
        let mergedChapter = max(existingSnapshot.currentChapter, chapterIndex)
        let mergedPart: Int

        if mergedChapter > chapterIndex {
            mergedPart = existingSnapshot.currentPart
        } else if mergedChapter > existingSnapshot.currentChapter {
            mergedPart = partIndex
        } else {
            mergedPart = max(existingSnapshot.currentPart, partIndex)
        }

        saveGuestProgressSnapshot(
            GuestProgressSnapshot(
                currentChapter: mergedChapter,
                currentPart: mergedPart,
                totalStudySeconds: existingSnapshot.totalStudySeconds
            )
        )
    }

    private static func saveGuestLessonCompleted(
        chapterIndex: Int,
        stars: Int,
        durationSeconds: Int,
        scorePoints: Int
    ) {
        let event = GuestLessonEvent(
            chapterIndex: chapterIndex,
            partIndex: -1,
            eventType: "lesson_completed",
            stars: stars,
            attempts: nil,
            durationSeconds: durationSeconds,
            scorePoints: scorePoints,
            occurredAt: iso8601Now()
        )
        appendGuestLessonEvent(event)

        let existingSnapshot = guestProgressSnapshot()
        let completedChapter = chapterIndex + 1
        let mergedChapter = max(existingSnapshot.currentChapter, completedChapter)
        let mergedPart = mergedChapter == completedChapter ? 0 : existingSnapshot.currentPart

        saveGuestProgressSnapshot(
            GuestProgressSnapshot(
                currentChapter: mergedChapter,
                currentPart: mergedPart,
                totalStudySeconds: existingSnapshot.totalStudySeconds + durationSeconds
            )
        )
    }

    private static func saveGuestPracticeSession(
        kind: PracticeSessionKind,
        durationSeconds: Int
    ) {
        let event = GuestLessonEvent(
            chapterIndex: -1,
            partIndex: -1,
            eventType: kind.rawValue,
            stars: nil,
            attempts: nil,
            durationSeconds: durationSeconds,
            scorePoints: 0,
            occurredAt: iso8601Now()
        )
        appendGuestLessonEvent(event)

        let existingSnapshot = guestProgressSnapshot()
        saveGuestProgressSnapshot(
            GuestProgressSnapshot(
                currentChapter: existingSnapshot.currentChapter,
                currentPart: existingSnapshot.currentPart,
                totalStudySeconds: existingSnapshot.totalStudySeconds + durationSeconds
            )
        )
    }

    private static func appendGuestLessonEvent(_ event: GuestLessonEvent) {
        var events = guestLessonEvents()
        events.append(event)
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: guestLessonEventsKey)
        }
    }

    private static func saveGuestProgressSnapshot(_ snapshot: GuestProgressSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: guestProgressSnapshotKey)
        }
    }
    
    // MARK: - Auth helper
    
    private static func currentUserID() async -> UUID? {
        do {
            return try await db.auth.session.user.id
        } catch {
            debugLog("[SupabaseProgressManager] Auth session error: \(error)")
            return nil
        }
    }
}
