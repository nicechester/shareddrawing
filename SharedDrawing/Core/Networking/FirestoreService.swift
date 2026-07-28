import Foundation
import FirebaseFirestore

class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    func saveCanvas(id: String, name: String, userId: String) async throws {
        let ref = db.collection("users").document(userId).collection("canvases").document(id)
        try await ref.setData([
            "canvasId": id,
            "name": name,
            "createdAt": Timestamp(date: Date()),
            "lastActivityAt": Timestamp(date: Date())
        ], merge: true)
    }

    func updateLastActivity(canvasId: String, userId: String) async throws {
        let ref = db.collection("users").document(userId).collection("canvases").document(canvasId)
        try await ref.updateData([
            "lastActivityAt": Timestamp(date: Date())
        ])
    }

    func getCanvases(userId: String) async throws -> [CanvasMetadata] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("canvases")
            .order(by: "lastActivityAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: CanvasMetadata.self)
        }
    }

    func listenToCanvases(userId: String, completion: @escaping ([CanvasMetadata]) -> Void) -> ListenerRegistration {
        return db.collection("users")
            .document(userId)
            .collection("canvases")
            .order(by: "lastActivityAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let canvases = docs.compactMap { try? $0.data(as: CanvasMetadata.self) }
                completion(canvases)
            }
    }
}

struct CanvasMetadata: Codable {
    @DocumentID var id: String?
    let canvasId: String
    let name: String
    let createdAt: Timestamp
    let lastActivityAt: Timestamp

    var createdDate: Date { createdAt.dateValue() }
    var lastActivityDate: Date { lastActivityAt.dateValue() }
}
