//
//  DataObject.swift
//  TheTama
//
//  Created by masa on 2015/04/08.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

import UIKit

class DataObject: NSObject, NSCoding {
	
	//--------------------------非保存、初期化される
	// BOOL
//	var connected = false;
	var listBottom = true;		// true=ListView:最終行を表示する

	// Integer
//	var batteryLevel = 0

	// Object
//	var ptpConnection: PtpConnection
	var tamaObjects: NSMutableArray		// 全写真情報を保持
	var tamaCapture: PtpObject?			// 撮影直後または選択中の写真情報
	var tamaViewer: PtpObject?			// 3D-Viewerで表示する写真情報
	
	
	//--------------------------永続化　（同時に下にある、NSCoding protocolへも実装すること）
	// BOOL
	var captureTouchDown = false;
	var capturePreview = true;		//キャプチャ後プレビューする（false:転送に待たされない）
	var option1payed = false;		//１課金済み　特典パック
	var option2payed = false;		//２課金済み
	var option3payed = false;		//３課金済み
	
	// Integer
	var dataVersion = 1			// 読込時にチェックして構造変更に対応できるようにするため
	var volumeLevel = 100

	// Object


	
	override init() {
		// Initial
//		self.ptpConnection = PtpConnection()
		self.tamaObjects = NSMutableArray()
	}

	
	// MARK: - Implements NSCoding protocol
	func encodeWithCoder(aCoder: NSCoder) {
		
		// BOOL
		aCoder.encodeBool(self.captureTouchDown,	forKey: "captureTouchDown")
		aCoder.encodeBool(self.capturePreview,		forKey: "capturePreview")
		aCoder.encodeBool(self.option1payed,		forKey: "option1payed")
		aCoder.encodeBool(self.option2payed,		forKey: "option2payed")
		aCoder.encodeBool(self.option3payed,		forKey: "option3payed")
		
		// Integer
		aCoder.encodeInteger(self.dataVersion,		forKey: "dataVersion")
		aCoder.encodeInteger(self.volumeLevel,		forKey: "volumeLevel")
		
		// Object

	}
	
	required init(coder aDecoder: NSCoder) {
		// BOOL
		self.captureTouchDown	= aDecoder.decodeBoolForKey("captureTouchDown")
		self.capturePreview		= aDecoder.decodeBoolForKey("capturePreview")
		self.option1payed		= aDecoder.decodeBoolForKey("option1payed")
		self.option2payed		= aDecoder.decodeBoolForKey("option2payed")
		self.option3payed		= aDecoder.decodeBoolForKey("option3payed")
		
		// Integer
		self.dataVersion		= aDecoder.decodeIntegerForKey("dataVersion")
		self.volumeLevel		= aDecoder.decodeIntegerForKey("volumeLevel")
		
		// Object
//		self.ptpConnection		= PtpConnection()	//非保存、初期化
		self.tamaObjects		= NSMutableArray()	//非保存、初期化
	}

}
