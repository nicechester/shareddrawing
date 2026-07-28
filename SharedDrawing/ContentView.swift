import SwiftUI

struct ContentView: View {
    let authService: AuthService

    var body: some View {
        if let userId = authService.currentUserID {
            MyCanvasesView(
                userId: userId,
                repository: FirebaseCanvasRepository(),
                authService: authService
            )
        } else {
            ProgressView("Signing in...")
        }
    }
}

#Preview {
    let auth = AuthService()
    ContentView(authService: auth)
}
