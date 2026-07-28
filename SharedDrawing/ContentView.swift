import SwiftUI

struct ContentView: View {
    @State private var currentCanvasID: String = UUID().uuidString.prefix(5).lowercased()
    @Binding var deepLinkCanvasId: String?

    let authService: AuthService

    var body: some View {
        CanvasView(
            canvasId: $currentCanvasID,
            repository: FirebaseCanvasRepository(),
            authService: authService
        )
        .onChange(of: deepLinkCanvasId) { _, newId in
            if let newId = newId {
                currentCanvasID = newId
                deepLinkCanvasId = nil
            }
        }
    }

    private func generateRandomID() -> String {
        let characters = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return String((0..<5).map { _ in characters.randomElement()! })
    }
}

#Preview {
    let auth = AuthService()
    ContentView(authService: auth, deepLinkCanvasId: .constant(nil))
}

#Preview {
    let auth = AuthService()
    ContentView(authService: auth)
}
