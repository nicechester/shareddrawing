import SwiftUI

struct CanvasView: View {
    @State private var viewModel: CanvasViewModel
    @State private var currentStroke: Stroke?
    @State private var isDrawing = false
    @State private var lastUpdateTime: Date?
    @State private var showCanvasIDSheet = false

    @Binding var canvasId: String
    let repository: CanvasRepository
    let authService: AuthService

    private let throttleInterval: TimeInterval = 0.05  // ~50ms throttle for live updates

    init(canvasId: Binding<String>, repository: CanvasRepository, authService: AuthService) {
        self._canvasId = canvasId
        self.repository = repository
        self.authService = authService
        self._viewModel = State(initialValue: CanvasViewModel(
            canvasId: canvasId.wrappedValue,
            repository: repository,
            authService: authService
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Canvas ID header - placed safely below the status bar
            Button(action: {
                showCanvasIDSheet = true
            }) {
                HStack {
                    Text("Canvas ID: '\(canvasId)'")
                        .font(.system(size: 18))
                        .monospaced()
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Color(.systemGray6)
                        .ignoresSafeArea(edges: .top) // Fills status bar area above the button with gray
                )
                .contentShape(Rectangle())
            }
            .sheet(isPresented: $showCanvasIDSheet) {
                ChangeCanvasIDSheet(
                    canvasId: $canvasId,
                    isPresented: $showCanvasIDSheet
                )
            }
            // Color Palette
            ColorPalettePicker(selectedColor: $viewModel.currentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white)

            // Drawing Canvas
            ZStack {
                Canvas { context, _ in
                    for stroke in viewModel.strokes {
                        renderStroke(stroke, in: &context)
                    }

                    if let current = currentStroke {
                        renderStroke(current, in: &context)
                    }
                }
                .background(Color.white)

                StrokeCaptureView(
                    onPointsCapture: { points in
                        guard !points.isEmpty else { return }

                        if !isDrawing {
                            isDrawing = true
                            currentStroke = viewModel.startStroke(at: points.first ?? .zero)
                        }

                        if var stroke = currentStroke {
                            for point in points {
                                viewModel.addStrokePoint(point, to: &stroke)
                            }
                            currentStroke = stroke

                            let now = Date()
                            if lastUpdateTime == nil || now.timeIntervalSince(lastUpdateTime ?? now) >= throttleInterval {
                                lastUpdateTime = now
                                Task {
                                    do {
                                        try await viewModel.repository.updateStroke(stroke, in: canvasId)
                                    } catch {
                                        print("❌ Error updating stroke: \(error)")
                                    }
                                }
                            }
                        }
                    },
                    onStrokeEnded: {
                        guard let stroke = currentStroke else { return }
                        isDrawing = false
                        Task {
                            await viewModel.submitStroke(stroke)
                            currentStroke = nil
                        }
                    }
                )
            }
        }
        .padding(.vertical, 48)
        .onChange(of: canvasId) { _, newCanvasId in
            currentStroke = nil
            isDrawing = false
            viewModel.switchToCanvas(newCanvasId)
        }
    }
    
    private func renderStroke(_ stroke: Stroke, in context: inout GraphicsContext) {
        guard stroke.points.count > 1 else { return }

        var path = Path()
        let firstPoint = stroke.points[0]
        path.move(to: CGPoint(x: firstPoint.x, y: firstPoint.y))

        for point in stroke.points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x, y: point.y))
        }

        let color = Color(hex: stroke.color)
        context.stroke(
            path,
            with: .color(color),
            lineWidth: stroke.width
        )
    }
}

struct ChangeCanvasIDSheet: View {
    @Binding var canvasId: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Canvas ID")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Canvas ID")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("Canvas ID", text: $canvasId)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        canvasId = generateRandomID()
                    }) {
                        Text("Generate")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Open")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(canvasId.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Spacer()
            }
            .padding()
        }
    }

    private func generateRandomID() -> String {
        let characters = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return String((0..<5).map { _ in characters.randomElement()! })
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let rgb = Int(hex, radix: 16) ?? 0

        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
