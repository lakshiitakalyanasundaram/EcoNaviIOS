import SwiftUI
import MapKit
// Remove import MapKit if it's not needed here (it's fine to keep if used elsewhere)

@main
struct GreenPathApp: App {
    // Create the shared AuthManager and inject it into the environment
    @StateObject private var authManager = AuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)  // This makes auth available everywhere
        }
    }
}
