import Foundation
import FirebaseDatabase
import os.log

private let logger = Logger(subsystem: "io.github.nicechester.shareddrawing", category: "Firebase")

class FirebaseCanvasRepository: CanvasRepository {
    private let database: DatabaseReference

    init(database: DatabaseReference = Database.database().reference()) {
        self.database = database
    }

    func listenToStrokes(canvasId: String) -> AsyncStream<StrokeEvent> {
        AsyncStream { continuation in
            let strokesRef = database.child("v2/canvases").child(canvasId).child("strokes")
            var listener: UInt?

            listener = strokesRef.observe(.childAdded) { [weak self] snapshot in
                guard let stroke = self?.decodeStroke(from: snapshot) else { return }
                continuation.yield(.added(stroke))
            } withCancel: { error in
                continuation.finish()
            }

            strokesRef.observe(.childChanged) { [weak self] snapshot in
                guard let stroke = self?.decodeStroke(from: snapshot) else { return }
                continuation.yield(.updated(stroke))
            }

            strokesRef.observe(.childRemoved) { snapshot in
                guard let strokeId = snapshot.key as String? else { return }
                continuation.yield(.removed(strokeId))
            }

            continuation.onTermination = { _ in
                if let listenerHandle = listener {
                    strokesRef.removeObserver(withHandle: listenerHandle)
                }
                strokesRef.removeAllObservers()
            }
        }
    }

    func addStroke(_ stroke: Stroke, to canvasId: String) async throws {
        let strokeRef = database.child("v2/canvases").child(canvasId).child("strokes").child(stroke.id)
        let strokeData = try encodedStrokeData(stroke)
        logger.debug("Adding stroke \(stroke.id) to canvas \(canvasId): \(strokeData.count) fields")
        try await strokeRef.setValue(strokeData)
        logger.debug("Stroke \(stroke.id) added successfully")

        // Update canvas lastActivityAt for retention policy
        let metaRef = database.child("v2/canvases").child(canvasId).child("meta").child("lastActivityAt")
        try await metaRef.setValue(ServerValue.timestamp())
    }

    func updateStroke(_ stroke: Stroke, in canvasId: String) async throws {
        let strokeRef = database.child("v2/canvases").child(canvasId).child("strokes").child(stroke.id)
        let strokeData = try encodedStrokeData(stroke)
        logger.debug("Updating stroke \(stroke.id) in canvas \(canvasId): \(stroke.points.count) points")
        try await strokeRef.updateChildValues(strokeData)
    }

    func removeStroke(id: String, from canvasId: String) async throws {
        let strokeRef = database.child("v2/canvases").child(canvasId).child("strokes").child(id)
        try await strokeRef.removeValue()
    }

    func updateBackgroundImageUrl(
        _ url: String,
        width: Double?,
        height: Double?,
        uploaderId: String?,
        uploaderName: String?,
        uploaderEmail: String?,
        for canvasId: String
    ) async throws {
        let metaRef = database.child("v2/canvases").child(canvasId).child("meta")
        var updates: [String: Any] = ["backgroundImageUrl": url]
        if let width = width {
            updates["imageWidth"] = width
        }
        if let height = height {
            updates["imageHeight"] = height
        }
        if let uploaderId = uploaderId {
            updates["uploadedBy"] = uploaderId
            updates["uploaderName"] = uploaderName as Any
            updates["uploaderEmail"] = uploaderEmail as Any
            updates["uploadedAt"] = ServerValue.timestamp()
        }
        try await metaRef.updateChildValues(updates)
    }

    func getBackgroundImageUrl(for canvasId: String) async throws -> String? {
        let metaRef = database.child("v2/canvases").child(canvasId).child("meta").child("backgroundImageUrl")
        let snapshot = try await metaRef.getData()
        return snapshot.value as? String
    }

