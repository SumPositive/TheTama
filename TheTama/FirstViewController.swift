//
//  FirstViewController.swift
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

import UIKit


class FirstViewController: UIViewController {
	
	@IBOutlet weak var iboConnect: UIButton!

	// UIメインスレッド
	func dispatch_async_main(block: () -> ()) {
		dispatch_async(dispatch_get_main_queue(), block)
	}
	
	// バックグランド
	func dispatch_async_global(block: () -> ()) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block)
	}
	
	var _ptpConnection: PtpConnection
	var _objects: NSMutableArray
//	var _storageInfo: PtpIpStorageInfo
//	var _batteryLevel: NSUInteger
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


	@IBAction func iboConnectButton(sender: AnyObject) {
		
	}

	
	func ptpip_eventRecived( code:Int16, param1:UInt32, param2:UInt32, param3:UInt32) {
		// PTP/IP-Event callback.
		switch code {
			case PTPIP_OBJECT_ADDED:
				// It will be receive when the camera has taken a new photo.
			 dispatch_async_main {
				NSLog(@"Object added Event(0x%04x) - 0x%08x", code, param1)
			}
			
			_ptpConnection.operateSession(session:PtpIpSession) {
				_objects.addObject(self.loadObject(param1, session))
				
				NSIndexPath* pos = NSIndexPath.indexpathForRow    [NSIndexPath indexPathForRow:_objects.count-1 inSection:1];
				dispatch_async_main(^{
					[_contentsView beginUpdates];
					[_contentsView insertRowsAtIndexPaths:@[pos]
					withRowAnimation:UITableViewRowAnimationRight];
					[_contentsView endUpdates];
					});
			}
				
				[_ptpConnection operateSession:^(PtpIpSession *session) {
					[_objects addObject:[self loadObject:param1 session:session]];
					NSIndexPath* pos = [NSIndexPath indexPathForRow:_objects.count-1 inSection:1];
					dispatch_async_main(^{
					[_contentsView beginUpdates];
					[_contentsView insertRowsAtIndexPaths:@[pos]
					withRowAnimation:UITableViewRowAnimationRight];
					[_contentsView endUpdates];
					});
					}];

			default:
			 dispatch_async_main {
				NSLog(@"Event(0x%04x) received", code)
			}
		}
		
	}
}

