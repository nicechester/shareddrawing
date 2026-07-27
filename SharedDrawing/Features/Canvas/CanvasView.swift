import SwiftUI

struct CanvasView: View {
    @State private var viewModel: CanvasViewModel
    @State private var currentStroke: Stroke?
    @State private var isDrawing = false
    @State private var lastUpdateTime: Date?

    let canvasId: String
    let repository: CanvasRepository
    let authService: AuthService

    private let throttleInterval: TimeInterval = 0.05  // ~50ms throttle for live updates

    init(canvasId: String, repository: CanvasRepository, authService: AuthService) {
        self.canvasId = canvasId
        self.repository = repository
        self.authService = authService
        self._viewModel = State(initialValue: CanvasViewModel(
            canvasId: canvasId,
            repository: repository,
            authService: authService
        ))
    }

    var body: some View {
        ZStack {
            Canvas { context, _ in
                // Render all completed strokes
                for stroke in viewModel.strokes {
                    renderStroke(stroke, in: &context)
                }

                // Render current in-progress stroke
                if let current = currentStroke {
                    renderStroke(current, in: &context)
                }
            }
            .background(Color.white)

            // Overlay touch capture
            StrokeCaptureView(
                onPointsCapture: { points in
                    guard !points.isEmpty else { return }

                    if !isDrawing {
                        // Start new stroke with first point
                        isDrawing = true
                        currentStroke = viewModel.startStroke(at: points.first ?? .zero)
                    }

                    // Add captured points to current stroke
                    if var stroke = currentStroke {
                        for point in points {
                            viewModel.addStrokePoint(point, to: &stroke)
                        }
                        currentStroke = stroke

                        // Throttled live update to Firebase (~50ms)
                        let now = Date()
                        if lastUpdateTime == nil || now.timeIntervalSince(lastUpdateTime ?? now) >= throttleInterval {
                            lastUpdateTime = now
                            Task {
                                try? await viewModel.repository.updateStroke(stroke, in: canvasId)
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
