//
//  TheTamaBase.h
//  TheTama
//
//  Created by masa on 2015/09/29.
//  Copyright © 2015年 Azukid. All rights reserved.
//

#ifndef TheTamaBase_h
#define TheTamaBase_h

/// Swift import.
#import "TheTama-Swift.h"


/// CocoaPods
#import "MRProgress.h"		// http://cocoadocs.org/docsets/MRProgress/0.2.2/


/// Azukid base.
#import "Azukid.h"



/// THETA Objects.
#import "PtpObject.h"

/// Manager's
#import "TheTaManager.h"


/// TabBarController's
#import "MainTabBarController.h"

/// ViewController's
#import "ConnectViewController.h"
#import "CaptureViewController.h"
#import "ListViewController.h"
#import "ViewerViewController.h"
#import "InfoViewController.h"



// TheTama Original Define.
#define LIST_CHUNK_FIRST	10		// ListViewTableでTHETAから１度に読み込む画像数
#define LIST_CHUNK_NEXT		15		// ListViewTableでTHETAから１度に読み込む画像数
#define PTP_TIMEOUT			3		//(second)



#include "TargetConditionals.h"
#if TARGET_IPHONE_SIMULATOR
// シミュレーター上でのみ実行される処理

#else
// 実機でのみ実行される処理

#endif



#endif /* TheTamaBase_h */
