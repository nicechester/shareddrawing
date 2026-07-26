import SwiftUI

/// A UIViewRepresentable that wraps StrokeCaptureUIView for raw coalesced touch capture
struct StrokeCaptureView: UIViewRepresentable {
    /// Callback with captured points (called with batches of points from coalesced touches)
    var onPointsCapture: (([CGPoint]) -> Void)?

    /// Callback when touch ends or is cancelled
    var onStrokeEnded: (() -> Void)?

    func makeUIView(context: Context) -> StrokeCaptureUIView {
        let view = StrokeCaptureUIView()
        view.onPointsCapture = onPointsCapture
        view.onStrokeEnded = onStrokeEnded
        return view
    }

    func updateUIView(_ uiView: StrokeCaptureUIView, context: Context) {
        // Update callbacks in case they change
        uiView.onPointsCapture = onPointsCapture
        uiView.onStrokeEnded = onStrokeEnded
    }
}

/// Custom UIView that handles raw touch events and coalesced touch capture
class StrokeCaptureUIView: UIView {
    /// Callback with captured points (called with batches of points from coalesced touches)
    var onPointsCapture: (([CGPoint]) -> Void)?

    /// Callback when touch ends or is cancelled
    var onStrokeEnded: (() -> Void)?

    // MARK: - State

    /// Whether a touch is currently being tracked
    private var isDrawing = false

    /// The touch object we're currently tracking (single-touch only)
    private var currentTouchID: UITouch?

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        // Transparent background to allow touch passthrough
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        // Only accept the first touch; ignore multi-touch
        guard !isDrawing else { return }
        guard let touch = touches.first else { return }

        isDrawing = true
        currentTouchID = touch

        // Emit the initial point
        let location = touch.location(in: self)
        onPointsCapture?([location])
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)

        guard isDrawing, let touch = currentTouchID else { return }
        guard touches.contains(touch) else { return }

        // Use coalesced touches for high-resolution point samples
        if let coalescedTouches = event?.coalescedTouches(for: touch) {
            let points = coalescedTouches.map { $0.location(in: self) }

            // Only emit if we have points
            if !points.isEmpty {
                onPointsCapture?(points)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        guard isDrawing, let touch = currentTouchID else { return }
        guard touches.contains(touch) else { return }

        // Capture the final point from the touch
        let location = touch.location(in: self)
        onPointsCapture?([location])

        // Signal that the stroke is complete
        isDrawing = false
        currentTouchID = nil
        onStrokeEnded?()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)

        guard isDrawing, let touch = currentTouchID else { return }
        guard touches.contains(touch) else { return }

        // Treat cancellation like a stroke end
        isDrawing = false
        currentTouchID = nil
        onStrokeEnded?()
    }
}
