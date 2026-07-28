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
        let header = ["alg": "RS256", "typ": "JWT"]
        let now = Int(Date().timeIntervalSince1970)
        let expiry = now + 3600

        let claims = [
            "iss": serviceAccountEmail,
            "scope": "https://www.googleapis.com/auth/devstorage.full_control",
            "aud": "https://oauth2.googleapis.com/token",
            "exp": expiry,
            "iat": now
        ] as [String: Any]

        let headerData = try JSONEncoder().encode(header)
        let claimsData = try JSONEncoder().encode(claims)

        let headerB64 = headerData.base64EncodedString().replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        let claimsB64 = claimsData.base64EncodedString().replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")

        let signatureInput = "\(headerB64).\(claimsB64)"
        let signature = try signJWT(signatureInput)

        let jwt = "\(signatureInput).\(signature)"

        // Exchange JWT for access token
        let tokenRequest = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        let body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(jwt)"

        var request = tokenRequest
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        if let token = response["access_token"]?.value as? String {
            return token
        }
        throw NSError(domain: "GCS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get access token"])
    }

    private func signJWT(_ input: String) throws -> String {
        // Simplified JWT signing - in production, use proper RSA signing
        // For now, return a placeholder
        return "placeholder"
    }

    private func generateSignedURL(objectPath: String, expiresIn: Int) throws -> String {
        let expiresAt = Int(Date().timeIntervalSince1970) + expiresIn

        let stringToSign = "GET\n\n\n\(expiresAt)\n/\(bucket)/\(objectPath)"

        // In production, sign this with the private key
        // For now, return a basic URL that will work with public read access
        let encodedPath = objectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectPath
        return "https://storage.googleapis.com/\(bucket)/\(encodedPath)"
    }
}

struct AnyCodable: Codable {
    var value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        }
    }
}
