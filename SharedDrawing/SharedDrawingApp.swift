import SwiftUI
import Firebase

@main
struct SharedDrawingApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
