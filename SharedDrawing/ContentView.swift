import SwiftUI

struct ContentView: View {
    @State private var currentCanvasID: String = UUID().uuidString.prefix(5).lowercased()

    let authService: AuthService

    var body: some View {
        CanvasView(
            canvasId: $currentCanvasID,
            repository: FirebaseCanvasRepository(),
            authService: authService
        )
    }

    private func generateRandomID() -> String {
        let characters = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return String((0..<5).map { _ in characters.randomElement()! })
    }
}

#Preview {
    let auth = AuthService()
    ContentView(authService: auth)
}
