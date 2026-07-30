import Foundation
import JWTKit
import os.log

private let logger = Logger(subsystem: "io.github.nicechester.shareddrawing", category: "GCS")

struct GCSClaims: JWTPayload {
    var iss: IssuerClaim
    var scope: String
    var aud: AudienceClaim
    var exp: ExpirationClaim
    var iat: IssuedAtClaim

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.exp.verifyNotExpired()
    }
}

class GCSImageUploader {
    private let bucket: String
    private let serviceAccountEmail: String
    private let privateKeyPEM: String
    private let projectId: String

    init(bucket: String, serviceAccountEmail: String, privateKeyPEM: String, projectId: String) {
        self.bucket = bucket
        self.serviceAccountEmail = serviceAccountEmail
        // Google's JSON has literal \n, convert to real newlines
        self.privateKeyPEM = privateKeyPEM.replacingOccurrences(of: "\\n", with: "\n")
        self.projectId = projectId
    }

    func uploadImage(_ imageData: Data, canvasId: String, userId: String) async throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let objectPath = "canvases/\(canvasId)/\(userId)/\(fileName)"
        logger.debug("Uploading image to GCS: \(objectPath)")

        let accessToken = try await getAccessToken()

        let encodedName = objectPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? objectPath
        let uploadURL = URL(string: "https://storage.googleapis.com/upload/storage/v1/b/\(bucket)/o?uploadType=media&name=\(encodedName)")!

        var req = URLRequest(url: uploadURL)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        req.httpBody = imageData

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "GCS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard http.statusCode == 200 else {
            let errorBody = String(data: imageData.prefix(500), encoding: .utf8) ?? ""
            logger.error("Upload failed: \(http.statusCode) \(errorBody)")
            throw NSError(domain: "GCS", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Upload failed: \(http.statusCode)"])
        }

        logger.info("Image uploaded: \(objectPath)")
        return "https://storage.googleapis.com/\(bucket)/\(objectPath)"
    }

    private func getAccessToken() async throws -> String {
        let keys = JWTKeyCollection()
        
        // JWTKit 5: Use Insecure.RSA for Google's RSA keys
        let rsaKey = try Insecure.RSA.PrivateKey(pem: privateKeyPEM)
        await keys.add(rsa: rsaKey, digestAlgorithm: .sha256)

        let now = Date()
        let payload = GCSClaims(
            iss: .init(value: serviceAccountEmail),
            scope: "https://www.googleapis.com/auth/devstorage.full_control",
            aud: .init(value: "https://oauth2.googleapis.com/token"),
            exp: .init(value: now.addingTimeInterval(3600)),
            iat: .init(value: now)
        )

        let jwt = try await keys.sign(payload)
        logger.debug("JWT created, exchanging for access token...")

        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(jwt)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse {
            logger.debug("Token response: \(http.statusCode)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let token = json?["access_token"] as? String else {
            let err = json?["error_description"] as? String ?? json?["error"] as? String ?? "Unknown"
            logger.error("GCS error: \(err)")
            throw NSError(domain: "GCS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Token error: \(err)"])
        }
        logger.info("Access token obtained")
        return token
    }
}
