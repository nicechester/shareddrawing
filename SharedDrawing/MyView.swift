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
    var myID = "Chester's iPAD"
    var pathID = "-1"
    var currentColor = "Blue"
    var currentLines: [CGPoint]?
    var currentPath = UIBezierPath()
    var allPaths: [String:UIBezierPath] = [:]
    var pointIndex = 0
    var paths = [(points: [CGPoint], color: String)]()
    var ref: FIRDatabaseReference! {
        didSet {
            ref.child("paths").observeSingleEvent(of: .value, with: initPaths)
            ref.child("paths").observe(.childAdded, with: changePaths)
            ref.child("paths").observe(.childChanged, with: changePaths)
            ref.child("paths").observe(.childRemoved, with: {_ in
                self.paths = []
                self.currentLines = nil
                self.setNeedsDisplay()
            })
        }
    }

    func isNotCurrentUser(_ snapshot: FIRDataSnapshot) -> Bool {
        if let pathInfo = snapshot.value as? [String:Any] {
            if let user = pathInfo["user"] as? String, myID==user {
                return false
            }
        }
        return true
    }
    
    func initPaths(snapshot: FIRDataSnapshot) {
        if let pathInfo = snapshot.value as? [String:Any] {
            update(with: pathInfo)
        }
    }

    func changePaths(snapshot: FIRDataSnapshot) {
        if let pathInfo = snapshot.value as? [String:Any], self.isNotCurrentUser(snapshot) {
            update(with: pathInfo)
        }
    }
    
    func initAllPaths() {
        let colors = ["Red", "Blue", "Orange", "Yellow"]
        colors.forEach {
            let path = UIBezierPath()
            path.lineWidth = 3.0
            allPaths[$0] = path
        }
        currentPath = UIBezierPath()
        currentPath.lineWidth = 3.0
    }

    func update(with pathInfo: [String:Any]) {
        if let color = pathInfo["color"] as? String {
            var cgPoints: [CGPoint]?
            if let mapPoints = pathInfo["points"] as? [String: [String: CGFloat]] {
                cgPoints = makeCGPoints(with: mapPoints)
            } else if let points = pathInfo["points"] as? [[String: CGFloat]] {
                cgPoints = makeCGPoints(with: points)
            }
            if let realCGPoints = cgPoints {
                self.paths.append((points: realCGPoints, color: color))
            }
        }
        self.setNeedsDisplay()
    }
    
    func makeCGPoints(with points: [String: [String: CGFloat]]) -> [CGPoint] {
        var cgPoints = [CGPoint]()
        let keys = Array(points.keys).sorted(by: <)
        keys.forEach { key in
            if let p = points[key] {
                cgPoints.append(CGPoint(x: p["x"]!, y: p["y"]!))
            }
        }
        return cgPoints
    }
    
    func makeCGPoints(with points: [[String: CGFloat]]) -> [CGPoint] {
        var cgPoints = [CGPoint]()
        points.forEach { p in cgPoints.append(CGPoint(x: p["x"]!, y: p["y"]!)) }
        return cgPoints
    }
    
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
        self.pathID = ref.child("path").childByAutoId().key
        self.ref.child("paths").child(pathID).child("color").setValue(currentColor)
        self.ref.child("paths").child(pathID).child("user").setValue(myID)
        self.currentLines = []
        let cursor = getPoint(touches)
        self.currentLines?.append(cursor)
        self.currentPath.move(to: cursor)
        setNeedsDisplay()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        setNeedsDisplay()
        addLine(touches)
    }
    
    private func getPoint(_ touches: Set<UITouch>) -> CGPoint {
        let point = touches.first?.location(in: self)
        if let rp = point {
            DispatchQueue.global(qos: .userInitiated).async {
                let coord = ["x":rp.x, "y":rp.y]
                self.ref.child("paths").child(self.pathID).child("points").child("\(self.pointIndex)").setValue(coord)
                DispatchQueue.main.async {
                    self.pointIndex += 1
                }
            }
        }
        return point!
    }
    
    private func addLine(_ touches: Set<UITouch>) {
        let cursor = getPoint(touches)
        self.currentLines?.append(cursor)
        self.currentPath.addLine(to: cursor)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        addLine(touches)
        self.allPaths[self.currentColor]?.append(self.currentPath)
        self.currentPath = UIBezierPath()
        self.currentPath.lineWidth = 3.0

        if let workingPath=currentLines {
            paths.append((workingPath, currentColor))
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        
    }
    
    override func draw(_ rect: CGRect) {
        allPaths.forEach {
            set(color: $0.key)
            $0.value.stroke()
        }
        set(color: self.currentColor)
        self.currentPath.stroke()

//        paths.forEach{ pathData in
//            drawLine(points: pathData.points, color: pathData.color)
//        }
//        if let workingPath = currentLines {
//            drawLine(points: workingPath, color: currentColor)
//        }
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
        currentLines = nil
        ref.child("paths").removeValue()
        pointIndex = 0
        initAllPaths()
    }
}
