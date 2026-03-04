//
//  SupabaseManager.swift
//  econavi
//
//  Created by Mayank Mishra on 23/01/26.
//


import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://nkcoimraewnwxhcmcomq.supabase.co")!,  
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5rY29pbXJhZXdud3hoY21jb21xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkwODI1OTcsImV4cCI6MjA4NDY1ODU5N30.PfTPf5179KGFcPVqVKKRnGE0Mev1JWe_YgX5lQgIvxM"
        )
    }
}
