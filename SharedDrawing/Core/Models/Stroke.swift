import Foundation

struct Stroke: Identifiable, Codable {
    let id: String
    let userId: String
    let color: String
    let width: Double
    var points: [StrokePoint]
    var isComplete: Bool
    let createdAt: TimeInterval
}
