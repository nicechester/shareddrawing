import SwiftUI
import Firebase

@main
struct SharedDrawingApp: App {
    @State private var authService: AuthService
    @State private var isInitialized = false
    @State private var deepLinkCanvasId: String?

    init() {
        FirebaseApp.configure()
        _authService = State(initialValue: AuthService())
    }

    var body: some Scene {
        WindowGroup {
            if isInitialized {
                ContentView(deepLinkCanvasId: $deepLinkCanvasId, authService: authService)
                    .ignoresSafeArea()
                    .onOpenURL { url in
                        if let canvasId = url.queryItemValue(for: "id") {
                            deepLinkCanvasId = canvasId
                        }
                    }
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

extension URL {
    func queryItemValue(for name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}
