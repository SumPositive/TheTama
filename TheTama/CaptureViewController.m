//
//  CaptureViewController.m
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
//#import "SVProgressHUD.h"
//#import "BDToastAlert.h"
#import "MRProgress.h"		// http://cocoadocs.org/docsets/MRProgress/0.2.2/

#import "Azukid.h"
#import "TheTama-Swift.h"

#import "CaptureViewController.h"
#import "PtpConnection.h"
#import "PtpLogging.h"
#import "PtpObject.h"



inline static void dispatch_async_main(dispatch_block_t block)
{
	dispatch_async(dispatch_get_main_queue(), block);
}

@interface CaptureViewController () <PtpIpEventListener>
{
	DataObject * mData;
	
	NSUInteger		mShutterSpeed;
	NSInteger		mFilmIso;
	NSInteger		mWhiteBalance;
	CAPTURE_MODE	mCaptureMode;
}

@property (nonatomic, strong) IBOutlet UISegmentedControl * sgShutter1;
@property (nonatomic, strong) IBOutlet UISegmentedControl * sgShutter2;
@property (nonatomic, strong) IBOutlet UISegmentedControl * sgIso;
@property (nonatomic, strong) IBOutlet UISegmentedControl * sgWhite1;
@property (nonatomic, strong) IBOutlet UISegmentedControl * sgWhite2;

@property (nonatomic, strong) IBOutlet UILabel * batteryLabel;
@property (nonatomic, strong) IBOutlet UIProgressView * batteryProgress;
@property (nonatomic, strong) IBOutlet UILabel  * volumeLabel;
@property (nonatomic, strong) IBOutlet UISlider * volumeSlider;
@property (nonatomic, strong) IBOutlet UIImageView * ivThumbnail;
@property (nonatomic, strong) IBOutlet UIButton * captureButton;

@end


@implementation CaptureViewController



#pragma mark - PtpIpEventListener delegates.

-(void)ptpip_eventReceived:(int)code :(uint32_t)param1 :(uint32_t)param2 :(uint32_t)param3
{
	LOG_FUNC
	// PTP/IP-Event callback.
	// This method is running at PtpConnection#gcd thread.
	switch (code) {
		default:
			LOG(@"Event(0x%04x) received", code);
			break;
			
//		case PTPIP_CAPTURE_COMPLETE:
//		{	// 撮影が完了した際に呼び出される
//			dispatch_async_main(^{
//				[self progressOff];
//			});
//		} break;
		
		case PTPIP_OBJECT_ADDED:
		{	// 撮影などを行った際にオブジェクトが作成された際に呼び出される
			LOG(@"Object added Event(0x%04x) - 0x%08x", code, param1);
			[mData.ptpConnection operateSession:^(PtpIpSession *session) {
				// サムネイル表示
				UIImage * thumb = [self imageThumbnail:param1 session:session];
				dispatch_async_main(^{
					self.ivThumbnail.image = thumb;
					// Get Battery level.
					mData.batteryLevel = [session getBatteryLevel];
					[self viewRefresh];
				});
			}];
		} break;
			
		case PTPIP_STORE_FULL:
		{	// ストレージFULL
			
		} break;
	}
	
	dispatch_async_main(^{
		self.captureButton.enabled = YES;
		[self progressOff];
	});
}

