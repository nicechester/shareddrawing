import Foundation
import Observation

@Observable
class CanvasViewModel {
    var strokes: [Stroke] = []
    var currentColor: String = "#000000"  // Black by default
    var canvasId: String
    var backgroundImageUrl: String?
    var imageSize: CGSize?  // Width/height of background image
    var viewportOffset: CGPoint = .zero  // Pan offset for larger virtual canvas
    var zoomScale: CGFloat = 1.0  // 0.5–5.0
    var rotationAngle: Double = 0.0  // Radians
    var canUndo: Bool { !undoStack.isEmpty || lastClearedStrokes != nil }
    var isAnonymous: Bool { authService.isAnonymous }
    var selectedPenStyle: PenStyle {
        didSet {
            UserDefaults.standard.set(selectedPenStyle.rawValue, forKey: Self.penStyleDefaultsKey)
        }
    }

    private static let penStyleDefaultsKey = "com.shareddrawing.selectedPenStyle"

    let repository: CanvasRepository
    private let authService: AuthService
    private var strokeListenerTask: Task<Void, Never>?
    private var backgroundImageListenerTask: Task<Void, Never>?
    private var undoStack = Stack<Stroke>()
    private var lastClearedStrokes: [Stroke]?

    init(canvasId: String, repository: CanvasRepository, authService: AuthService) {
        self.canvasId = canvasId
        self.repository = repository
        self.authService = authService
        let savedRaw = UserDefaults.standard.string(forKey: Self.penStyleDefaultsKey)
        self.selectedPenStyle = savedRaw.flatMap(PenStyle.init(rawValue:)) ?? .default
        setupStrokeListener()
    }

    func switchToCanvas(_ newCanvasId: String) {
        strokeListenerTask?.cancel()
        backgroundImageListenerTask?.cancel()
        canvasId = newCanvasId
        strokes = []
        backgroundImageUrl = nil
        imageSize = nil
        resetTransform()
        setupStrokeListener()
    }

    func pan(screenDelta: CGPoint, fitScale: CGFloat = 1.0) {
        // Convert screen-space delta to world-space delta accounting for rotation and scale
        var delta = screenDelta

        // Undo fit scale
        delta.x /= fitScale
        delta.y /= fitScale

        // Undo zoom scale
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

    func worldSize(fallback: CGSize) -> CGSize {
        return imageSize ?? fallback
    }

    func fitScale(canvasSize: CGSize) -> CGFloat {
        guard let imageSize = imageSize else { return 1.0 }
        let scaleX = canvasSize.width / imageSize.width
        let scaleY = canvasSize.height / imageSize.height
        return min(scaleX, scaleY)  // Fit to smallest dimension
    }

    func backfillImageDimensionsIfNeeded(width: Double, height: Double) async {
        if imageSize == nil {
            imageSize = CGSize(width: width, height: height)
            try? await repository.updateBackgroundImageDimensions(width: width, height: height, for: canvasId)
        }
    }

    private func setupStrokeListener() {
        // Load background image from metadata and listen for real-time updates
        backgroundImageListenerTask = Task {
            while !Task.isCancelled {
                do {
                    let url = try await repository.getBackgroundImageUrl(for: canvasId)
                    if url != backgroundImageUrl {
                        backgroundImageUrl = url
                        if let url = url {
                            print("📸 Loaded background image URL: \(url)")
                        } else {
                            print("📸 Background image cleared")
                        }
                    }

                    // Poll for dimension updates
                    if let dimensions = try await repository.getBackgroundImageDimensions(for: canvasId) {
                        if imageSize != dimensions {
                            imageSize = dimensions
                            print("📐 Loaded image dimensions: \(dimensions)")
                        }
                    }
                } catch {
                    print("⚠️ Failed to load background image metadata: \(error)")
                }

                // Check for updates every 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
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
            width: selectedPenStyle.baseWidth,
            points: [StrokePoint(x: Double(point.x), y: Double(point.y), t: 0)],
            isComplete: false,
            createdAt: now,
            style: selectedPenStyle.rawValue
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

    func updateBackgroundImage(_ imageUrl: String, width: Double? = nil, height: Double? = nil) async throws {
        let uploaderId = isAnonymous ? nil : authService.currentUserID
        let uploaderName = isAnonymous ? nil : authService.currentUserName
        let uploaderEmail = isAnonymous ? nil : authService.currentUserEmail

        try await repository.updateBackgroundImageUrl(
            imageUrl,
            width: width,
            height: height,
            uploaderId: uploaderId,
            uploaderName: uploaderName,
            uploaderEmail: uploaderEmail,
            for: canvasId
        )
        self.backgroundImageUrl = imageUrl
        if let width = width, let height = height {
            self.imageSize = CGSize(width: width, height: height)
        }
        print("✅ Background image URL updated: \(imageUrl)")
    }

    deinit {
        strokeListenerTask?.cancel()
    }
}
