import Foundation
import Observation

@Observable
class CanvasViewModel {
    var strokes: [Stroke] = []
    var currentColor: String = "#000000"  // Black by default
    var canvasId: String
    var backgroundImageUrl: String?
    var viewportOffset: CGPoint = .zero  // Pan offset for larger virtual canvas
    var zoomScale: CGFloat = 1.0  // 0.5–5.0
    var rotationAngle: Double = 0.0  // Radians
    var canUndo: Bool { !undoStack.isEmpty || lastClearedStrokes != nil }

    let repository: CanvasRepository
    private let authService: AuthService
    private var strokeListenerTask: Task<Void, Never>?
    private var undoStack = Stack<Stroke>()
    private var lastClearedStrokes: [Stroke]?

    init(canvasId: String, repository: CanvasRepository, authService: AuthService) {
        self.canvasId = canvasId
        self.repository = repository
        self.authService = authService
        setupStrokeListener()
    }

    func switchToCanvas(_ newCanvasId: String) {
        strokeListenerTask?.cancel()
        canvasId = newCanvasId
        strokes = []
        backgroundImageUrl = nil
        resetTransform()
        setupStrokeListener()
    }

    func pan(screenDelta: CGPoint) {
        // Convert screen-space delta to world-space delta accounting for rotation and scale
        var delta = screenDelta

        // Undo scale
        delta.x /= zoomScale
        delta.y /= zoomScale

        // Undo rotation
        let cos = cos(-rotationAngle)
        let sin = sin(-rotationAngle)
        let rotatedX = delta.x * cos - delta.y * sin
        let rotatedY = delta.x * sin + delta.y * cos

        viewportOffset.x += rotatedX
        viewportOffset.y += rotatedY
    }

    func zoom(by scale: CGFloat) {
        zoomScale = max(0.5, min(5.0, zoomScale * scale))
    }

    func rotate(by angle: Double) {
        rotationAngle += angle
    }

    func resetTransform() {
        viewportOffset = .zero
        zoomScale = 1.0
        rotationAngle = 0.0
    }

    private func setupStrokeListener() {
        // Load background image from metadata
        Task {
            do {
                let url = try await repository.getBackgroundImageUrl(for: canvasId)
                if let url = url {
                    self.backgroundImageUrl = url
                    print("📸 Loaded background image URL: \(url)")
                }
            } catch {
                print("⚠️ Failed to load background image URL: \(error)")
            }
        }

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
            undoStack.push(finalStroke)
        } catch {
            print("Error submitting stroke: \(error)")
        }
    }

    func undo() async {
        if let clearedStrokes = lastClearedStrokes {
            lastClearedStrokes = nil
            for stroke in clearedStrokes {
                do {
                    try await repository.addStroke(stroke, to: canvasId)
                } catch {
                    print("❌ Error undoing clear: \(error)")
                }
            }
        } else if let stroke = undoStack.pop() {
            do {
                try await repository.removeStroke(id: stroke.id, from: canvasId)
            } catch {
                print("❌ Error undoing stroke: \(error)")
            }
        }
    }

    func recordClear(_ strokes: [Stroke]) {
        lastClearedStrokes = strokes
    }

    func updateBackgroundImage(_ imageUrl: String) async throws {
        try await repository.updateBackgroundImageUrl(imageUrl, for: canvasId)
        self.backgroundImageUrl = imageUrl
        print("✅ Background image URL updated: \(imageUrl)")
    }

    deinit {
        strokeListenerTask?.cancel()
    }
}
