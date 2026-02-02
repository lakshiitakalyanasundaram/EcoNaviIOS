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
    
    // MARK: - Session Persistence (UserDefaults – simple for testing)
    
    private let sessionStorageKey = "supabase.auth.persisted.session"
    
    private func saveSession(_ session: Session?) {
        guard let session else {
            UserDefaults.standard.removeObject(forKey: sessionStorageKey)
            print("Cleared saved session")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(session)
            UserDefaults.standard.set(data, forKey: sessionStorageKey)
            print("Session saved successfully")
        } catch {
            print("Failed to encode/save session: \(error)")
        }
    }
    
    private func loadSavedSession() -> Session? {
        guard let data = UserDefaults.standard.data(forKey: sessionStorageKey) else {
            print("No saved session found")
            return nil
        }
        
        do {
            let session = try JSONDecoder().decode(Session.self, from: data)
            
            // expiresAt is non-optional TimeInterval (Double) in your SDK version
            let expiresDate = Date(timeIntervalSince1970: session.expiresAt)
            let expiresStr = expiresDate.ISO8601Format()
            
            print("Loaded saved session (expiresAt: \(expiresStr))")
            return session
        } catch {
            print("Failed to decode saved session: \(error) – removing invalid data")
            UserDefaults.standard.removeObject(forKey: sessionStorageKey)
            return nil
        }
    }
    
    // MARK: - Initialization & Auth State Listener
    
    private var authStateTask: Task<Void, Never>?
    
    private init() {
        // Listen to auth state changes
        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await (event, newSession) in SupabaseManager.shared.client.auth.authStateChanges {
                print("Auth state changed: \(event) – session valid: \(newSession != nil ? "yes" : "no")")
                
                switch event {
                case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                    self.updateSession(newSession)
                    self.saveSession(newSession)
                    
                case .signedOut:
                    self.updateSession(nil)
                    self.saveSession(nil)
                    
                default:
                    break
                }
            }
        }
        
        // Attempt restore right away
        Task {
            await self.restoreSession()
        }
    }
    
    deinit {
        authStateTask?.cancel()
    }
    
    // MARK: - Restore Session on Launch
    
    func restoreSession() async {
        // Priority 1: Try to restore from saved Session using setSession()
        if let stored = loadSavedSession() {
            do {
                let restoredSession = try await SupabaseManager.shared.client.auth.setSession(
                    accessToken: stored.accessToken,
                    refreshToken: stored.refreshToken
                )
                
                // expiresAt is non-optional TimeInterval
                let restoredExpiresDate = Date(timeIntervalSince1970: restoredSession.expiresAt)
                let expiresStr = restoredExpiresDate.ISO8601Format()
                
                print("Session restored via setSession() – new expiresAt: \(expiresStr)")
                updateSession(restoredSession)
                saveSession(restoredSession)  // Save refreshed version
                return  // Success
            } catch {
                print("Restore via setSession failed: \(error.localizedDescription)")
                // Fall through (e.g., refresh token invalid/expired)
            }
        }
        
        // Priority 2: Fallback to client.session (usually nil after app kill)
        do {
            let current = try await SupabaseManager.shared.client.auth.session
            print("Fallback session from client: \(current != nil ? "exists" : "nil")")
            updateSession(current)
            saveSession(current)
        } catch {
            print("No fallback session: \(error.localizedDescription)")
            updateSession(nil)
        }
    }
    
    // MARK: - State Update
    
    private func updateSession(_ session: Session?) {
        self.session = session
        self.user = session?.user
        self.isLoggedIn = session != nil
        self.email = session?.user.email ?? ""
        self.displayName = name(from: session?.user.email ?? "")
        self.errorMessage = nil
    }
    
    // MARK: - Auth Actions
    
    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            let session = try await SupabaseManager.shared.client.auth.signIn(email: email, password: password)
            updateSession(session)
            saveSession(session)
        } catch {
            errorMessage = error.localizedDescription
            print("Sign in error: \(error)")
        }
    }
    
    func signUp(email: String, password: String) async {
        errorMessage = nil
        do {
            let response = try await SupabaseManager.shared.client.auth.signUp(email: email, password: password)
            if let session = response.session {
                updateSession(session)
                saveSession(session)
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Sign up error: \(error)")
        }
    }
    
    func signOut() async {
        do {
            try await SupabaseManager.shared.client.auth.signOut()
            updateSession(nil)
            saveSession(nil)
        } catch {
            errorMessage = error.localizedDescription
            print("Sign out error: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func name(from email: String) -> String {
        let base = email.split(separator: "@").first.map(String.init) ?? "User"
        return base.prefix(1).uppercased() + base.dropFirst()
    }
}