-(void)ptpip_socketError:(int)err
{
	// socket error callback.
	// This method is running at PtpConnection#gcd thread.
	
	// If libptpip closed the socket, `closed` is non-zero.
	BOOL closed = PTP_CONNECTION_CLOSED(err);
	
	// PTPIP_PROTOCOL_*** or POSIX error number (errno()).
	err = PTP_ORIGINAL_PTPIPERROR(err);
	
	NSArray* errTexts = @[@"Socket closed",              // PTPIP_PROTOCOL_SOCKET_CLOSED
						  @"Brocken packet",             // PTPIP_PROTOCOL_BROCKEN_PACKET
						  @"Rejected",                   // PTPIP_PROTOCOL_REJECTED
						  @"Invalid session id",         // PTPIP_PROTOCOL_INVALID_SESSION_ID
						  @"Invalid transaction id.",    // PTPIP_PROTOCOL_INVALID_TRANSACTION_ID
						  @"Unrecognided command",       // PTPIP_PROTOCOL_UNRECOGNIZED_COMMAND
						  @"Invalid receive state",      // PTPIP_PROTOCOL_INVALID_RECEIVE_STATE
						  @"Invalid data length",        // PTPIP_PROTOCOL_INVALID_DATA_LENGTH
						  @"Watchdog expired",           // PTPIP_PROTOCOL_WATCHDOG_EXPIRED
						  ];
	NSString* desc;
	if ((PTPIP_PROTOCOL_SOCKET_CLOSED<=err) && (err<=PTPIP_PROTOCOL_WATCHDOG_EXPIRED)) {
		desc = [errTexts objectAtIndex:err-PTPIP_PROTOCOL_SOCKET_CLOSED];
	} else {
		desc = [NSString stringWithUTF8String:strerror(err)];
	}
	
	LOG(@"socket error(0x%X,closed=%@).\n--- %@", err, closed? @"YES": @"NO", desc);
	//if (closed) {
		[mData.ptpConnection setEventListener:nil];
		
		dispatch_async_main(^{
			//[self disconnect];
			[self progressOff];
			// Back Model Connect View
			[self dismissViewControllerAnimated:YES completion:nil];
		});
	//}
}


#pragma mark - PTP/IP Operations.

- (UIImage *)imageThumbnail:(uint32_t)objectHandle session:(PtpIpSession*)session
{
	LOG_FUNC
	// This method MUST be running at PtpConnection#gcd thread.
	//mData.tamaObjectHandle = objectHandle;
	mData.tamaCapture = nil;
	
	// Get object informations.
	// It containes filename, capture-date and etc.
	PtpIpObjectInfo* objectInfo = [session getObjectInfo:objectHandle];
	if (!objectInfo) {
		dispatch_async_main(^{
			LOG(@"getObjectInfo(0x%08x) failed.", objectHandle);
		});
		//mData.tamaObjectHandle = 0;
		return nil;
	}
	
	UIImage* thumb;
	if (objectInfo.object_format==PTPIP_FORMAT_JPEG) {
		// Get thumbnail image.
		NSMutableData* thumbData = [NSMutableData data];
		BOOL result = [session getThumb:objectHandle
							onStartData:^(NSUInteger totalLength) {
								// Callback before thumb-data reception.
								LOG(@"getThumb(0x%08x) will received %zd bytes.", objectHandle, totalLength);
								
							} onChunkReceived:^BOOL(NSData *data) {
								// Callback for each chunks.
								[thumbData appendData:data];
								
								// Continue to receive.
								return YES;
							}];
		if (!result) {
			LOG(@"getThumb(0x%08x) failed.", objectHandle);
			thumb = [UIImage imageNamed:@"NoThumb.svg"];
		} else {
			// OK
			thumb = [UIImage imageWithData:thumbData];
			//set mData
			PtpObject * tamaObj = [[PtpObject alloc] initWithObjectInfo:objectInfo thumbnail:thumb];
			assert(tamaObj);
			[mData.tamaObjects addObject:tamaObj];
			mData.tamaCapture = tamaObj;
			LOG(@"mData.tamaObjects.count=%ld", (unsigned long)mData.tamaObjects.count);
		}
	} else {
		thumb = [UIImage imageNamed:@"NoThumb.svg"];
	}
	return thumb;
}


#pragma mark - UI events.

- (IBAction)volumeSliderChanged:(UISlider*)sender
{
//	if (!mData.option1payed && sender.value < 1) {
//		//BDToastAlert *toast = [BDToastAlert sharedInstance];
//		//[toast showToastWithText:NSLocalizedString(@"Lz.PrivilegeVolumeZero",nil) onViewController:self];
//		sender.value = 1;
//
//		UIAlertController *alertController = [UIAlertController
//											  alertControllerWithTitle:NSLocalizedString(@"Lz.PurchaseAlertTitle",nil)
//											  message:NSLocalizedString(@"Lz.PurchaseAlertMessage",nil)
//											  preferredStyle:UIAlertControllerStyleAlert];
//		// addActionした順に左から右にボタンが配置されます
//		[alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Lz.PurchaseAlertBuLeft",nil)
//						style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
//		{
//			// ボタンが押された時の処理
//			//[self otherButtonPushed];
//		}]];
//		[alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Lz.PurchaseAlertBuRight",nil)
//						style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
//		{
//			// ボタンが押された時の処理
//			//[self checkInAppPurchase];
//		}]];
//		[self presentViewController:alertController animated:YES completion:nil];
//	}

	mData.volumeLevel = sender.value;
	[self volumeShow];
}
- (void)volumeShow
{
	self.volumeSlider.value = mData.volumeLevel;
	self.volumeLabel.text = [NSString stringWithFormat:@"%ld%%", (long)mData.volumeLevel];
}

