//
//  OpenCanvasIDPopoverViewController.swift
//  SharedDrawing
//
//  Created by Chester Kim on 9/25/16.
//  Copyright © 2016 Chester Kim. All rights reserved.
//

import UIKit

protocol CanvasViewDelegate {
    func setCanvas(id: String)
}

class OpenCanvasIDPopoverViewController: UIViewController {
    var canvasViewDelegate: CanvasViewDelegate?
    @IBOutlet weak var canvasIDText: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func okTapped(_ sender: UIButton) {
        canvasViewDelegate?.setCanvas(id: canvasIDText.text!)
        self.dismiss(animated: true, completion: nil)
    }
}
