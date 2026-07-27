import Foundation
import Observation

@Observable
class CanvasViewModel {
    var strokes: [Stroke] = []
    var currentColor: String = "#000000"  // Black by default
    var canvasId: String

    let repository: CanvasRepository
    private let authService: AuthService
    private var strokeListenerTask: Task<Void, Never>?

    init(canvasId: String, repository: CanvasRepository, authService: AuthService) {
        self.canvasId = canvasId
        self.repository = repository
        self.authService = authService
        setupStrokeListener()
    }

    private func setupStrokeListener() {
        // Listen to real-time stroke updates via AsyncStream
        strokeListenerTask = Task {
            for await event in repository.listenToStrokes(canvasId: canvasId) {
                switch event {
                case .added(let stroke):
                    strokes.append(stroke)
                case .updated(let stroke):
                    if let index = strokes.firstIndex(where: { $0.id == stroke.id }) {
                        strokes[index] = stroke
                    }
                case .removed(let strokeId):
                    strokes.removeAll { $0.id == strokeId }
                }
            }
        }
    }

    func addStrokePoint(_ point: CGPoint, to stroke: inout Stroke) {
        let strokePoint = StrokePoint(
            x: Double(point.x),
            y: Double(point.y),
            t: Int(Date().timeIntervalSince(Date(timeIntervalSince1970: stroke.createdAt)) * 1000)
        )
        stroke.points.append(strokePoint)
    }

    func startStroke(at point: CGPoint) -> Stroke {
        let now = Date().timeIntervalSince1970
        return Stroke(
            id: UUID().uuidString,
            userId: authService.currentUserID ?? "anonymous",
            color: currentColor,
            width: 2.0,
            points: [StrokePoint(x: Double(point.x), y: Double(point.y), t: 0)],
            isComplete: false,
            createdAt: now
        )
    }

    func submitStroke(_ stroke: Stroke) async {
        var finalStroke = stroke
        finalStroke.isComplete = true
        do {
            try await repository.addStroke(finalStroke, to: canvasId)
        } catch {
            print("Error submitting stroke: \(error)")
        }
    }

    deinit {
        strokeListenerTask?.cancel()
    }
}
