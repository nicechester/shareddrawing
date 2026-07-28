import Foundation
import CryptoKit

class GCSImageUploader {
    private let bucket: String
    private let serviceAccountEmail: String
    private let privateKeyPEM: String
    private let projectId: String

    init(bucket: String, serviceAccountEmail: String, privateKeyPEM: String, projectId: String) {
        self.bucket = bucket
        self.serviceAccountEmail = serviceAccountEmail
        self.privateKeyPEM = privateKeyPEM
        self.projectId = projectId
    }

    func uploadImage(_ imageData: Data, canvasId: String, userId: String) async throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let objectPath = "canvases/\(canvasId)/\(userId)/\(fileName)"

        print("📤 Uploading image to GCS: \(objectPath)")

        let accessToken = try await getAccessToken()

        // Upload image to GCS
        let uploadURL = URL(string: "https://storage.googleapis.com/upload/storage/v1/b/\(bucket)/o?uploadType=media&name=\(objectPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? objectPath)")!
        var uploadRequest = URLRequest(url: uploadURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        uploadRequest.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        uploadRequest.httpBody = imageData

        let (_, response) = try await URLSession.shared.data(for: uploadRequest)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "GCS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to upload image"])
        }

        print("✅ Image uploaded: \(objectPath)")

        // Generate signed URL (3-hour expiry)
        let signedURL = try generateSignedURL(objectPath: objectPath, expiresIn: 3 * 60 * 60)
        return signedURL
    }

    private func getAccessToken() async throws -> String {
        let now = Int(Date().timeIntervalSince1970)
        let expiry = now + 3600

        let header = base64URLEncode(#"{"alg":"RS256","typ":"JWT"}"#)
        let claims = base64URLEncode(#"{"iss":"\#(serviceAccountEmail)","scope":"https://www.googleapis.com/auth/devstorage.full_control","aud":"https://oauth2.googleapis.com/token","exp":\#(expiry),"iat":\#(now)}"#)

        let signatureInput = "\(header).\(claims)"
        let signature = try signJWT(signatureInput)
        let jwt = "\(signatureInput).\(signature)"

        // Exchange JWT for access token
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(jwt)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Access token response: \(httpResponse.statusCode)")
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let token = json["access_token"] as? String {
                print("✅ Access token obtained")
                return token
            } else if let error = json["error"] as? String {
                print("❌ GCS error: \(error) - \(json["error_description"] ?? "")")
                throw NSError(domain: "GCS", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
            }
        }

        let responseStr = String(data: data, encoding: .utf8) ?? "unknown"
        print("❌ Failed to get access token. Response: \(responseStr)")
        throw NSError(domain: "GCS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get access token"])
    }

    private func signJWT(_ input: String) throws -> String {
        guard let inputData = input.data(using: .utf8) else {
            throw NSError(domain: "GCS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JWT input"])
        }

        // Parse private key and sign
        let privateKey = try parsePrivateKey(privateKeyPEM)
        let signature = try signData(inputData, with: privateKey)
        return base64URLEncode(signature)
    }

    private func parsePrivateKey(_ pemString: String) throws -> SecKey {
        let pemData = pemString
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let keyData = Data(base64Encoded: pemData) else {
            print("❌ Failed to decode base64 private key (length: \(pemData.count))")
            throw NSError(domain: "GCS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid private key format"])
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
            let errorMsg = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            print("❌ Failed to create SecKey: \(errorMsg)")
            throw NSError(domain: "GCS", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        print("✅ Private key loaded successfully")
        return key
    }

    private func signData(_ data: Data, with key: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            key,
            .rsaSignatureMessagePKCS1v15SHA256,
            data as CFData,
            &error
        ) as Data? else {
            throw error?.takeRetainedValue() as Error? ?? NSError(domain: "GCS", code: -1)
        }
        return signature
    }

    private func base64URLEncode(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        return base64URLEncode(data)
    }

    private func base64URLEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }

    private func generateSignedURL(objectPath: String, expiresIn: Int) throws -> String {
        let expiresAt = Int(Date().timeIntervalSince1970) + expiresIn
        let encodedPath = objectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectPath
        return "https://storage.googleapis.com/\(bucket)/\(encodedPath)?exp=\(expiresAt)"
    }
}
