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
    var canvasID = "1" {
        didSet {
            self.initCanvas()
            self.wireFB()
            self.setNeedsDisplay()
        }
    }
    var currentColor = "Blue"
    var currentLines: [[CGFloat]]? = []
    var currentPath = UIBezierPath()
    var incrImage: UIImage? = nil
    var userCheck: (FIRDataSnapshot, String) -> Bool = MyView.alwaysReturnsTrue
    var fbHandles: [UInt] = [0, 0, 0]
    var pts = [CGPoint](repeating: CGPoint(x: 0.0, y: 0.0), count:4)
    var ptsCount = 0
    var pathStack = Stack<String>()
    
    var ref: FIRDatabaseReference! {
        didSet {
            self.initCanvas()
            self.wireFB()
        }
    }
    
    func initCanvas() {
        currentLines = []
        incrImage = nil
        currentPath = UIBezierPath()
        currentPath.lineWidth = 3
    }
    
    private func wireFB() {
        fbHandles.forEach { h in
            if h != 0 {
                ref.removeObserver(withHandle: h)
            }
        }
        fbHandles[0] = ref.child(canvasID).child("paths").observe(.childAdded, with: changePath)
        fbHandles[1] = ref.child(canvasID).child("paths").observe(.childChanged, with: changePath)
        fbHandles[2] = ref.child(canvasID).child("paths").observe(.childRemoved, with: { snapshot in
            self.initCanvas()
            self.setNeedsDisplay()
            self.changeAllPaths()
        })
    }

    static func alwaysReturnsTrue(_ snapshot: FIRDataSnapshot, _ currentUserID: String) -> Bool {
        return true
    }

    static func isNotCurrentUser(_ snapshot: FIRDataSnapshot, _ currentUserID: String) -> Bool {
        if let pathInfo = snapshot.value as? [String:Any] {
            if let user = pathInfo["user"] as? String, currentUserID==user {
                return false
            }
        }
        return true
    }
    
    func changeAllPaths() {
        ref.child(canvasID).child("paths").observeSingleEvent(of: .value, with: { snapshot in
            if let paths = snapshot.value as? [String:[String:Any]] {
                paths.forEach{ (_, value) in
                    self.update(with: value)
                }
            }
        })
    }
    
    func changePath(snapshot: FIRDataSnapshot) {
        if let pathInfo = snapshot.value as? [String:Any], self.userCheck(snapshot, myID) {
            update(with: pathInfo)
        }
    }

    func update(with pathInfo: [String:Any]) {
        if let color = pathInfo["color"] as? String, let points = pathInfo["points"] as? [[CGFloat]], points.count>0 {
            let path=UIBezierPath()
            path.lineWidth = 3.0
            let p = CGPoint()
            var upoints = [makeCGPoint(points[0]), p, p, p]
            var ucnt = 0
            points.forEach {
                ucnt += 1
                upoints[ucnt] = makeCGPoint($0)
                if ucnt == 3 {
                    path.move(to: upoints[0])
                    path.addCurve(to: upoints[3], controlPoint1: upoints[1], controlPoint2: upoints[2])
                    upoints[0] = path.currentPoint
                    ucnt = 0
                }
            }
            self.drawBitmap(path: path, color: color)
        }
        self.setNeedsDisplay()
    }
    
    func makeCGPoint(_ point: [CGFloat]) -> CGPoint {
        return CGPoint(x: point[0], y: point[1])
    }
    
    func set(color colorString: String) {
        switch colorString {
        case "Black":
            UIColor.black.setStroke()
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

    func drawingBegan(touches: Set<UITouch>, event: UIEvent?) {
        self.pathID = ref.child(canvasID).child("paths").childByAutoId().key
        self.ref.child(canvasID).child("paths").child(pathID).child("color").setValue(currentColor)
        self.ref.child(canvasID).child("paths").child(pathID).child("user").setValue(myID)
        if let cursor = touches.first?.location(in: self) {
            pts[0] = cursor
            ptsCount = 0
        }
        self.currentPath.lineWidth = 3.0
    }
    

    func drawingMoved(touches: Set<UITouch>, event: UIEvent?) {
        addLine(touches)
        setNeedsDisplay()
    }

    private func addLine(_ touches: Set<UITouch>) {
        if let cursor = touches.first?.location(in: self) {
            self.currentLines?.append([cursor.x, cursor.y])
            ptsCount += 1
            pts[ptsCount] = cursor
            if ptsCount == 3 {
                currentPath.move(to: pts[0])
                currentPath.addCurve(to: pts[3], controlPoint1: pts[1], controlPoint2: pts[2])
                pts[0] = currentPath.currentPoint
                ptsCount = 0
            }

        }
    }
    

    func drawingEnded(touches: Set<UITouch>, event: UIEvent?) {
        self.drawBitmap(path: self.currentPath, color: self.currentColor)
        pts[0] = currentPath.currentPoint
        ptsCount = 0;
        currentPath = UIBezierPath()
        currentPath.lineWidth = 3.0
        self.userCheck = MyView.isNotCurrentUser
        if let lines=currentLines {
            DispatchQueue.global(qos: .userInitiated).async {
                self.ref.child(self.canvasID).child("paths").child(self.pathID).child("points").setValue(lines)
                DispatchQueue.main.async {
                    self.currentLines = []
                    self.pathStack.push(self.pathID)
                }
            }
        }
    }

    func drwingCanceled() {
        ptsCount = 0;
        currentPath = UIBezierPath()
        currentPath.lineWidth = 3.0
        currentLines = []
        setNeedsDisplay()
    }

    private func drawBitmap(path: UIBezierPath, color: String) {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, true, 0.0)
        set(color: color)
        if (incrImage == nil) {
            let rectPath = UIBezierPath(rect: self.bounds)
            UIColor.white.setFill()
            rectPath.fill()
        }
        incrImage?.draw(at: CGPoint.zero)
        path.stroke()
        incrImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
    
    override func draw(_ rect: CGRect) {
        incrImage?.draw(in: rect)
        set(color: self.currentColor)
        self.currentPath.stroke()
    }

    
    func clear() {
        currentLines = nil
        incrImage = nil
        ref.child(canvasID).child("paths").removeValue()
    }

    func existCanvas(with canvasID: String) -> Bool {
        var doesExist = false
        self.ref.observeSingleEvent(of: .value, with: { snapshot in
            doesExist = snapshot.hasChild(canvasID)
        })
        return doesExist
    }

    func undo() {
        if self.pathStack.isNotEmpty() {
            self.ref.child(self.canvasID).child("paths").child(self.pathStack.pop()).removeValue()
//            ref.child(canvasID).child("paths").observeSingleEvent(of: .value, with: { snapshot in
//                self.changePaths(snapshot: snapshot, noUserCheck: true)
//            })
        }
    }
}
