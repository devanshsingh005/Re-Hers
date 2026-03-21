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

    /// Base URL for constructing storage and function URLs.
    /// Not a secret — this is the project URL, not an API key.
    let supabaseBaseURL: String

    private init() {
        let urlString = "https://djqgmowfjxsnjdffdohw.supabase.co"
        let key       = "sb_publishable__FkMcK1683czdRktkt7YsA_vYR4ZsOW"

        supabaseBaseURL = urlString

        client = SupabaseClient(
            supabaseURL: URL(string: urlString)!,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }
}
