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
    
    @IBOutlet weak var myView: MyView!
    @IBOutlet weak var redButton: UIButton!
    @IBOutlet weak var blueButton: UIButton!
    @IBOutlet weak var orangeButton: UIButton!
    @IBOutlet weak var yellowButton: UIButton!
    var colorButtons = [UIButton]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        colorButtons = [redButton, blueButton, orangeButton, yellowButton]
        myView.ref = FIRDatabase.database().reference()
        myView.myID = UIDevice.current.identifierForVendor?.uuidString ?? "iPAD"
        myView.initAllPaths()
        self.title = myView.canvasID
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
            button.isSelected = button==sender
        }
    }

    func setCanvas(id: String) {
        var canvasID = id
        if canvasID == "" {
            repeat {
                canvasID = newCanvasID()
            } while myView.existCanvas(with: canvasID)
        }
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