- (IBAction)onCaptureTouchDown:(id)sender
{
	// シャッターボタンを押したとき撮影
	if (mData.captureTouchDown) {
		[self capture];
	}
}

- (IBAction)onCaptureTouchUpInside:(id)sender
{
	// シャッターボタンを離したとき撮影
	if (!mData.captureTouchDown) {
		[self capture];
	}
}

- (void)capture
{
	//[self progressOnTitle:NSLocalizedString(@"Lz.Capture",nil)];
	[MRProgressOverlayView showOverlayAddedTo:self.view
										title:NSLocalizedString(@"Lz.Capture",nil)
										 mode:MRProgressOverlayViewModeIndeterminate
									 animated:YES
									stopBlock:^(MRProgressOverlayView *progressOverlayView) {
										// STOP処理
//										[self progressOnTitle:NSLocalizedString(@"Session closeing...",nil)];
//										[mData.ptpConnection close:^{
//											dispatch_async_main(^{
//												[self progressOff];
//												[self dismissViewControllerAnimated:YES completion:nil];
//											});
//										}];
										dispatch_async_main(^{
											[mData.ptpConnection setEventListener:nil];
											[self progressOff];
											[self dismissViewControllerAnimated:YES completion:nil];
										});
										return;
									}];
	
	self.captureButton.enabled = NO;
	self.ivThumbnail.image = [UIImage imageNamed:@"NoThumb.svg"];
	
	[mData.ptpConnection operateSession:^(PtpIpSession *session){
		// This block is running at PtpConnection#gcd thread.

		// シャッタースピード
		//     AUTO(0),
		//     1/8000, 1/6400, 1/5000, 1/4000, 1/3200,
		//     1/2500, 1/2000, 1/1600, 1/1250, 1/1000,
		//     1/800, 1/640, 1/500, 1/400, 1/320,
		//     1/250, 1/200, 1/160, 1/125, 1/100,
		//     1/80, 1/60, 1/50, 1/40, 1/30,
		//     1/25, 1/15, 1/13, 1/10, 10/75
		// [session setShutterSpeed: PtpIpRationalMake(1,400)]; // 1/400sec
		if (mShutterSpeed < 7) {
			[session setShutterSpeed: PtpIpRationalMake(0,0)]; // Auto
		} else if (mShutterSpeed < 10) {
			[session setShutterSpeed: PtpIpRationalMake(10,75)]; // 10/75 = 1/7.5
		} else {
			[session setShutterSpeed: PtpIpRationalMake(1,mShutterSpeed)];
		}
		
		// ISO感度
		//     100, 125, 160, 200, 250, 320, 400, 500, 640,
		//     800, 1000, 1250, 1600,
		//     AUTOMATIC(0xFFFF)
		// [session setExposureIndex: 100]; // ISO100
		[session setExposureIndex: mFilmIso];

		// ホワイトバランス
		//     AUTOMATIC, DAYLIGHT(屋外), SHADE(日陰), CLOUDY(曇天),
		//     TUNGSTEN1(白熱灯1),  TUNGSTEN2(白熱灯2),
		//     FLUORESCENT1(蛍光灯1(昼光色)), FLUORESCENT2(蛍光灯2(昼白色)),
		//     FLUORESCENT3(蛍光灯3(白色)), FLUORESCENT4(蛍光灯4(電球色))
		// [session setWhiteBalance: PTPIP_WHITE_BALANCE_DAYLIGHT]; // 屋外
		[session setWhiteBalance: mWhiteBalance];

		// 露出補正値
		//     2000, 1700, 1300, 1000, 700, 300,
		//     0, -300, -700, -1000, -1300, -1700, -2000
		//[session setExposureBiasCompensation: 300]; // +1/3EV
		[session setExposureBiasCompensation: 0];
		
		// set シャッターの音量
		[session setAudioVolume: mData.volumeLevel];
		
		switch (mCaptureMode) {
			case CAPTURE_MODE_NORMAL:
			{
				BOOL rtn = [session initiateCapture];
				LOG(@"execShutter[rtn:%d]", rtn);
				
				if (rtn != 1) {
					dispatch_async_main(^{
						[self dismissViewControllerAnimated:YES completion:nil];
					});
				}
			}	break;

			case CAPTURE_MODE_TIMELAPSE:
			{
				BOOL rtn = [session initiateOpenCapture];
				LOG(@"execShutter[rtn:%d]", rtn);
				if (rtn != 1) {
					dispatch_async_main(^{
						[self dismissViewControllerAnimated:YES completion:nil];
					});
				}
			}	break;
				
			case CAPTURE_MODE_MOVIE:
			{
				BOOL rtn = [session initiateOpenCapture];
				LOG(@"execShutter[rtn:%d]", rtn);
				if (rtn != 1) {
					dispatch_async_main(^{
						[self dismissViewControllerAnimated:YES completion:nil];
					});
				}
			}	break;

			default:
				break;
		}
	 }];
}

