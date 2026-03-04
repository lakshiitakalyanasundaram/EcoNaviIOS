import SwiftUI
import MapKit
// Remove import MapKit if it's not needed here (it's fine to keep if used elsewhere)

@main
struct GreenPathApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var userDataManager = UserDataManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(userDataManager)
                .task {
                    if authManager.isLoggedIn {
                        await userDataManager.refreshAll()
                    }
                }
        }
    }
}
