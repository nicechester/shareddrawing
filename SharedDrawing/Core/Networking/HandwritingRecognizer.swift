import Foundation
import Vision
import UIKit
import CoreGraphics
import os.log

private let logger = Logger(subsystem: "io.github.nicechester.shareddrawing", category: "Handwriting")

actor HandwritingRecognizer {
    func recognizeText(from strokes: [Stroke]) async throws -> String? {
        guard !strokes.isEmpty else { return nil }

        // Compute bounding box
        var minX = Double.infinity, maxX = -Double.infinity
        var minY = Double.infinity, maxY = -Double.infinity
        for stroke in strokes {
            for point in stroke.points {
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
        }

        let padding: CGFloat = 20
        let naturalWidth = CGFloat(maxX - minX) + padding * 2
        let naturalHeight = CGFloat(maxY - minY) + padding * 2
        let minRenderSize: CGFloat = 200

        let renderWidth = max(naturalWidth, minRenderSize)
        let renderHeight = max(naturalHeight, minRenderSize)
        let scale = renderWidth / (naturalWidth > 0 ? naturalWidth : 1)

        // Render strokes to image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: renderWidth, height: renderHeight))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: renderWidth, height: renderHeight)))

            UIColor.black.setStroke()
            for stroke in strokes {
                let path = UIBezierPath()
                path.lineWidth = 4
                path.lineCapStyle = .round
                path.lineJoinStyle = .round

                for (index, point) in stroke.points.enumerated() {
                    let scaledX = (CGFloat(point.x) - CGFloat(minX)) * scale + padding
                    let scaledY = (CGFloat(point.y) - CGFloat(minY)) * scale + padding
                    let cgPoint = CGPoint(x: scaledX, y: scaledY)

                    if index == 0 {
                        path.move(to: cgPoint)
                    } else {
                        path.addLine(to: cgPoint)
                    }
                }
                path.stroke()
            }
        }

        // Recognize text using Vision
        guard let cgImage = image.cgImage else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
            return nil
        }

        // Sort by reading order and extract text
        let sorted = observations.sorted { a, b in
            if abs(a.boundingBox.origin.y - b.boundingBox.origin.y) > 0.05 {
                return a.boundingBox.origin.y > b.boundingBox.origin.y
            }
            return a.boundingBox.origin.x < b.boundingBox.origin.x
        }

        let recognized = sorted
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        return recognized.isEmpty ? nil : recognized
    }
}
