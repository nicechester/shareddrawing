import Foundation
import SwiftUI

extension Stroke {
    /// Compute the bounding box of the stroke from its points
    var boundingBox: CGRect {
        guard !points.isEmpty else { return .zero }

        let xs = points.map { $0.x }
        let ys = points.map { $0.y }

        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    /// Compute the minimum distance from a point to any line segment in the stroke
    /// Returns a very large number if the stroke has fewer than 2 points
    func minDistance(to point: CGPoint) -> Double {
        guard points.count >= 2 else { return Double.greatestFiniteMagnitude }

        var minDist = Double.greatestFiniteMagnitude

        for i in 0..<(points.count - 1) {
            let p1 = CGPoint(x: points[i].x, y: points[i].y)
            let p2 = CGPoint(x: points[i + 1].x, y: points[i + 1].y)

            let dist = distanceFromPointToSegment(point, segmentStart: p1, segmentEnd: p2)
            minDist = min(minDist, dist)
        }

        return minDist
    }

    /// Compute distance from a point to a line segment
    private func distanceFromPointToSegment(_ point: CGPoint, segmentStart: CGPoint, segmentEnd: CGPoint) -> Double {
        let dx = segmentEnd.x - segmentStart.x
        let dy = segmentEnd.y - segmentStart.y
        let lenSquared = dx * dx + dy * dy

        if lenSquared == 0 {
            // Segment is a point; return distance to that point
            let px = point.x - segmentStart.x
            let py = point.y - segmentStart.y
            return sqrt(px * px + py * py)
        }

        // Project point onto the line segment
        let t = max(0, min(1, ((point.x - segmentStart.x) * dx + (point.y - segmentStart.y) * dy) / lenSquared))
        let projX = segmentStart.x + t * dx
        let projY = segmentStart.y + t * dy

        let px = point.x - projX
        let py = point.y - projY
        return sqrt(px * px + py * py)
    }
}

extension TextObject {
    /// Estimate bounding box for text object based on position, text, and font size
    /// Used for eraser hit-testing; actual rendering size may vary
    func boundingBox() -> CGRect {
        let textSize = estimateTextSize()
        return CGRect(
            x: x - textSize.width / 2,
            y: y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
    }

    /// Check if a point (with radius) intersects this text object
    func intersects(point: CGPoint, radius: Double) -> Bool {
        let bbox = boundingBox()
        let expandedBox = bbox.insetBy(dx: -radius, dy: -radius)
        return expandedBox.contains(point)
    }

    /// Estimate the size of rendered text
    private func estimateTextSize() -> CGSize {
        let nsString = text as NSString
        let font = UIFont.systemFont(ofSize: fontSize)
        return nsString.size(withAttributes: [.font: font])
    }
}
