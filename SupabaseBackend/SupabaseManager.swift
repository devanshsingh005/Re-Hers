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
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let urlString = config["SupabaseURL"] as? String,
              let key = config["SupabaseKey"] as? String,
              let url = URL(string: urlString) else {
            fatalError("Config.plist missing or invalid. Copy Re-Hearse_v1/Config.plist.example to Re-Hearse_v1/Config.plist and fill in your Supabase credentials.")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key
        )
    }
}

