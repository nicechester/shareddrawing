import Foundation
import FirebaseDatabase

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
        print("📤 Adding stroke \(stroke.id) to canvas \(canvasId): \(strokeData.count) fields")
        try await strokeRef.setValue(strokeData)
        print("✅ Stroke \(stroke.id) added successfully")

        // Update canvas lastActivityAt for retention policy
        let metaRef = database.child("v2/canvases").child(canvasId).child("meta").child("lastActivityAt")
        try await metaRef.setValue(ServerValue.timestamp())
    }

    func updateStroke(_ stroke: Stroke, in canvasId: String) async throws {
        let strokeRef = database.child("v2/canvases").child(canvasId).child("strokes").child(stroke.id)
        let strokeData = try encodedStrokeData(stroke)
        print("📤 Updating stroke \(stroke.id) in canvas \(canvasId): \(stroke.points.count) points")
        try await strokeRef.updateChildValues(strokeData)
    }

    func removeStroke(id: String, from canvasId: String) async throws {
        let strokeRef = database.child("v2/canvases").child(canvasId).child("strokes").child(id)
        try await strokeRef.removeValue()
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

        return Stroke(
            id: id,
            userId: userId,
            color: color,
            width: width,
            points: points,
            isComplete: isComplete,
            createdAt: createdAt
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
            "createdAt": stroke.createdAt
        ]
    }
}
