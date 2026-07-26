import Foundation

enum StrokeEvent {
    case added(Stroke)
    case updated(Stroke)
    case removed(String)  // stroke ID
}

protocol CanvasRepository {
    func listenToStrokes(canvasId: String) -> AsyncStream<StrokeEvent>
    func addStroke(_ stroke: Stroke, to canvasId: String) async throws
    func updateStroke(_ stroke: Stroke, in canvasId: String) async throws
    func removeStroke(id: String, from canvasId: String) async throws
}
