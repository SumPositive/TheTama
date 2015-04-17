//
//  InterfaceController.swift
//  TheTama WatchKit Extension
//
//  Created by masa on 2015/04/16.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

import WatchKit
import Foundation


class InterfaceController: WKInterfaceController {

	var count = 0
	@IBOutlet weak var button: WKInterfaceButton!
	@IBOutlet weak var label: WKInterfaceLabel!

	
	override func awakeWithContext(context: AnyObject?) {
		super.awakeWithContext(context)
		
		// Configure interface objects here.
		NSLog("%@ %@", self, __FUNCTION__)
	}
	
	override func willActivate() {
		// This method is called when watch view controller is about to be visible to user
		super.willActivate()
		NSLog("%@ will activate", self)
		NSLog("%@ %@", self, __FUNCTION__)

		// Disconnect
		button.setEnabled(false)
		label.setHidden(false)

		//Send count to parent application
		let userInfo = ["command" : "isConnect"]
		WKInterfaceController.openParentApplication(userInfo) { (reply, error) -> Void in
			if reply != nil {
				NSLog("reply=%@", reply["result"] as! Bool)
				if reply["result"] as! Bool {
					// Connect
					self.button.setEnabled(true)
					self.label.setHidden(true)
				}
			}
		}
	}
	
	override func didDeactivate() {
		// This method is called when watch view controller is no longer visible
		NSLog("%@ did deactivate", self)
		
		super.didDeactivate()
	}
	
	@IBAction func buttonTouchUp() {
		// Waiting.
		self.button.setEnabled(false)
		self.label.setHidden(false)

		//Send count to parent application
		let userInfo = ["command" : "capture"]
		WKInterfaceController.openParentApplication(userInfo) { (reply, error) -> Void in
			if reply != nil {
				NSLog("reply=%@", reply["result"] as! Bool)
				if reply["result"] as! Bool {
					// OK
					
					// Thumbnail
					if let thumb = reply["thumbnail"] as? UIImage {
						
					}
					
					
				}
			}
			self.button.setEnabled(true)
			self.label.setHidden(true)
		}
	}
	
	@IBAction func sendCounter() {
		//Send count to parent application
		println("Watch \(self.count)")
		WKInterfaceController.openParentApplication(["countValue": "\(self.count)"],
			reply: {replyInfo, error in
				println(replyInfo["fromApp"])
		})
	}
}
