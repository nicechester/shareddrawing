import Foundation

enum StrokeEvent {
    case added(Stroke)
    case updated(Stroke)
    case removed(String)  // stroke ID
}

enum TextObjectEvent {
    case added(TextObject)
    case updated(TextObject)
    case removed(String)
}

protocol CanvasRepository {
    func listenToStrokes(canvasId: String) -> AsyncStream<StrokeEvent>
    func addStroke(_ stroke: Stroke, to canvasId: String) async throws
    func updateStroke(_ stroke: Stroke, in canvasId: String) async throws
    func removeStroke(id: String, from canvasId: String) async throws
    func removeStrokes(ids: [String], from canvasId: String) async throws
    func updateBackgroundImageUrl(
        _ url: String,
        width: Double?,
        height: Double?,
        uploaderId: String?,
        uploaderName: String?,
        uploaderEmail: String?,
        for canvasId: String
    ) async throws
    func getBackgroundImageUrl(for canvasId: String) async throws -> String?
    func getBackgroundImageDimensions(for canvasId: String) async throws -> CGSize?
    func updateBackgroundImageDimensions(width: Double, height: Double, for canvasId: String) async throws
    func removeBackgroundImage(for canvasId: String) async throws
    func listenToTextObjects(canvasId: String) -> AsyncStream<TextObjectEvent>
    func addTextObject(_ textObject: TextObject, to canvasId: String) async throws
    func updateTextObject(_ textObject: TextObject, in canvasId: String) async throws
    func removeTextObject(id: String, from canvasId: String) async throws
    func removeTextObjects(ids: [String], from canvasId: String) async throws
}
