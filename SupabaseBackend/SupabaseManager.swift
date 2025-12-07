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
    
    private init() {
        let url = URL(string: "https://djqgmowfjxsnjdffdohw.supabase.co")!
        let key = "sb_publishable__FkMcK1683czdRktkt7YsA_vYR4ZsOW"
        
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key
        )
    }
}

