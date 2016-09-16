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
    var pointIndex = 0
    var paths = [(points: [CGPoint], color: String)]()
    var ref: FIRDatabaseReference!
        {
        didSet {
            ref.observe(.childChanged, with: { snapshot in
                self.paths = [(points: [CGPoint], color: String)]()
                for eachPath in snapshot.children.allObjects as! [FIRDataSnapshot] {
                    if let pathInfo = eachPath.value as? [String:Any] {
                        if let color = pathInfo["color"] as? String, let points = pathInfo["points"] as? [String:Any] {
                            var cgPoints = [CGPoint]()
                            let keys = Array(points.keys).sorted(by: <)
                            for key in keys {
                                if let pointDic = points[key] as? [String:Float] {
                                    let x=pointDic["x"]!
                                    let y=pointDic["y"]!
                                    cgPoints.append((CGPoint(x: CGFloat(x), y: CGFloat(y))))
                                }
                            }
                            self.paths.append((points: cgPoints, color: color))
                        }
                    }
                }
                self.setNeedsDisplay()
            })
            ref.observe(.childRemoved, with: {_ in 
                self.paths.removeAll()
                self.setNeedsDisplay()
            })
        }
    }
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
//        setNeedsDisplay()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentPath?.append(getPoint(touches))
//        setNeedsDisplay()
    }
    
    private func getPoint(_ touches: Set<UITouch>) -> CGPoint {
        let point = touches.first?.location(in: self)
        if let rp = point {
            let coord = ["x":rp.x, "y":rp.y]
            ref.child("paths").child(key).child("points").child("\(pointIndex)").setValue(coord)
            pointIndex += 1
        }
        return point!
    }
 
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//        if let workingPath=currentPath {
//            paths.append((workingPath, currentColor))
//        }
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
//        paths.removeAll()
        currentPath = nil
        ref.child("paths").removeValue()
        pointIndex = 0

//        setNeedsDisplay()
    }
}
