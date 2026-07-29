import Foundation

struct ServiceAccountKey: Codable {
    let type: String
    let project_id: String
    let private_key_id: String
    let private_key: String
    let client_email: String
    let client_id: String
    let auth_uri: String
    let token_uri: String
    let auth_provider_x509_cert_url: String
    let client_x509_cert_url: String
}

class ServiceAccountLoader {
    static func loadKey(from filename: String = "shared-drawing-7910b9b25a2d.json") -> ServiceAccountKey? {
        guard let path = Bundle.main.path(forResource: filename.replacingOccurrences(of: ".json", with: ""), ofType: "json") else {
            print("⚠️ Service account key file not found: \(filename)")
            return nil
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            print("⚠️ Failed to read service account key file")
            return nil
        }

        do {
            return try JSONDecoder().decode(ServiceAccountKey.self, from: data)
        } catch {
            print("⚠️ Failed to decode service account key: \(error)")
            return nil
        }
    }
}
