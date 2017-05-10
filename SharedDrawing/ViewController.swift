//
//  ViewController.swift
//  SharedDrawing
//
//  Created by Chester Kim on 9/15/16.
//  Copyright © 2016 Chester Kim. All rights reserved.
//

import UIKit
import Firebase

class ViewController: UIViewController, CanvasViewDelegate {
    private let letters = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".characters)
    private let len = 5
    private var modeButtonMap: [UIButton:MyView.DrawingImpl] = [:]
    
    @IBOutlet weak var brushButton: UIButton!
    @IBOutlet weak var moveButton: UIButton!
    @IBOutlet weak var myView: MyView!
    @IBOutlet weak var redButton: UIButton!
    @IBOutlet weak var blueButton: UIButton!
    @IBOutlet weak var orangeButton: UIButton!
    @IBOutlet weak var yellowButton: UIButton!
    @IBOutlet weak var blackButton: UIButton!
    private var colorButtons = [UIButton]()
    private var modeButtons = [UIButton]()

    override func viewDidLoad() {
        super.viewDidLoad()
        colorButtons = [blackButton, redButton, blueButton, orangeButton, yellowButton]
        modeButtons = [brushButton, moveButton]
        modeButtonMap = [brushButton:MyView.brush, moveButton:MyView.move]
        myView.ref = FIRDatabase.database().reference()
        myView.myID = UIDevice.current.identifierForVendor?.uuidString ?? "iPAD"
        myView.layer.borderColor = UIColor.black.cgColor
        myView.layer.borderWidth = 3.0
        self.title = myView.canvasID
        self.setColor(blackButton)
        self.setMode(brushButton)
        moveButton.imageView?.contentMode = .scaleAspectFit
        brushButton.imageView?.contentMode = .scaleAspectFit
    }
    
    @IBAction func clear(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Are you sure?", message: "You are about to delete whole drawing", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in self.myView.clear() }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    @IBAction func setColor(_ sender: UIButton) {
        myView.currentColor = sender.currentTitle!
        colorButtons.forEach { button in
            button.alpha = (button==sender) ? 1.0 : 0.5
            button.layer.borderColor = ((button==sender) ? UIColor.black : UIColor.clear).cgColor
        }
    }

    @IBAction func setMode(_ sender: UIButton) {
        modeButtons.forEach { button in
            button.layer.borderColor = ((button==sender) ? UIColor.brown : UIColor.clear).cgColor
        }
        colorButtons.forEach { button in
            button.isEnabled = (sender==brushButton)
        }
        myView.mode = modeButtonMap[sender] ?? MyView.brush
        myView.frame = CGRect(x: 0, y: 0, width: 1000, height: 1000)
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

//    private func updateMinZoomScaleForSize(size: CGSize) {
//        let widthScale = size.width / myView.bounds.width
//        let heightScale = size.height / myView.bounds.height
//        let minScale = min(widthScale, heightScale)
//        
//        scrollView.minimumZoomScale = minScale
//        scrollView.zoomScale = minScale
//    }
//
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        
//        updateMinZoomScaleForSize(size: view.bounds.size)
//    }
}
