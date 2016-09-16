//
//  WhiteboardView.swift
//  SharedDrawing
//
//  Created by Chester Kim on 9/15/16.
//  Copyright © 2016 Chester Kim. All rights reserved.
//

import UIKit
import Firebase

class MyView: UIView {
    var currentColor = "Blue"
    var currentPath: [CGPoint]?
    var paths = [(points: [CGPoint], color: String)]()
    var ref: FIRDatabaseReference!
//        {
//        didSet {
//            ref.observe(.childAdded, with: { snapshot in
//                if let paths = snapshot.value(forKey: "paths") as? [Any] {
//                    paths.forEach { path in
//                        if let points = path
//                    }
//                }
//            })
//        }
//    }
    var key = "-1"

    func set(color colorString: String) {
        switch colorString {
        case "Red":
            UIColor.red.setStroke()
        case "Blue":
            UIColor.blue.setStroke()
        case "Orange":
            UIColor.orange.setStroke()
        case "Yellow":
            UIColor.yellow.setStroke()
        default:
            UIColor.black.setStroke()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        key = "path-\(ref.child("path").childByAutoId().key)"
        ref.child("paths").child(key).child("color").setValue(currentColor)
        currentPath = [getPoint(touches)]
        setNeedsDisplay()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentPath?.append(getPoint(touches))
        setNeedsDisplay()
    }
    
    private func getPoint(_ touches: Set<UITouch>) -> CGPoint {
        let point = touches.first?.location(in: self)
        if let rp = point {
            let coord = ["x":rp.x, "y":rp.y]
            ref.child("paths").child(key).child("points").childByAutoId().setValue(coord)
        }
        return point!
    }
 
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let workingPath=currentPath {
            paths.append((workingPath, currentColor))
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        
    }
    
    override func draw(_ rect: CGRect) {
        paths.forEach{ pathData in
            drawLine(points: pathData.points, color: pathData.color)
        }
        if let workingPath = currentPath {
            drawLine(points: workingPath, color: currentColor)
        }
    }
    
    func drawLine(points: [CGPoint], color colorString: String) {
        let path = UIBezierPath()
        path.move(to: points[0])
        path.lineWidth = 5.0
        points[1..<points.count].forEach { p in
            path.addLine(to: p)
        }
        set(color: colorString)
        path.stroke()
    }
    
    func clear() {
        paths.removeAll()
        currentPath = nil
        ref.child("paths").removeValue()
        setNeedsDisplay()
    }
}
