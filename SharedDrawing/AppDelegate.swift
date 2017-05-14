//
//  AppDelegate.swift
//  SharedDrawing
//
//  Created by Chester Kim on 9/15/16.
//  Copyright © 2016 Chester Kim. All rights reserved.
//

import UIKit
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        FIRApp.configure()
        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        else {
            return false
        }
        let canvasID = components.queryItems?.filter({ (item) in item.name == "id" }).first?.value ?? "1"
        self.presentViewController(canvasID)
        return true
    }

    func presentViewController(_ canvasID: String) {
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        let canvasVC = storyboard.instantiateViewController(withIdentifier: "CanvasViewController")
            as! ViewController
        canvasVC.canvasID = canvasID
        
        let navigationVC = storyboard.instantiateViewController(withIdentifier: "NavigationController")
            as! UINavigationController
        navigationVC.modalPresentationStyle = .formSheet
        
        navigationVC.pushViewController(canvasVC, animated: true)
    }}

