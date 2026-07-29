import Foundation

struct CanvasMeta: Codable {
    let name: String
    let createdBy: String
    let createdAt: TimeInterval
    let lastActivityAt: TimeInterval
    let imageWidth: Double?
    let imageHeight: Double?
}
