import Foundation
import FirebaseStorage

class GCSImageUploader {
    private let projectId: String

    init(bucket: String, serviceAccountEmail: String, privateKeyPEM: String, projectId: String) {
        self.projectId = projectId
    }

    func uploadImage(_ imageData: Data, canvasId: String, userId: String) async throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let objectPath = "canvases/\(canvasId)/\(userId)/\(fileName)"

        print("📤 Uploading image to Firebase Storage: \(objectPath)")

        let storage = Storage.storage()
        let ref = storage.reference().child(objectPath)

        // Upload with anonymous auth (already enabled in Firebase console)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        let _ = try await ref.putDataAsync(imageData, metadata: metadata)
        print("✅ Image uploaded: \(objectPath)")

        // Get download URL
        let downloadURL = try await ref.downloadURL()
        print("📍 Download URL: \(downloadURL.absoluteString)")
        return downloadURL.absoluteString
    }
}
