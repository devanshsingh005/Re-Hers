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
        let url = URL(string: "https://YOUR-PROJECT-ID.supabase.co")!
        let key = "YOUR_ANON_OR_PUBLISHABLE_KEY"
        
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key
        )
    }
}

