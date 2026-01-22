import Foundation
import Supabase
import SwiftUI
import Combine

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var user: User? = nil
    @Published var session: Session? = nil
    @Published var isLoggedIn: Bool = false
    @Published var displayName: String = "Guest"
    @Published var email: String = ""
    @Published var errorMessage: String?
    

    
    private func updateSession(_ session: Session?) {
        self.session = session
        self.user = session?.user
        self.isLoggedIn = session != nil
        self.email = session?.user.email ?? ""
        self.displayName = self.name(from: session?.user.email ?? "")
        self.errorMessage = nil  // Clear any errors on successful state change
    }
    
    private func loadCurrentSession() async {
        do {
            let currentSession = try await SupabaseManager.shared.client.auth.session
            updateSession(currentSession)
        } catch {
            updateSession(nil)
        }
    }
    
    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            let session = try await SupabaseManager.shared.client.auth.signIn(email: email, password: password)
            // Manually update state in case listener is slow
            updateSession(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func signUp(email: String, password: String) async {
        errorMessage = nil
        do {
            let session = try await SupabaseManager.shared.client.auth.signUp(email: email, password: password)
            // If email confirmations are OFF, user is auto-logged in
            if let session = session.session {
                updateSession(session)
            }
            // If confirmations are ON, user gets email — they'll need to confirm before login works
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func signOut() async {
        do {
            try await SupabaseManager.shared.client.auth.signOut()
            updateSession(nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func name(from email: String) -> String {
        let base = email.split(separator: "@").first.map(String.init) ?? "User"
        return base.prefix(1).uppercased() + base.dropFirst()
    }
}
