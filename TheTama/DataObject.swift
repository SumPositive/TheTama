//
//  DataObject.swift
//  TheTama
//
//  Created by masa on 2015/04/08.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

import UIKit

class DataObject: NSObject, NSCoding {
	
	// BOOL
	var captureTouchDown = false;
	
	// Integer
	var dataVersion = 1			// 読込時にチェックして構造変更に対応できるようにするため
	var batteryLevel = 0
	var volumeLevel = 100
	
	// Object
	var ptpConnection: PtpConnection
	var tamaObjects: NSMutableArray		// 全写真情報を保持
	var tamaCapture: PtpObject?			// 撮影直後または選択中の写真情報
	var tamaViewer: PtpObject?			// 3D-Viewerで表示する写真情報
	
	
	override init() {
		// Initial
		self.ptpConnection = PtpConnection()
		self.tamaObjects = NSMutableArray()
	}

	
	// MARK: - Implements NSCoding protocol
	func encodeWithCoder(aCoder: NSCoder) {
		
		// BOOL
		aCoder.encodeBool(self.captureTouchDown,	forKey: "captureTouchDown")
		
		// Integer
		aCoder.encodeInteger(self.dataVersion,		forKey: "dataVersion")
		aCoder.encodeInteger(self.batteryLevel,		forKey: "batteryLevel")
		aCoder.encodeInteger(self.volumeLevel,		forKey: "volumeLevel")
		
		// Object
		//aCoder.encodeObject(self.ptpConnection,		forKey:"ptpConnection")
		//aCoder.encodeObject(self.tamaObjects,		forKey:"tamaObjects")
		//aCoder.encodeObject(self.tamaCapture,		forKey:"tamaCapture")
	}
	
	required init(coder aDecoder: NSCoder) {
		// BOOL
		self.captureTouchDown	= aDecoder.decodeBoolForKey("captureTouchDown")
		
		// Integer
		self.dataVersion		= aDecoder.decodeIntegerForKey("dataVersion")
		self.batteryLevel		= aDecoder.decodeIntegerForKey("batteryLevel")
		self.volumeLevel		= aDecoder.decodeIntegerForKey("volumeLevel")
		
		// Object
		self.ptpConnection		= PtpConnection()  // 毎回クリア
		self.tamaObjects		= NSMutableArray()
		//self.tamaObjects		= aDecoder.decodeObjectForKey("tamaObjects") as! NSMutableArray
		//self.tamaCapture			= aDecoder.decodeObjectForKey("tamaCapture") as? PtpObject
	}

}
