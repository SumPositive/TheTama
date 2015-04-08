//
//  DataObject.swift
//  TheTama
//
//  Created by masa on 2015/04/08.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

import UIKit

class DataObject: NSObject {
	
	var ptpConnection: PtpConnection?
	var storageInfo: PtpIpStorageInfo?
	var deviceInfo: PtpIpDeviceInfo?

	var tamaObjects: NSMutableArray?
	var batteryLevel:UInt = 0
	var volumeLevel = 100
	
	var captureTouchDown = false;
	
	override init() {

	}

}
