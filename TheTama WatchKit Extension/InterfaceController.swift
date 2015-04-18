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

	@IBOutlet weak var button: WKInterfaceButton!
	//@IBOutlet weak var label: WKInterfaceLabel!

	var mButtonCapture:Bool = true
	
	
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
		self.buttonDisable()
		//self.label.setHidden(false)

		//Send count to parent application
		let userInfo = ["command" : "isConnect"]
		WKInterfaceController.openParentApplication(userInfo) { (reply, error) -> Void in
			if reply != nil {
				NSLog("reply=%@", reply["result"] as! Bool)
				if reply["result"] as! Bool {
					// Connect
					self.buttonEnable(nil)
					//self.label.setHidden(true)
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
		self.buttonDisable()
		
		if mButtonCapture {
			// Capture Mode
			//Send count to parent application
			let userInfo = ["command" : "capture"]
			WKInterfaceController.openParentApplication(userInfo) { (reply, error) -> Void in
				if reply != nil {
					NSLog("reply=%@", reply["result"] as! Bool)
					if reply["result"] as! Bool {
						// Thumbnail
						if let thumbData = reply["thumbnail"] as? NSData {
							self.buttonEnable(thumbData) // To Thumbnail Mode
						}
					}
				}
			}
		} else {
			// Thumbnail Mode
			self.buttonEnable(nil) // To Capture Mode
		}
	}

	
	func buttonDisable() {
		self.button.setBackgroundImageNamed("TheTama-Tran-Capture.svg")
		self.button.setEnabled(false)
		//self.label.setHidden(false)
	}

	func buttonEnable(imageData: NSData?) {
		if imageData != nil {
			self.button.setBackgroundImageData(imageData)
			mButtonCapture = false
		} else {
			self.button.setBackgroundImageNamed("TheTama-Tran-BASA.svg")
			mButtonCapture = true
		}
		self.button.setEnabled(true)
	}
}