    func getBackgroundImageDimensions(for canvasId: String) async throws -> CGSize? {
        let metaRef = database.child("v2/canvases").child(canvasId).child("meta")
        let snapshot = try await metaRef.getData()
        guard let dict = snapshot.value as? [String: Any],
              let width = dict["imageWidth"] as? Double,
              let height = dict["imageHeight"] as? Double else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    func updateBackgroundImageDimensions(width: Double, height: Double, for canvasId: String) async throws {
        let metaRef = database.child("v2/canvases").child(canvasId).child("meta")
        try await metaRef.updateChildValues(["imageWidth": width, "imageHeight": height])
    }

    func removeBackgroundImage(for canvasId: String) async throws {
        let metaRef = database.child("v2/canvases").child(canvasId).child("meta")
        try await metaRef.updateChildValues([
            "backgroundImageUrl": NSNull(),
            "imageWidth": NSNull(),
            "imageHeight": NSNull(),
            "uploadedBy": NSNull(),
            "uploaderName": NSNull(),
            "uploaderEmail": NSNull(),
            "uploadedAt": NSNull()
        ])
        logger.debug("Dropped backgroundImageUrl, imageWidth, imageHeight, and uploader fields for canvas \(canvasId)")
    }

    // MARK: - Private Helpers

    private func decodeStroke(from snapshot: DataSnapshot) -> Stroke? {
        guard let dict = snapshot.value as? [String: Any] else { return nil }

        let id = snapshot.key
        guard let userId = dict["userId"] as? String,
              let color = dict["color"] as? String,
              let width = dict["width"] as? Double,
              let isComplete = dict["isComplete"] as? Bool,
              let createdAt = dict["createdAt"] as? TimeInterval else {
            return nil
        }

        var points: [StrokePoint] = []
        if let pointsArray = dict["points"] as? [[String: Any]] {
            points = pointsArray.compactMap { pointDict in
                guard let x = pointDict["x"] as? Double,
                      let y = pointDict["y"] as? Double,
                      let t = pointDict["t"] as? Int else {
                    return nil
                }
                return StrokePoint(x: x, y: y, t: t)
            }
        }

        let style = dict["style"] as? String ?? PenStyle.default.rawValue
        return Stroke(
            id: id,
            userId: userId,
            color: color,
            width: width,
            points: points,
            isComplete: isComplete,
            createdAt: createdAt,
            style: style
        )
    }

    private func encodedStrokeData(_ stroke: Stroke) throws -> [String: Any] {
        let pointsData = stroke.points.map { point -> [String: Any] in
            ["x": point.x, "y": point.y, "t": point.t]
        }

        return [
            "userId": stroke.userId,
            "color": stroke.color,
            "width": stroke.width,
            "points": pointsData,
            "isComplete": stroke.isComplete,
            "createdAt": stroke.createdAt,
            "style": stroke.style
        ]
    }

    func listenToTextObjects(canvasId: String) -> AsyncStream<TextObjectEvent> {
        AsyncStream { continuation in
            let textObjectsRef = database.child("v2/canvases").child(canvasId).child("textObjects")
            var listener: UInt?

            listener = textObjectsRef.observe(.childAdded) { [weak self] snapshot in
                guard let textObject = self?.decodeTextObject(from: snapshot) else { return }
                continuation.yield(.added(textObject))
            } withCancel: { error in
                continuation.finish()
            }

            textObjectsRef.observe(.childChanged) { [weak self] snapshot in
                guard let textObject = self?.decodeTextObject(from: snapshot) else { return }
                continuation.yield(.updated(textObject))
            }

            textObjectsRef.observe(.childRemoved) { snapshot in
                let textObjectId = snapshot.key
                continuation.yield(.removed(textObjectId))
            }

            continuation.onTermination = { _ in
                if let listenerHandle = listener {
                    textObjectsRef.removeObserver(withHandle: listenerHandle)
                }
                textObjectsRef.removeAllObservers()
            }
        }
    }

    func addTextObject(_ textObject: TextObject, to canvasId: String) async throws {
        let textObjectRef = database.child("v2/canvases").child(canvasId).child("textObjects").child(textObject.id)
        let textObjectData = try encodedTextObjectData(textObject)
        logger.debug("Adding text object \(textObject.id) to canvas \(canvasId)")
        try await textObjectRef.setValue(textObjectData)

        let metaRef = database.child("v2/canvases").child(canvasId).child("meta").child("lastActivityAt")
        try await metaRef.setValue(ServerValue.timestamp())
    }

    func updateTextObject(_ textObject: TextObject, in canvasId: String) async throws {
        let textObjectRef = database.child("v2/canvases").child(canvasId).child("textObjects").child(textObject.id)
        let textObjectData = try encodedTextObjectData(textObject)
        logger.debug("Updating text object \(textObject.id) in canvas \(canvasId)")
        try await textObjectRef.updateChildValues(textObjectData)
    }

    func removeTextObject(id: String, from canvasId: String) async throws {
        let textObjectRef = database.child("v2/canvases").child(canvasId).child("textObjects").child(id)
        logger.debug("Removing text object \(id) from canvas \(canvasId)")
        try await textObjectRef.removeValue()
    }

    private func decodeTextObject(from snapshot: DataSnapshot) -> TextObject? {
        guard let dict = snapshot.value as? [String: Any] else { return nil }

        let id = snapshot.key
        guard let userId = dict["userId"] as? String,
              let text = dict["text"] as? String,
              let x = dict["x"] as? Double,
              let y = dict["y"] as? Double,
              let color = dict["color"] as? String,
              let fontSize = dict["fontSize"] as? Double,
              let isComplete = dict["isComplete"] as? Bool,
              let createdAt = dict["createdAt"] as? TimeInterval else {
            return nil
        }

        return TextObject(id: id, userId: userId, text: text, x: x, y: y, color: color, fontSize: fontSize, isComplete: isComplete, createdAt: createdAt)
    }

    private func encodedTextObjectData(_ textObject: TextObject) throws -> [String: Any] {
        return [
            "userId": textObject.userId,
            "text": textObject.text,
            "x": textObject.x,
            "y": textObject.y,
            "color": textObject.color,
            "fontSize": textObject.fontSize,
            "isComplete": textObject.isComplete,
            "createdAt": textObject.createdAt
        ]
    }
}
