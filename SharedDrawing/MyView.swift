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
            self.currentLines = nil
//            self.initAllPaths()
            self.wireFB()
            self.setNeedsDisplay()
        }
    }
    var currentColor = "Blue"
    var currentLines: [[CGFloat]]?
    var currentPath = UIBezierPath()
    var incrImage: UIImage?
//    var allPaths: [String:UIBezierPath] = [:]
    var userCheck: (FIRDataSnapshot, String) -> Bool = MyView.alwaysReturnsTrue
    var fbHandles: [UInt] = [0, 0, 0]
    
    var ref: FIRDatabaseReference! {
        didSet {
            self.wireFB()
        }
    }

    private func wireFB() {
        fbHandles.forEach { h in
            if h != 0 {
                ref.removeObserver(withHandle: h)
            }
        }
        fbHandles[0] = ref.child(canvasID).child("paths").observe(.childAdded, with: changePaths)
        fbHandles[1] = ref.child(canvasID).child("paths").observe(.childChanged, with: changePaths)
        fbHandles[2] = ref.child(canvasID).child("paths").observe(.childRemoved, with: {_ in
            self.currentLines = nil
//            self.initAllPaths()
            self.setNeedsDisplay()
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
    
    func changePaths(snapshot: FIRDataSnapshot) {
        if let pathInfo = snapshot.value as? [String:Any], self.userCheck(snapshot, myID) {
            update(with: pathInfo)
        }
    }
    
//    func initAllPaths() {
//        let colors = ["Red", "Blue", "Orange", "Yellow"]
//        colors.forEach {
//            let path = UIBezierPath()
//            path.lineWidth = 3.0
//            allPaths[$0] = path
//        }
//        currentPath = UIBezierPath()
//        currentPath.lineWidth = 3.0
//        currentLines = []
//    }

    func update(with pathInfo: [String:Any]) {
        if let color = pathInfo["color"] as? String, let points = pathInfo["points"] as? [[CGFloat]], points.count>0 {
            let path=UIBezierPath()
            path.lineWidth = 3.0
            path.move(to: makeCGPoint(points[0]))
            points.forEach { path.addLine(to: makeCGPoint($0)) }
            self.drawBitmap(path: path, color: color)
//            self.allPaths[color]?.append(path)
        }
        self.setNeedsDisplay()
    }
    
    func makeCGPoint(_ point: [CGFloat]) -> CGPoint {
        return CGPoint(x: point[0], y: point[1])
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
        self.pathID = ref.child(canvasID).child("paths").childByAutoId().key
        self.ref.child(canvasID).child("paths").child(pathID).child("color").setValue(currentColor)
        self.ref.child(canvasID).child("paths").child(pathID).child("user").setValue(myID)
        if let cursor = touches.first?.location(in: self) {
            self.currentPath.move(to: cursor)
        }
        setNeedsDisplay()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        addLine(touches)
        setNeedsDisplay()
    }

    private func addLine(_ touches: Set<UITouch>) {
        if let cursor = touches.first?.location(in: self) {
            self.currentLines?.append([cursor.x, cursor.y])
            self.currentPath.addLine(to: cursor)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//        self.allPaths[self.currentColor]?.append(self.currentPath)
        self.drawBitmap(path: self.currentPath, color: self.currentColor)
        self.currentPath = UIBezierPath()
        self.currentPath.lineWidth = 3.0
        self.userCheck = MyView.isNotCurrentUser
        if let lines=currentLines {
            DispatchQueue.global(qos: .userInitiated).async {
                self.ref.child(self.canvasID).child("paths").child(self.pathID).child("points").setValue(lines)
                DispatchQueue.main.async {
                    self.currentLines = []
                }
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        
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
//        allPaths.forEach { pathByColor in
//            set(color: pathByColor.key)
//            pathByColor.value.stroke()
//        }
        set(color: self.currentColor)
        self.currentPath.stroke()
    }

    
    func clear() {
        currentLines = nil
        ref.child(canvasID).child("paths").removeValue()
//        initAllPaths()
    }

    func existCanvas(with canvasID: String) -> Bool {
        var doesExist = false
        self.ref.observeSingleEvent(of: .value, with: { snapshot in
            doesExist = snapshot.hasChild(canvasID)
        })
        return doesExist
    }

}
