import SwiftUI

@Observable
class MyCanvasesViewModel {
    var canvases: [CanvasMetadata] = []
    var isLoading = false
    private var listener: ListenerRegistration?

    func loadCanvases(userId: String) {
        isLoading = true
        listener = FirestoreService.shared.listenToCanvases(userId: userId) { [weak self] canvases in
            self?.canvases = canvases
            self?.isLoading = false
        }
    }

    deinit {
        listener?.remove()
    }
}

struct MyCanvasesView: View {
    @State private var viewModel = MyCanvasesViewModel()
    @State private var selectedCanvasId: String?
    let userId: String
    let repository: CanvasRepository
    let authService: AuthService

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.canvases.isEmpty {
                    VStack(spacing: 16) {
                        Text("No canvases yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Create or join a canvas to get started")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    List {
                        ForEach(viewModel.canvases, id: \.id) { canvas in
                            NavigationLink(value: canvas.canvasId) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(canvas.name)
                                        .font(.headline)
                                    HStack(spacing: 12) {
                                        Text("ID: \(canvas.canvasId)")
                                            .font(.caption)
                                            .monospaced()
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Text(formatDate(canvas.lastActivityDate))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("My Canvases")
            .navigationDestination(isPresented: .constant(selectedCanvasId != nil)) {
                if let canvasId = selectedCanvasId {
                    CanvasView(
                        canvasId: canvasId,
                        repository: repository,
                        authService: authService
                    )
                    .navigationBarBackButtonHidden()
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: CanvasIDView()) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadCanvases(userId: userId)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    MyCanvasesView(
        userId: "test-user",
        repository: FakeCanvasRepository(),
        authService: AuthService()
    )
}
