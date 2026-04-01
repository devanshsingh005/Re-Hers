//
//  SupabaseProgressManager.swift
//  Re-Hearse_v1
//
//  Central service for writing lesson progress to Supabase.
//  Uses SupabaseManager.shared.client — no raw URLSession or manual headers.
//  All calls are async Tasks (fire-and-forget) so the UI never blocks.
//
//  ── Run this SQL once in your Supabase SQL editor ────────────────────────
//
//  -- 1. Add new columns to profiles
//  ALTER TABLE public.profiles
//    ADD COLUMN IF NOT EXISTS current_chapter     smallint NOT NULL DEFAULT 1,
//    ADD COLUMN IF NOT EXISTS current_part        smallint NOT NULL DEFAULT 0,
//    ADD COLUMN IF NOT EXISTS last_active_at      timestamptz,
//    ADD COLUMN IF NOT EXISTS total_study_seconds bigint   NOT NULL DEFAULT 0;
//
//  -- 2. lesson_events table (one row per action)
//  CREATE TABLE IF NOT EXISTS public.lesson_events (
//    id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
//    user_id          uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
//    chapter_index    smallint    NOT NULL,
//    part_index       smallint    NOT NULL,        -- 0-based variant index; -1 = full lesson
//    event_type       text        NOT NULL,        -- 'part_completed' | 'lesson_completed'
//    stars            smallint,
//    attempts         smallint,
//    duration_seconds integer,
//    score_points     smallint,
//    occurred_at      timestamptz NOT NULL DEFAULT now()
//  );
//
//  -- 3. RPC for safe study-time increment
//  CREATE OR REPLACE FUNCTION increment_study_time(p_user_id uuid, p_delta integer)
//  RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
//    UPDATE public.profiles
//    SET total_study_seconds = total_study_seconds + p_delta
//    WHERE id = p_user_id;
//  $$;
//
//  ─────────────────────────────────────────────────────────────────────────

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

public struct ProfileProgressModel: Codable, Sendable {
    public let id: String
    public let current_chapter: Int
    public let current_part: Int
    public let last_active_at: String
    public let total_study_seconds: Int
}

public struct ProfileFetchResponse: Codable, Sendable {
    public let total_study_seconds: Int
}

private struct ExistingProfileProgress: Codable, Sendable {
    let current_chapter: Int?
    let current_part: Int?
    let total_study_seconds: Int?
}

// MARK: - Manager

final class SupabaseProgressManager: Sendable {
    
    private static var db: SupabaseClient { SupabaseManager.shared.client }
    
    // MARK: - Public API
    
    /// Call when the user taps "Done Practicing" on any variant/part.
    static func recordPartCompleted(
        chapterIndex: Int,
        partIndex:    Int,
        attempts:     Int,
        scorePoints:  Int
    ) async {
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
            let currentTotal = existingProgress?.total_study_seconds ?? 0
            let mergedChapter = max(currentChapter, chapterIndex)
            let mergedPart: Int
            if mergedChapter > chapterIndex {
                mergedPart = currentPart
            } else if mergedChapter > currentChapter {
                mergedPart = partIndex
            } else {
                mergedPart = max(currentPart, partIndex)
            }
            
            let profileUpdate = ProfileProgressModel(
                id: userID.uuidString,
                current_chapter: mergedChapter,
                current_part: mergedPart,
                last_active_at: iso8601Now(),
                total_study_seconds: currentTotal
            )
            
            try await db
                .from("profiles")
                .upsert(profileUpdate, onConflict: "id")
                .execute()
            
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
            let currentTotal = existingProgress?.total_study_seconds ?? 0
            let completedChapter = chapterIndex + 1
            let mergedChapter = max(currentChapter, completedChapter)
            let mergedPart = mergedChapter == completedChapter ? 0 : currentPart
            
            let profileUpdate = ProfileProgressModel(
                id: userID.uuidString,
                current_chapter: mergedChapter,
                current_part: mergedPart,
                last_active_at: iso8601Now(),
                total_study_seconds: currentTotal + durationSeconds
            )
            
            try await db
                .from("profiles")
                .upsert(profileUpdate, onConflict: "id")
                .execute()
            
            debugLog("[SupabaseProgressManager] Lesson saved — ch:\(chapterIndex) ⭐\(stars) \(durationSeconds)s")
            
        } catch {
            debugLog("[SupabaseProgressManager] recordLessonCompleted error: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private static func iso8601Now() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: Date())
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
