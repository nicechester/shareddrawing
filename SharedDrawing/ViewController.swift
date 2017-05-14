//
//  ViewController.swift
//  SharedDrawing
//
//  Created by Chester Kim on 9/15/16.
//  Copyright © 2016 Chester Kim. All rights reserved.
//

import UIKit
import Firebase

class ViewController: UIViewController, CanvasViewDelegate, UIGestureRecognizerDelegate {
    private let letters = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".characters)
    private let len = 5
    var canvasID: String? = nil
    
    @IBOutlet weak var myView: MyView!
    @IBOutlet weak var redButton: UIButton!
    @IBOutlet weak var blueButton: UIButton!
    @IBOutlet weak var orangeButton: UIButton!
    @IBOutlet weak var yellowButton: UIButton!
    @IBOutlet weak var blackButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    
    private var colorButtons = [UIButton]()
    var fingerStrokeRecognizer: StrokeGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        colorButtons = [blackButton, redButton, blueButton, orangeButton, yellowButton]
        myView.ref = FIRDatabase.database().reference()
        myView.myID = UIDevice.current.identifierForVendor?.uuidString ?? "iPAD"
        myView.layer.borderColor = UIColor.black.cgColor
        myView.layer.borderWidth = 3.0
        if let cid = self.canvasID {
            myView.canvasID = cid
        }
        self.title = myView.canvasID
        self.setColor(blackButton)
        scrollView.maximumZoomScale = 3.0
        scrollView.minimumZoomScale = 0.5
        scrollView.pinchGestureRecognizer?.allowedTouchTypes = [UITouchType.direct.rawValue as NSNumber]
        scrollView.panGestureRecognizer.allowedTouchTypes = [UITouchType.direct.rawValue as NSNumber]
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        scrollView.delegate = self
        let fingerStrokeRecognizer = StrokeGestureRecognizer(target: self, action: nil)
        fingerStrokeRecognizer.delegate = self
        fingerStrokeRecognizer.cancelsTouchesInView = false
        fingerStrokeRecognizer.myView = myView
        scrollView.addGestureRecognizer(fingerStrokeRecognizer)
        self.fingerStrokeRecognizer = fingerStrokeRecognizer
        

    }
    
    @IBAction func clear(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Are you sure?", message: "You are about to delete whole drawing", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in self.myView.clear() }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    @IBAction func undo(_ sender: UIBarButtonItem) {
        myView.undo()
    }

    @IBAction func setColor(_ sender: UIButton) {
        myView.currentColor = sender.currentTitle!
        colorButtons.forEach { button in
//            button.alpha = (button==sender) ? 1.0 : 0.5
            button.layer.borderColor = ((button==sender) ? UIColor.black : UIColor.clear).cgColor
            let image = (button==sender) ? UIImage(named: "paintbrush.png") : nil
            button.setImage(image, for: .normal)
        }
    }
    
    func setCanvas(id: String) {
        var canvasID = id
        if canvasID == "" {
            repeat {
                canvasID = newCanvasID()
            } while myView.existCanvas(with: canvasID)
        }
        myView.frame = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        myView.canvasID = canvasID

        self.title = canvasID
    }
    
    private func newCanvasID() -> String {
        var randomString = ""
        for _ in 0..<len {
            let rand = Int(arc4random_uniform(UInt32(letters.count)))
            randomString.append(letters[rand])
        }
        return randomString
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let canvasIDPopOver = segue.destination as? OpenCanvasIDPopoverViewController {
            canvasIDPopOver.canvasViewDelegate = self
        }
    }
}

extension ViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return myView
    }
}
