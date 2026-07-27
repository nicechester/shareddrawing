import SwiftUI

struct ContentView: View {
    let authService: AuthService

    var body: some View {
        CanvasIDView()
    }
}

#Preview {
    let mockAuth = AuthService()
    ContentView(authService: mockAuth)
}
