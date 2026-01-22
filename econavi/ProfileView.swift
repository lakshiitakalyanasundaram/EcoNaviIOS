import SwiftUI
import MapKit
import CoreLocation
import Combine
import PhotosUI

struct ProfileView: View {
    @Binding var isPresented: Bool
    
    @EnvironmentObject var authManager: AuthManager  // Real Supabase authentication
    
    @State private var showSignIn = false
    
    @State private var savedPlacesCount = 0
    @State private var currentPreference = "Driving"
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ProfileHeaderRow(
                        name: authManager.isLoggedIn ? authManager.displayName : "Not signed in",
                        email: authManager.isLoggedIn ? authManager.email : "Sign in to sync places, reports, and preferences",
                        initials: initials(from: authManager.isLoggedIn ? authManager.displayName : "Guest")
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                Section {
                    NavigationLink(destination: PlacesView(savedPlacesCount: $savedPlacesCount)) {
                        ProfileRow(icon: "square.stack.fill", iconColor: .purple, title: "Places") {
                            Text("\(savedPlacesCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    NavigationLink(destination: ReportsView()) {
                        ProfileRow(icon: "exclamationmark.bubble.fill", iconColor: .red, title: "Reports")
                    }
                    
                    NavigationLink(destination: OfflineMapsView()) {
                        ProfileRow(icon: "arrow.down.circle.fill", iconColor: .gray, title: "Offline Maps") {
                            Text("Download")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    NavigationLink(destination: PreferencesView(currentPreference: $currentPreference)) {
                        ProfileRow(icon: "slider.horizontal.3", iconColor: .gray, title: "Preferences") {
                            Text(currentPreference)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    if authManager.isLoggedIn {
                        Button(role: .destructive) {
                            Task {
                                await authManager.signOut()
                            }
                        } label: {
                            Text("Sign Out")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } else {
                        Button {
                            showSignIn = true
                        } label: {
                            Text("Sign In")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .fullScreenCover(isPresented: $showSignIn) {
                SignInView(isPresented: $showSignIn)
            }
        }
    }
    
    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").compactMap { $0.first }.map(String.init)
        if parts.isEmpty { return "G" }
        return parts.prefix(2).joined().uppercased()
    }
}

// MARK: - Profile Building Blocks

private struct ProfileHeaderRow: View {
    let name: String
    let email: String
    let initials: String
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 86, height: 86)
                
                Text(initials)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 18)
            
            Text(name)
                .font(.title2.bold())
            
            Text(email)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    
    init(icon: String, iconColor: Color, title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.trailing = trailing
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28)
            
            Text(title)
                .foregroundStyle(.primary)
            
            Spacer()
            
            trailing()
        }
    }
}

// MARK: - Sub Views (Remove 'private' so they are visible to NavigationLink)

struct PlacesView: View {
    @Binding var savedPlacesCount: Int
    
    var body: some View {
        List {
            Section {
                Text("Saved places will appear here.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct ReportsView: View {
    // Paste your full ReportsView + report flow here
    var body: some View {
        Text("Reports View Placeholder")
            .navigationTitle("Reports")
    }
}

struct OfflineMapsView: View {
    // Paste your full OfflineMapsView + related classes/views here
    var body: some View {
        Text("Offline Maps View Placeholder")
            .navigationTitle("Offline Maps")
    }
}

struct PreferencesView: View {
    @Binding var currentPreference: String
    
    // Paste your full PreferencesView here
    var body: some View {
        Text("Preferences View Placeholder")
            .navigationTitle("Preferences")
    }
}

// Add any other destination views here without 'private':
// struct OfflineMapDetailView: View { ... }
// struct OfflineMapsSettingsView: View { ... }
// struct DownloadNewMapView: View { ... }
// struct ReportFlowRootView: View { ... }
// etc.

// MARK: - Auth Flow

private struct SignInView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authManager: AuthManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $password)
                }
                
                if let error = authManager.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button(isLoading ? "Please wait..." : (isSignUpMode ? "Create Account" : "Sign In")) {
                        Task {
                            isLoading = true
                            authManager.errorMessage = nil
                            
                            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            if isSignUpMode {
                                await authManager.signUp(email: trimmedEmail, password: password)
                            } else {
                                await authManager.signIn(email: trimmedEmail, password: password)
                            }
                            
                            isLoading = false
                            
                            if authManager.isLoggedIn {
                                isPresented = false
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(isLoading || email.isEmpty || password.count < 6)
                }
                
                Section {
                    Button(isSignUpMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                        isSignUpMode.toggle()
                        authManager.errorMessage = nil
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle(isSignUpMode ? "Sign Up" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView(isPresented: .constant(true))
        .environmentObject(AuthManager.shared)
}
