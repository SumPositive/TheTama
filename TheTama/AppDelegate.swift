//
//  AppDelegate.swift
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

import UIKit
import WatchKit


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?
	var dataObject: DataObject?
	var captureObject: Capture?
	
	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		// Override point for customization after application launch.
		// 初起動したとき
		
		// mData 復帰
		let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as! Array<String>
		let filePath = paths[0].stringByAppendingPathComponent("mData.TheTama")
		dataObject = NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? DataObject
		if dataObject == nil {
			println("ERROR! mData load");
		}
		
		// option1payed
		if dataObject?.option1payed == false {
			let ud = NSUserDefaults.standardUserDefaults()
			dataObject?.option1payed = ud.boolForKey("option1payed")
		}
		
		return true
	}
	
	func applicationWillResignActive(application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
		// バックグランドになるとき
		NSNotificationCenter.defaultCenter().postNotificationName("applicationDidEnterBackground", object: nil)
		// mData 保存
		if dataObject != nil {
			//パスの取得
			let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as! Array<String>
			//保存するファイルの名前
			let filePath = paths[0].stringByAppendingPathComponent("mData.TheTama")
			//アーカイブして保存する
			let successful = NSKeyedArchiver.archiveRootObject(dataObject!, toFile: filePath)
			if !successful {
				println("ERROR! mData save");
			}
		}
	}

	func applicationWillEnterForeground(application: UIApplication) {
		// バックグランドから復帰するとき
		NSNotificationCenter.defaultCenter().postNotificationName("applicationWillEnterForeground", object: nil)
	}

	func applicationDidBecomeActive(application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}
	
	
	// MARK: - Shared Object

	func getDataObject() -> DataObject? {
		if dataObject == nil {
			dataObject = DataObject()
		}
		return dataObject
	}

	func getCaptureObject() -> Capture? {
		if captureObject == nil {
			captureObject = Capture()
		}
		return captureObject
	}


	// MARK: - WatchKit I/O

	func application(application: UIApplication,
		handleWatchKitExtensionRequest userInfo: [NSObject : AnyObject]?,
		reply: (([NSObject : AnyObject]!) -> Void)!) {

			if let command:String = userInfo?["command"] as? String {
				println("command=" + command)
				switch command {
				case "isConnect":	// THETA Wi-Fi接続状態
					#if arch(i386) || arch(x86_64)
						// シミュレータ
						reply(["result":true])
					#else
						// 実機
						if (captureObject != nil && captureObject?.connected==true) {
							reply(["result":true])
						} else {
							reply(["result":false])
						}
					#endif
					return

				case "capture":		// キャプチャ実行、サムネイルを送る
					#if arch(i386) || arch(x86_64)
						// シミュレータ
						let image:UIImage? = UIImage(named:"Tama2.svg")
					#else
						// 実機
						
						
						
						let image:UIImage? = dataObject!.tamaCapture!.thumbnail
					#endif
					let thum:NSData? = UIImagePNGRepresentation(image)
					reply(["result":true, "thumbData":thum!])
					return
					
				default:
					break
				}
			}
			reply([:])
	}

}




