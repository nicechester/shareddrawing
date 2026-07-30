import SwiftUI
import os.log

private let logger = Logger(subsystem: "io.github.nicechester.shareddrawing", category: "App")
import Firebase
import GoogleSignIn

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
            Group {
                if isInitialized {
                    ContentView(deepLinkCanvasId: $deepLinkCanvasId, authService: authService)
                        .ignoresSafeArea()
                } else {
                    ProgressView("Initializing...")
                        .task {
                            try? await authService.signInAnonymously()
                            isInitialized = true
                        }
                }
            }
            .onOpenURL { url in
                logger.debug("Received URL: \(url.absoluteString)")
                if GIDSignIn.sharedInstance.handle(url) {
                    return
                }
                if let canvasId = url.queryItemValue(for: "id") {
                    logger.info("Parsed Canvas ID: \(canvasId)")
                    deepLinkCanvasId = canvasId
                } else {
                    logger.warning("Could not parse 'id' parameter from: \(url)")
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
