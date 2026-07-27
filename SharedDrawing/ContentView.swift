import SwiftUI

struct ContentView: View {
    let authService: AuthService

    var body: some View {
        let repository = FirebaseCanvasRepository()
        CanvasView(
            canvasId: "test-canvas",
            repository: repository,
            authService: authService
        )
    }
}

#Preview {
    let mockAuth = AuthService()
    ContentView(authService: mockAuth)
}
