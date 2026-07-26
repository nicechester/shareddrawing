import SwiftUI
import Firebase

@main
struct SharedDrawingApp: App {
    @State private var authService: AuthService
    @State private var isInitialized = false

    init() {
        FirebaseApp.configure()
        _authService = State(initialValue: AuthService())
    }

    var body: some Scene {
        WindowGroup {
            if isInitialized {
                ContentView().environment(authService)
            } else {
                ProgressView("Initializing...")
                    .task {
                        try? await authService.signInAnonymously()
                        isInitialized = true
                    }
            }
        }
    }
}
