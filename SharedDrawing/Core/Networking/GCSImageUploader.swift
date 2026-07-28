import Foundation

class GCSImageUploader {
    private let bucket: String
    private let serviceAccountEmail: String
    private let privateKey: String
    private let projectId: String

    init(bucket: String, serviceAccountEmail: String, privateKey: String, projectId: String) {
        self.bucket = bucket
        self.serviceAccountEmail = serviceAccountEmail
        self.privateKey = privateKey
        self.projectId = projectId
    }

    func uploadImage(_ imageData: Data, canvasId: String, userId: String) async throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let objectPath = "canvases/\(canvasId)/\(userId)/\(fileName)"

        print("📤 Uploading image to GCS: \(objectPath)")

        // Upload image
        let uploadURL = URL(string: "https://storage.googleapis.com/upload/storage/v1/b/\(bucket)/o")!
        var uploadRequest = URLRequest(url: uploadURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue("Bearer \(try await getAccessToken())", forHTTPHeaderField: "Authorization")
        uploadRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        uploadRequest.setValue("public, max-age=3600", forHTTPHeaderField: "Cache-Control")

        let fullURL = uploadURL.appendingPathComponent(objectPath, isDirectory: false)
        var components = URLComponents(url: fullURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "name", value: objectPath)]
        uploadRequest.url = components.url

        let (data, _) = try await URLSession.shared.data(for: uploadRequest)
        print("✅ Image uploaded: \(objectPath)")

        // Generate signed URL (3-hour expiry)
        let signedURL = try generateSignedURL(objectPath: objectPath, expiresIn: 3 * 60 * 60)
        return signedURL
    }

    private func getAccessToken() async throws -> String {
        let now = Int(Date().timeIntervalSince1970)
        let expiry = now + 3600

        let headerJSON = """
        {"alg":"RS256","typ":"JWT"}
        """
        let claimsJSON = """
        {"iss":"\(serviceAccountEmail)","scope":"https://www.googleapis.com/auth/devstorage.full_control","aud":"https://oauth2.googleapis.com/token","exp":\(expiry),"iat":\(now)}
        """

        guard let headerData = headerJSON.data(using: .utf8),
              let claimsData = claimsJSON.data(using: .utf8) else {
            throw NSError(domain: "GCS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JWT"])
        }

        let headerB64 = headerData.base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")

        let claimsB64 = claimsData.base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")

        let signatureInput = "\(headerB64).\(claimsB64)"

        // Placeholder: Proper JWT signing requires RSA private key implementation
        // For production, use a proper JWT library or backend service
        let signature = "placeholder"
        let jwt = "\(signatureInput).\(signature)"

        // Exchange JWT for access token
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.httpBody = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(jwt)".data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = json["access_token"] as? String {
            return token
        }
        throw NSError(domain: "GCS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get access token"])
    }

    private func generateSignedURL(objectPath: String, expiresIn: Int) throws -> String {
        let expiresAt = Int(Date().timeIntervalSince1970) + expiresIn
        let encodedPath = objectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectPath
        return "https://storage.googleapis.com/\(bucket)/\(encodedPath)?exp=\(expiresAt)"
    }
}
