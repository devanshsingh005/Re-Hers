//
//  SupabaseManager.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/12/25.
//

import Foundation
import Supabase

public struct UserProfile: Codable {
    public let id: UUID
    public var avatar_url: String?
    public var full_name: String?
    public var username: String?
    public var bio: String?
    public var total_study_seconds: Int?
    public var daily_goal_minutes: Int?
    public var practice_mins_today: Int?
    public var last_practice_date: String?
    public var current_chapter: Int?

    public init(id: UUID, avatar_url: String? = nil, full_name: String? = nil, username: String? = nil, bio: String? = nil, total_study_seconds: Int? = nil, daily_goal_minutes: Int? = nil, practice_mins_today: Int? = nil, last_practice_date: String? = nil, current_chapter: Int? = nil) {
        self.id = id
        self.avatar_url = avatar_url
        self.full_name = full_name
        self.username = username
        self.bio = bio
        self.total_study_seconds = total_study_seconds
        self.daily_goal_minutes = daily_goal_minutes
        self.practice_mins_today = practice_mins_today
        self.last_practice_date = last_practice_date
        self.current_chapter = current_chapter
    }
}

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient
    private let supabaseKey: String
    private let resolvedSupabaseURL: URL

    var supabaseURL: String {
        Self.resolveSupabaseURL()
    }

    private init() {
        let rawKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_KEY") as? String ?? ""
        let key = rawKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        guard let resolvedSupabaseURL = URL(string: Self.resolveSupabaseURL()) else {
            fatalError("SUPABASE_URL is not a valid URL — check build configuration")
        }

        self.supabaseKey = key
        self.resolvedSupabaseURL = resolvedSupabaseURL
        client = SupabaseClient(
            supabaseURL: resolvedSupabaseURL,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }

    func makeEphemeralClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: resolvedSupabaseURL,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: InMemoryAuthLocalStorage(),
                    autoRefreshToken: false,
                    emitLocalSessionAsInitialSession: false
                )
            )
        )
    }

    func accessToken(forceRefresh: Bool = false) async throws -> String {
        if forceRefresh {
            return try await client.auth.refreshSession().accessToken
        }
        return try await client.auth.session.accessToken
    }

    func currentUserId() async throws -> String {
        try await client.auth.session.user.id.uuidString
    }

    func startAutoRefresh() {
        client.auth.startAutoRefresh()
    }

    func stopAutoRefresh() {
        client.auth.stopAutoRefresh()
    }

    private static func resolveSupabaseURL() -> String {
        let rawURLString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        return rawURLString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}

private final class InMemoryAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private var store: [String: Data] = [:]
    private let lock = NSLock()

    func store(key: String, value: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        store[key] = value
    }

    func retrieve(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return store[key]
    }

    func remove(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        store.removeValue(forKey: key)
    }
}