- (void)viewRefresh
{
	// 音量
	[self volumeShow];
	
	// 充電レベル   FULL(100), HALF(67), NEAR_END(33), END(0)
	self.batteryLabel.text = [NSString stringWithFormat:@"%ld%%", (unsigned long)mData.batteryLevel];
	float ff = (float)mData.batteryLevel / 100.0;
	if (ff < 0.33) {
		self.batteryProgress.progressTintColor = [UIColor redColor];
	}
	else if (ff < 0.67) {
		self.batteryProgress.progressTintColor = [UIColor yellowColor];
	}
	else {
		self.batteryProgress.progressTintColor = [UIColor blueColor];
	}
	self.batteryProgress.progress = ff;

	[self progressOff];
}


- (IBAction)onThumbnailTouchUpIn:(id)sender
{
	// サムネイル画像を押したとき
	if (mData.tamaCapture != nil) {
		// Goto Viewer View
		mData.tamaViewer = mData.tamaCapture;
		[self performSegueWithIdentifier:@"segViewer" sender:self];
	}
}

- (IBAction)onListTouchUpIn:(id)sender
{
	// List > を押したとき
	// Goto Model Viewer View
	[self performSegueWithIdentifier:@"segList" sender:self];
}

// シャッタースピード
//     AUTO(0),
//     1/8000, 1/6400, 1/5000, 1/4000, 1/3200,
//     1/2500, 1/2000, 1/1600, 1/1250, 1/1000,
//     1/800, 1/640, 1/500, 1/400, 1/320,
//     1/250, 1/200, 1/160, 1/125, 1/100,
//     1/80, 1/60, 1/50, 1/40, 1/30,
//     1/25, 1/15, 1/13, 1/10, 10/75
- (IBAction)sgShutter1Changed:(UISegmentedControl*)sender
{
	self.sgShutter2.selectedSegmentIndex = UISegmentedControlNoSegment; //クリア
	switch (sender.selectedSegmentIndex) {
		case 0: // Auto
			mShutterSpeed = 0;
			break;
		case 1: // 1/7.5
			mShutterSpeed = 7;
			break;
		case 2: // 1/15
			mShutterSpeed = 15;
			break;
		case 3: // 1/30
			mShutterSpeed = 30;
			break;
		case 4: // 1/60
			mShutterSpeed = 60;
			break;
		case 5: // 1/125
			mShutterSpeed = 125;
			break;
			
		default:
			mShutterSpeed = 0;
			return;
	}
//	// ISO感度をAutoにする
//	mFilmIso = 0xFFFF;
//	self.sgIso.selectedSegmentIndex = 0; //Auto
}

