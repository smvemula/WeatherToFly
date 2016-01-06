//
//  UIAlertViewExtension.swift
//  PlayNFLBetting
//
//  Created by Vemula, Manoj (Contractor) on 4/10/15.
//  Copyright (c) 2015 Vemula, Manoj (Contractor). All rights reserved.
//

import Foundation
import UIKit

extension UIAlertController {
    class func showAlertViewNetworkIssues(vc: UIViewController) {
        self.showAlertView(NSLocalizedString("Error !!", comment: "Error !!"), text: NSLocalizedString("Network error.", comment: "Network error."), actionButtonBlock: nil, vc: vc)
    }
    
    class func showWorkInProgress(vc: UIViewController) {
        self.showAlertView("!!!Work in Progress!!!", text: "STAY TUNED!", actionButtonBlock: nil, vc: vc)
    }
    
    class func showAlertView(title: String, text: String, actionButtonBlock: (() -> ())?, vc: UIViewController) {
        if UIApplication.sharedApplication().applicationState == UIApplicationState.Active {
            let alert = UIAlertController(title: title, message: text, preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Cancel, handler: { action in
                if let exists = actionButtonBlock {
                    exists()
                }
            }))
            vc.presentViewController(alert, animated: true, completion: nil)
        } else {
            print("\(title) : \(text)")
        }
    }
    
    class func showAlertView(title: String, message: String, cancelButtonTitle: String, actionButtonTitle: String, actionButtonBlock: () -> (), vc: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: actionButtonTitle, style: UIAlertActionStyle.Default, handler: { action in
            actionButtonBlock()
        }))
        alert.addAction(UIAlertAction(title: cancelButtonTitle, style: UIAlertActionStyle.Cancel, handler: { action in
        }))
        vc.presentViewController(alert, animated: true, completion: nil)
    }
}
