import Foundation

struct TextObject: Identifiable, Codable {
    let id: String
    let userId: String
    let text: String
    let x: Double
    let y: Double
    let color: String
    let fontSize: Double
    let isComplete: Bool
    let createdAt: TimeInterval
}
