//
//  SupabaseManager.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/12/25.
//

import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

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

        client = SupabaseClient(
            supabaseURL: resolvedSupabaseURL,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
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
