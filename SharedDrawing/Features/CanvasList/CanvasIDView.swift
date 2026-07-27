import SwiftUI

struct CanvasIDView: View {
    @State private var enteredID = ""
    @State private var selectedCanvasID: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("SharedDrawing")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Canvas ID")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    TextField("Enter canvas ID", text: $enteredID)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                HStack(spacing: 12) {
                    Button(action: { selectedCanvasID = generateRandomID() }) {
                        Text("Create")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: { selectedCanvasID = enteredID.trimmingCharacters(in: .whitespaces) }) {
                        Text("Join")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(enteredID.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Spacer()
            }
            .padding()
            .navigationDestination(isPresented: .constant(selectedCanvasID != nil)) {
                if let canvasID = selectedCanvasID {
                    CanvasView(
                        canvasId: canvasID,
                        repository: FirebaseCanvasRepository(),
                        authService: AuthService()
                    )
                    .navigationBarBackButtonHidden()
                }
            }
        }
    }

    private func generateRandomID() -> String {
        let characters = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return String((0..<5).map { _ in characters.randomElement()! })
    }
}

#Preview {
    CanvasIDView()
}
