import Foundation

struct Stroke: Identifiable, Codable {
    let id: String
    let userId: String
    let color: String  // hex, e.g. "#FF3B30"
    let width: Double  // default ~2
    let points: [StrokePoint]
    let isComplete: Bool  // false while drawing, true when finished
    let createdAt: TimeInterval  // Unix timestamp from Firebase ServerValue
}
