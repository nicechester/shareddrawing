//
//  ViewController.swift
//  SharedDrawing
//
//  Created by Chester Kim on 9/15/16.
//  Copyright © 2016 Chester Kim. All rights reserved.
//

import UIKit
import Firebase

class ViewController: UIViewController {
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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func clear(_ sender: UIBarButtonItem) {
        myView.clear()
    }

    @IBAction func setColor(_ sender: UIButton) {
        myView.currentColor = sender.currentTitle!
        colorButtons.forEach { button in
            button.isSelected = button==sender
        }
    }
}

