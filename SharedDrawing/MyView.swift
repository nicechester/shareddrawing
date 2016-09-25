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
    var currentLines: [[CGFloat]]?
    var currentPath = UIBezierPath()
    var allPaths: [String:UIBezierPath] = [:]
    var ref: FIRDatabaseReference! {
        didSet {
            ref.child("paths").observeSingleEvent(of: .value, with: initPaths)
            ref.child("paths").observe(.childAdded, with: changePaths)
            ref.child("paths").observe(.childChanged, with: changePaths)
            ref.child("paths").observe(.childRemoved, with: {_ in
                self.currentLines = nil
                self.initAllPaths()
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
        currentLines = []
    }

    func update(with pathInfo: [String:Any]) {
        if let color = pathInfo["color"] as? String, let points = pathInfo["points"] as? [[CGFloat]], points.count>0 {
            let path=UIBezierPath()
            path.move(to: makeCGPoint(with: points[0]))
            points.forEach { path.addLine(to: makeCGPoint(with: $0)) }
            self.allPaths[color]?.append(path)
        }
        self.setNeedsDisplay()
    }
    
    func makeCGPoint(with point: [CGFloat]) -> CGPoint {
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
        self.pathID = ref.child("path").childByAutoId().key
        self.ref.child("paths").child(pathID).child("color").setValue(currentColor)
        self.ref.child("paths").child(pathID).child("user").setValue(myID)
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
        self.allPaths[self.currentColor]?.append(self.currentPath)
        self.currentPath = UIBezierPath()
        self.currentPath.lineWidth = 3.0

        if let lines=currentLines {
            DispatchQueue.global(qos: .userInitiated).async {
                self.ref.child("paths").child(self.pathID).child("points").setValue(lines)
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        
    }
    
    override func draw(_ rect: CGRect) {
        allPaths.forEach { pathByColor in
            set(color: pathByColor.key)
            pathByColor.value.stroke()
        }
        set(color: self.currentColor)
        self.currentPath.stroke()
    }
    
    func clear() {
        currentLines = nil
        ref.child("paths").removeValue()
        initAllPaths()
    }
}
