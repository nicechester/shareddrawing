import Foundation

class GCSImageUploader {
    private let bucket: String

    init(bucket: String, serviceAccountEmail: String, privateKeyPEM: String, projectId: String) {
        self.bucket = bucket
    }

    func uploadImage(_ imageData: Data, canvasId: String, userId: String) async throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let objectPath = "canvases/\(canvasId)/\(userId)/\(fileName)"

        print("📤 Uploading image to GCS: \(objectPath)")

        // Use JSON API for unauthenticated upload (requires bucket CORS + public write access)
        // For MVP, we'll use a simple multipart upload with no auth
        let uploadURL = URL(string: "https://www.googleapis.com/upload/storage/v1/b/\(bucket)/o?uploadType=multipart")!

        var uploadRequest = URLRequest(url: uploadURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")

        // Create multipart body
        let boundary = UUID().uuidString
        var body = Data()

        // Metadata part
        let metadata = #"{"name":"\#(objectPath)"}"#
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadata.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Image data part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--".data(using: .utf8)!)

        uploadRequest.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        uploadRequest.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: uploadRequest)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "GCS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to upload image"])
        }

        print("✅ Image uploaded: \(objectPath)")

        // Return public URL (requires bucket to allow public reads)
        let publicURL = "https://storage.googleapis.com/\(bucket)/\(objectPath)"
        print("📍 Public URL: \(publicURL)")
        return publicURL
    }
}
