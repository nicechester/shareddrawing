//
//  StrokeGestureRecognizer.swift
//  SharedDrawing
//
//  Created by Chester Kim on 5/10/17.
//  Copyright © 2017 Chester Kim. All rights reserved.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass

class StrokeGestureRecognizer: UIGestureRecognizer {
    var myView: MyView?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        myView?.drawingBegan(touches: touches, event: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        myView?.drawingMoved(touches: touches, event: event)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        myView?.drawingEnded(touches: touches, event: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        
    }

    override func reset() {
        
    }
}