- (IBAction)sgShutter2Changed:(UISegmentedControl*)sender
{
	self.sgShutter1.selectedSegmentIndex = UISegmentedControlNoSegment; //クリア
	switch (sender.selectedSegmentIndex) {
		case 0: // 1/250
			mShutterSpeed = 250;
			break;
		case 1: // 1/500
			mShutterSpeed = 500;
			break;
		case 2: // 1/1000
			mShutterSpeed = 1000;
			break;
		case 3: // 1/2000
			mShutterSpeed = 2000;
			break;
		case 4: // 1/4000
			mShutterSpeed = 4000;
			break;
		case 5: // 1/8000
			mShutterSpeed = 8000;
			break;
			
		default:
			mShutterSpeed = 0;
			return;
	}
//	// ISO感度をAutoにする
//	mFilmIso = 0xFFFF;
//	self.sgIso.selectedSegmentIndex = 0; //Auto
}

// ISO感度
//     100, 125, 160, 200, 250, 320, 400, 500, 640,
//     800, 1000, 1250, 1600,
//     AUTOMATIC(0xFFFF)
- (IBAction)sgIsoChanged:(UISegmentedControl*)sender
{
	switch (sender.selectedSegmentIndex) {
		case 0: // Auto
			mFilmIso = 0xFFFF;
			break;
		case 1: // 100
			mFilmIso = 100;
			break;
		case 2: // 200
			mFilmIso = 200;
			break;
		case 3: // 400
			mFilmIso = 400;
			break;
		case 4: // 800
			mFilmIso = 800;
			break;
		case 5: // 1600
			mFilmIso = 1600;
			break;
			
		default:
			mFilmIso = 0xFFFF;
			return;
	}
//	// シャッタースピードをAutoにする
//	mShutterSpeed = 0;
//	self.sgShutter1.selectedSegmentIndex = 0; //Auto
//	self.sgShutter2.selectedSegmentIndex = UISegmentedControlNoSegment; //クリア
}

// ホワイトバランス
//     AUTOMATIC, DAYLIGHT(屋外), SHADE(日陰), CLOUDY(曇天),
//     TUNGSTEN1(白熱灯1),  TUNGSTEN2(白熱灯2),
//     FLUORESCENT1(蛍光灯1(昼光色)), FLUORESCENT2(蛍光灯2(昼白色)),
//     FLUORESCENT3(蛍光灯3(白色)), FLUORESCENT4(蛍光灯4(電球色))
//// DevceProp: WHITE_BALANCE
//PTPIP_WHITE_BALANCE_MANUAL      = 0x0001,
//PTPIP_WHITE_BALANCE_AUTOMATIC   = 0x0002,
//PTPIP_WHITE_BALANCE_ONE_PUSH_AUTOMATIC  = 0x0003,
//PTPIP_WHITE_BALANCE_DAYLIGHT    = 0x0004,
//PTPIP_WHITE_BALANCE_TUNGSTEN1   = 0x0006,
//PTPIP_WHITE_BALANCE_FLASH       = 0x0007,
//PTPIP_WHITE_BALANCE_SHADE       = 0x8001,
//PTPIP_WHITE_BALANCE_CLOUDY      = 0x8002,
//PTPIP_WHITE_BALANCE_FLUORESCENT1 = 0x8003,
//PTPIP_WHITE_BALANCE_FLUORESCENT2 = 0x8004,
//PTPIP_WHITE_BALANCE_FLUORESCENT3 = 0x8005,
//PTPIP_WHITE_BALANCE_FLUORESCENT4 = 0x8006,
//PTPIP_WHITE_BALANCE_TUNGSTEN2   = 0x8020,
- (IBAction)sgWhite1Changed:(UISegmentedControl*)sender
{
	self.sgWhite2.selectedSegmentIndex = UISegmentedControlNoSegment; //クリア
	switch (sender.selectedSegmentIndex) {
		case 0: // Auto
			mWhiteBalance = PTPIP_WHITE_BALANCE_AUTOMATIC;
			break;
		case 1: // 屋外
			mWhiteBalance = PTPIP_WHITE_BALANCE_DAYLIGHT;
			break;
		case 2: // 日陰
			mWhiteBalance = PTPIP_WHITE_BALANCE_SHADE;
			break;
		case 3: // 曇天
			mWhiteBalance = PTPIP_WHITE_BALANCE_CLOUDY;
			break;
		case 4: // 白熱灯1
			mWhiteBalance = PTPIP_WHITE_BALANCE_TUNGSTEN1;
			break;
		case 5: // 白熱灯2
			mWhiteBalance = PTPIP_WHITE_BALANCE_TUNGSTEN2;
			break;
			
		default:
			mWhiteBalance = PTPIP_WHITE_BALANCE_AUTOMATIC;
			break;
	}
}

