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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        myView.ref = FIRDatabase.database().reference()
        myView.myID = UIDevice.current.identifierForVendor?.uuidString ?? "iPAD"
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
    }
}

