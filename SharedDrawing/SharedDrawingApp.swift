import SwiftUI
import Firebase

@main
struct SharedDrawingApp: App {
    @State private var authService = AuthService()
    @State private var isInitializing = true

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            if isInitializing {
                ProgressView("Initializing...")
                    .task {
                        do {
                            try await authService.signInAnonymously()
                        } catch {
                            print("Failed to sign in: \(error.localizedDescription)")
                        }
                        isInitializing = false
                    }
            } else {
                ContentView()
                    .environment(authService)
            }
        }
    }
}