- (IBAction)sgWhite2Changed:(UISegmentedControl*)sender
{
	self.sgWhite1.selectedSegmentIndex = UISegmentedControlNoSegment; //クリア
	switch (sender.selectedSegmentIndex) {
		case 0: // 蛍光灯1(昼光色)
			mWhiteBalance = PTPIP_WHITE_BALANCE_FLUORESCENT1;
			break;
		case 1: // 蛍光灯2(昼白色)
			mWhiteBalance = PTPIP_WHITE_BALANCE_FLUORESCENT2;
			break;
		case 2: // 蛍光灯3(白色)
			mWhiteBalance = PTPIP_WHITE_BALANCE_FLUORESCENT3;
			break;
		case 3: // 蛍光灯4(電球色)
			mWhiteBalance = PTPIP_WHITE_BALANCE_FLUORESCENT4;
			break;
			
		default:
			mWhiteBalance = PTPIP_WHITE_BALANCE_AUTOMATIC;
			break;
	}
}

- (void)progressOnTitle:(NSString*)zTitle
{
	if (zTitle) {
		[MRProgressOverlayView showOverlayAddedTo:self.view
											title:zTitle	// nil だと落ちる
											 mode:MRProgressOverlayViewModeIndeterminate
										 animated:YES];
	} else {
		[MRProgressOverlayView showOverlayAddedTo:self.view animated:YES];
	}
}

- (void)progressOff
{
	[MRProgressOverlayView dismissOverlayForView:self.view animated:YES];
}



#pragma mark - Life cycle.

