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
        .onAppear {
                    consumeDeepLink()
        }
        .onChange(of: deepLinkCanvasId) { _, _ in
            consumeDeepLink()
        }
    }

    private func consumeDeepLink() {
        if let newId = deepLinkCanvasId {
            currentCanvasID = newId
            deepLinkCanvasId = nil
        }
    }
}

#Preview {
    let auth = AuthService()
    ContentView(deepLinkCanvasId: .constant(nil), authService: auth)
}
