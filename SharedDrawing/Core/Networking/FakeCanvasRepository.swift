import Foundation

class FakeCanvasRepository: CanvasRepository {
    private var strokes: [String: Stroke] = [:]
    private let queue = DispatchQueue(label: "com.shareddrawing.fake-repository")

    func listenToStrokes(canvasId: String) -> AsyncStream<StrokeEvent> {
        AsyncStream { continuation in
            queue.async {
                // Yield existing strokes as "added" events
                for (_, stroke) in self.strokes.sorted(by: { $0.key < $1.key }) {
                    continuation.yield(.added(stroke))
                }
            }

            continuation.onTermination = { _ in
                // Clean up if needed
            }
        }
    }

    func addStroke(_ stroke: Stroke, to canvasId: String) async throws {
        await queue.async {
            self.strokes[stroke.id] = stroke
        }
    }

    func updateStroke(_ stroke: Stroke, in canvasId: String) async throws {
        await queue.async {
            self.strokes[stroke.id] = stroke
        }
    }

    func removeStroke(id: String, from canvasId: String) async throws {
        await queue.async {
            self.strokes.removeValue(forKey: id)
        }
    }

    // MARK: - Test Helpers

    /// Reset all strokes (useful for test setup/teardown)
    func reset() {
        queue.sync {
            strokes.removeAll()
        }
    }

    /// Get all stored strokes (for test assertions)
    func getAllStrokes() -> [Stroke] {
        queue.sync {
            strokes.values.sorted { $0.createdAt < $1.createdAt }
        }
    }
}