- (void)viewDidLoad
{
	[super viewDidLoad];
	LOG_FUNC
	
	AppDelegate * app = [UIApplication sharedApplication].delegate;
	mData = [app getDataObject];
	assert(mData != nil);
	
	//
	mShutterSpeed = 0;  //AUTO(0)
	mFilmIso = 0xFFFF;  //AUTOMATIC(0xFFFF)
	mWhiteBalance = PTPIP_WHITE_BALANCE_AUTOMATIC;

	
	//  通知受信の設定
	NSNotificationCenter*   nc = [NSNotificationCenter defaultCenter];
	//[nc addObserver:self selector:@selector(applicationDidEnterBackground) name:@"applicationDidEnterBackground" object:nil];
	[nc addObserver:self selector:@selector(applicationWillEnterForeground) name:@"applicationWillEnterForeground" object:nil];

	// Thumbnailコーナを丸くする
	[[self.ivThumbnail layer] setCornerRadius: self.ivThumbnail.frame.size.height / 3.0];
	[self.ivThumbnail setClipsToBounds:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	if (self.ivThumbnail.image==nil) {
		self.ivThumbnail.image = [UIImage imageNamed:@"NoThumb.svg"];
	}

	//self.batteryProgress.transform = CGAffineTransformMakeScale( 1.0f, 3.0f ); // 横方向に1倍、縦方向に3倍して表示する
//	[UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
//		self.batteryProgress.transform = CGAffineTransformMakeScale( 1.0f, 0.0f );
//	} completion:^(BOOL finished) {
//		self.batteryProgress.transform = CGAffineTransformMakeScale( 1.0f, 3.0f );
//	}];
	
	
	self.sgShutter1.selectedSegmentIndex = 0;
	self.sgShutter2.selectedSegmentIndex = UISegmentedControlNoSegment;
	self.sgIso.selectedSegmentIndex = 0;
	self.sgWhite1.selectedSegmentIndex = 0;
	self.sgWhite2.selectedSegmentIndex = UISegmentedControlNoSegment;
	
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	LOG_FUNC
	[self applicationWillEnterForeground];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}



//2回目以降のフォアグラウンド実行になった際に呼び出される(Backgroundにアプリがある場合)
- (void)applicationWillEnterForeground
{
	LOG_FUNC
	
#if TARGET_IPHONE_SIMULATOR
	mData.volumeLevel = 33; // TEST Dummy.
	mData.batteryLevel = 88; // TEST Dummy.
	[self viewRefresh];
#else
	// コネクト・チェック
	LOG(@"mData.ptpConnection.connected=%d", mData.ptpConnection.connected);
	if (mData.connected) {
		// Ready to PTP/IP.
		[mData.ptpConnection setLoglevel:PTPIP_LOGLEVEL_WARN];
		// PtpIpEventListener delegates.
		[mData.ptpConnection setEventListener:self]; //画面遷移の都度、デリゲート指定必須
		
		[mData.ptpConnection operateSession:^(PtpIpSession *session) {
			// Get

			// 充電レベル   FULL(100), HALF(67), NEAR_END(33), END(0)
			mData.batteryLevel = [session getBatteryLevel];
			

			// 静止画撮影の方法
			//     0(静止画撮影モードではない＝動画モードと判定しても良い),
			//     NORMAL(単写モード), TIMELAPSE(インターバル撮影)
//			// DevceProp: STILL_CAPTURE_MODE
//			PTPIP_STILL_CAPTURE_MODE_NORMAL     = 0x0001,
//			PTPIP_STILL_CAPTURE_MODE_BURST,
//			PTPIP_STILL_CAPTURE_MODE_TIMELAPSE,
//			PTPIP_STILL_CAPTURE_MODE_SOUND      = 0x8000,
//			PTPIP_STILL_CAPTURE_MODE_NORMAL_WITH_SOUND    = PTPIP_STILL_CAPTURE_MODE_NORMAL    | PTPIP_STILL_CAPTURE_MODE_SOUND,
//			PTPIP_STILL_CAPTURE_MODE_BURST_WITH_SOUND     = PTPIP_STILL_CAPTURE_MODE_BURST     | PTPIP_STILL_CAPTURE_MODE_SOUND,
//			PTPIP_STILL_CAPTURE_MODE_TIMELAPSE_WITH_SOUND = PTPIP_STILL_CAPTURE_MODE_TIMELAPSE | PTPIP_STILL_CAPTURE_MODE_SOUND,
//			PTPIP_STILL_CAPTURE_MODE_MOVIE      = 0x8010,

			NSInteger stillCaptureMode = [session getStillCaptureMode];
			LOG(@"stillCaptureMode=%ld",(long)stillCaptureMode);

			mCaptureMode = CAPTURE_MODE_NORMAL;
			if (stillCaptureMode==0 || stillCaptureMode==PTPIP_STILL_CAPTURE_MODE_MOVIE) {
				mCaptureMode = CAPTURE_MODE_MOVIE;
				// 動画記録時間(秒)(型番：RICOH THETA m15)
				NSUInteger recordingTime = [session getRecordingTime];
				LOG(@"recordingTime=%ld",(long)recordingTime);
				
				// 動画の残り記録時間（秒）(型番：RICOH THETA m15)
				NSUInteger remainingRecordingTime = [session getRemainingRecordingTime];
				LOG(@"remainingRecordingTime=%ld",(long)remainingRecordingTime);
			}
			else if	(stillCaptureMode==PTPIP_STILL_CAPTURE_MODE_TIMELAPSE) {
				mCaptureMode = CAPTURE_MODE_TIMELAPSE;
				// インターバル撮影の上限枚数
				//     0(上限なし), 2-65535
				NSInteger timelapseNumber = [session getTimelapseNumber];
				LOG(@"timelapseNumber=%ld",(long)timelapseNumber);
				
				// インターバル撮影の撮影間隔
				//     5000-3600000 msec
				NSInteger timelapseInterval= [session getTimelapseInterval];
				LOG(@"timelapseInterval=%ld",(long)timelapseInterval);
			}
			
			dispatch_async_main(^{
				[self viewRefresh];
			});
		}];
	}
	else {
		// ConnectView
		[self dismissViewControllerAnimated:YES completion:nil];
		return;
	}
#endif

}

@end
