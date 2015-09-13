//
//  CaptureViewController.m
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "MRProgress.h"		// http://cocoadocs.org/docsets/MRProgress/0.2.2/

#import "Azukid.h"
#import "TheTama-Swift.h"
#import "TheTaManager.h"

#import "CaptureViewController.h"
#import "PtpConnection.h"
#import "PtpLogging.h"
#import "PtpObject.h"



inline static void dispatch_async_main(dispatch_block_t block)
{
	dispatch_async(dispatch_get_main_queue(), block);
}

@interface CaptureViewController () <TheTaManagerDelegate>
{
	DataObject*		mData;
	//TheTaManager*	mCapture;
	
	NSUInteger		mShutterSpeed;
	NSInteger		mFilmIso;
	NSInteger		mWhiteBalance;
	CAPTURE_MODE	mCaptureMode;
	NSInteger		mTransactionId;
	UIImage*		mImageThumb;
	NSTimer*		mTimerCheck;
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
@property (nonatomic, strong) IBOutlet UILabel  * lbThumbnail;
@property (nonatomic, strong) IBOutlet UIButton * buThumbnail;
@property (nonatomic, strong) IBOutlet UIButton * buCapture;
@property (nonatomic, strong) IBOutlet UISwitch * swPreview;

@end


@implementation CaptureViewController


//
//#pragma mark - PtpIpEventListener delegates.
//
//-(void)ptpip_eventReceived:(int)code :(uint32_t)param1 :(uint32_t)param2 :(uint32_t)param3
//{
//	LOG_FUNC
//	// PTP/IP-Event callback.
//	// This method is running at PtpConnection#gcd thread.
//	switch (code) {
//		default:
//			LOG(@"Event(0x%04x) received", code);
//			break;
//			
//		case PTPIP_DEVICE_PROP_CHANGED:
//		{	// デバイスのプロパティに変化あり
//			return;
//		} break;
//
//		case PTPIP_CAPTURE_COMPLETE:
//		{	// 撮影が完了した際に呼び出される
//			dispatch_async_main(^{
//				//[self progressOff];
//				[self viewRefresh];
//			});
//		} break;
//		
//		case PTPIP_OBJECT_ADDED:
//		{	// 撮影などを行った際にオブジェクトが作成された際に呼び出される
//			LOG(@"Object added Event(0x%04x) - 0x%08x", code, param1);
//			[mData.ptpConnection operateSession:^(PtpIpSession *session) {
//				// サムネイルを取得し、表示する
//				[self imageThumbnail:param1 session:session];
//			}];
//		} break;
//			
//		case PTPIP_STORE_FULL:
//		{	// ストレージFULL
//			return;
//		} break;
//	}
//	
//}
//
//-(void)ptpip_socketError:(int)err
//{
//	// socket error callback.
//	// This method is running at PtpConnection#gcd thread.
//	
//	// If libptpip closed the socket, `closed` is non-zero.
//	BOOL closed = PTP_CONNECTION_CLOSED(err);
//	
//	// PTPIP_PROTOCOL_*** or POSIX error number (errno()).
//	err = PTP_ORIGINAL_PTPIPERROR(err);
//	
//	NSArray* errTexts = @[@"Socket closed",              // PTPIP_PROTOCOL_SOCKET_CLOSED
//						  @"Brocken packet",             // PTPIP_PROTOCOL_BROCKEN_PACKET
//						  @"Rejected",                   // PTPIP_PROTOCOL_REJECTED
//						  @"Invalid session id",         // PTPIP_PROTOCOL_INVALID_SESSION_ID
//						  @"Invalid transaction id.",    // PTPIP_PROTOCOL_INVALID_TRANSACTION_ID
//						  @"Unrecognided command",       // PTPIP_PROTOCOL_UNRECOGNIZED_COMMAND
//						  @"Invalid receive state",      // PTPIP_PROTOCOL_INVALID_RECEIVE_STATE
//						  @"Invalid data length",        // PTPIP_PROTOCOL_INVALID_DATA_LENGTH
//						  @"Watchdog expired",           // PTPIP_PROTOCOL_WATCHDOG_EXPIRED
//						  ];
//	NSString* desc;
//	if ((PTPIP_PROTOCOL_SOCKET_CLOSED<=err) && (err<=PTPIP_PROTOCOL_WATCHDOG_EXPIRED)) {
//		desc = [errTexts objectAtIndex:err-PTPIP_PROTOCOL_SOCKET_CLOSED];
//	} else {
//		desc = [NSString stringWithUTF8String:strerror(err)];
//	}
//	
//	LOG(@"socket error(0x%X,closed=%@).\n--- %@", err, closed? @"YES": @"NO", desc);
//	//if (closed) {
//		[mData.ptpConnection setEventListener:nil];
//		
//		dispatch_async_main(^{
//			[self progressOff];
//			// Back Model Connect View
//			[self dismissViewControllerAnimated:YES completion:nil];
//		});
//	//}
//}


#pragma mark - PTP/IP Operations.

//- (void)imageThumbnail:(uint32_t)objectHandle session:(PtpIpSession*)session
//{
//	LOG_FUNC
//	// This method MUST be running at PtpConnection#gcd thread.
//
//	mData.tamaCapture = nil;
//	
//	// Get object informations.
//	// It containes filename, capture-date and etc.
//	PtpIpObjectInfo* objectInfo = [session getObjectInfo:objectHandle];
//	if (!objectInfo) {
//		LOG(@"getObjectInfo(0x%08x) failed.", objectHandle);
//		//mData.tamaObjectHandle = 0;
//		return;
//	}
//	
//	UIImage* thumb = mImageThumb;
//	if (mData.capturePreview && objectInfo.object_format==PTPIP_FORMAT_JPEG) {
//		// Get thumbnail image.
//		NSMutableData* thumbData = [NSMutableData data];
//		BOOL result = [session getThumb:objectHandle
//							onStartData:^(NSUInteger totalLength) {
//								// Callback before thumb-data reception.
//								LOG(@"getThumb(0x%08x) will received %zd bytes.", objectHandle, totalLength);
//								
//							} onChunkReceived:^BOOL(NSData *data) {
//								// Callback for each chunks.
//								[thumbData appendData:data];
//								
//								// Continue to receive.
//								return YES;
//							}];
//		if (result) {
//			// OK
//			thumb = [UIImage imageWithData:thumbData];
//			//set mData
//			PtpObject * tamaObj = [[PtpObject alloc] initWithObjectInfo:objectInfo thumbnail:thumb];
//			assert(tamaObj);
//			if (0 < mData.tamaObjects.count) {
//				[mData.tamaObjects addObject:tamaObj];
//			}
//			LOG(@"mData.tamaObjects.count=%ld", (unsigned long)mData.tamaObjects.count);
//			mData.tamaCapture = tamaObj;
//			mData.listBottom = YES; // ListViewにて最終行を表示させる
//		} else {
//			LOG(@"getThumb(0x%08x) failed.", objectHandle);
//		}
//	}
//	
//	// Get Battery level.
//	mData.batteryLevel = [session getBatteryLevel];
//	
//	// UI Refresh
//	NSDateFormatter* df = [[NSDateFormatter alloc] init];
//	[df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
//	[df setDateStyle:NSDateFormatterShortStyle];
//	[df setTimeStyle:NSDateFormatterMediumStyle];
//	dispatch_async_main(^{
//		[self thumbnail:thumb title:[df stringFromDate:objectInfo.capture_date]];
//	});
//}



#pragma mark - <CaptureDelegate>

- (void)connected:(BOOL)result
{
	LOG_FUNC
	[self progressOff];
}

- (void)disconnected
{
	LOG_FUNC
}

//- (void)captured:(BOOL)result thumb:(UIImage*)thumb date:(NSDate *)capture_date
//{
//	LOG_FUNC
//	if (result) {
//		NSDateFormatter* df = [[NSDateFormatter alloc] init];
//		[df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
//		[df setDateStyle:NSDateFormatterShortStyle];
//		[df setTimeStyle:NSDateFormatterMediumStyle];
//		dispatch_async_main(^{
//			[self thumbnail:thumb title:[df stringFromDate:capture_date]];
//			self.buCapture.enabled = YES;
//		});
//	}
//	else {
//		dispatch_async_main(^{
//			[self dismissViewControllerAnimated:YES completion:nil];
//		});
//	}
//}

- (void)strageFull
{
	LOG_FUNC
}

- (void)socketError
{
	LOG_FUNC
	dispatch_async_main(^{
		[self dismissViewControllerAnimated:YES completion:nil];
	});
}


#pragma mark - UI events.

- (IBAction)volumeSliderChanged:(UISlider*)sender
{
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
		//[self capture];
	}
}

- (IBAction)onCaptureTouchUpInside:(id)sender
{
	// シャッターボタンを離したとき撮影
	if (!mData.captureTouchDown) {
		//[self capture];
	}
}

//- (void)capture
//{
//	LOG_FUNC
//
//	switch (mCaptureMode) {
//		case CAPTURE_MODE_NORMAL:
//		{
//			[self progressOnTitle:NSLocalizedString(@"During 360° Capture.", nil)];
//		}	break;
//			
//		case CAPTURE_MODE_TIMELAPSE:
//		{
//			[MRProgressOverlayView showOverlayAddedTo:self.view
//												title:NSLocalizedString(@"During timelapse shooting.",nil)
//												 mode:MRProgressOverlayViewModeIndeterminate
//											 animated:YES
//											stopBlock:^(MRProgressOverlayView *progressOverlayView) {
//												// STOP処理
//												[self progressOff];
//												[self progressOnTitle:NSLocalizedString(@"Saveing...", nil)];
//												[mConnection operateSession:^(PtpIpSession *session){
//													BOOL result = [session terminateOpenCapture: mTransactionId];
//													LOG(@"terminateOpenCapture: result=%d", result);
//													if (completion) {
//														completion(YES, nil, nil, nil);
//													}
//												}];
//												return;
//											}];
//		}	break;
//			
//		case CAPTURE_MODE_MOVIE:
//		{
//			[MRProgressOverlayView showOverlayAddedTo:self.view
//												title:NSLocalizedString(@"During movie shooting.",nil)
//												 mode:MRProgressOverlayViewModeIndeterminate
//											 animated:YES
//											stopBlock:^(MRProgressOverlayView *progressOverlayView) {
//												// STOP処理
//												[self progressOff];
//												[self progressOnTitle:NSLocalizedString(@"Saveing...", nil)];
//												[mConnection operateSession:^(PtpIpSession *session){
//													BOOL result = [session terminateOpenCapture: mTransactionId];
//													LOG(@"terminateOpenCapture: result=%d", result);
//													if (completion) {
//														completion(YES, nil, nil, nil);
//													}
//												}];
//												return;
//											}];
//		}	break;
//			
//		default:
//			break;
//	}
//
//	mCapture.shutterSpeed = mShutterSpeed;
//	mCapture.filmIso = mFilmIso;
//	mCapture.whiteBalance = mWhiteBalance;
//	mCapture.volumeLevel = mData.volumeLevel;
//	[mCapture captureCompletion:^(BOOL success, UIImage * thumbnail, NSDate * capture_date, NSError *error) {
//		if (success) {
//			// サムネイル表示
//			NSDateFormatter* df = [[NSDateFormatter alloc] init];
//			[df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
//			[df setDateStyle:NSDateFormatterShortStyle];
//			[df setTimeStyle:NSDateFormatterMediumStyle];
//			dispatch_async_main(^{
//				[self thumbnail:thumbnail title:[df stringFromDate:capture_date]];
//				self.buCapture.enabled = YES;
//			});
//		}
//		else{
//			dispatch_async_main(^{
//				[self dismissViewControllerAnimated:YES completion:nil];
//			});
//		}
//		
//		[self progressOff];
//	}];
//}


//- (void)capture
//{
//	self.buCapture.enabled = NO;
//	[self thumbnailOff];
//
//	switch (mCaptureMode) {
//		case CAPTURE_MODE_NORMAL:
//		{
//			[self progressOnTitle:NSLocalizedString(@"During 360° Capture.",nil)];
//		}	break;
//			
//		case CAPTURE_MODE_TIMELAPSE:
//		{
//			[MRProgressOverlayView showOverlayAddedTo:self.view
//												title:NSLocalizedString(@"During timelapse shooting.",nil)
//												 mode:MRProgressOverlayViewModeIndeterminate
//											 animated:YES
//											stopBlock:^(MRProgressOverlayView *progressOverlayView) {
//												// STOP処理
//												[self progressOff];
//												[self progressOnTitle:NSLocalizedString(@"Saveing...",nil)];
//												[mData.ptpConnection operateSession:^(PtpIpSession *session){
//													BOOL result = [session terminateOpenCapture: mTransactionId];
//													LOG(@"terminateOpenCapture: result=%d", result);
//													dispatch_async_main(^{
//														self.buCapture.enabled = YES;
//													});
//												}];
//												return;
//											}];
//		}	break;
//			
//		case CAPTURE_MODE_MOVIE:
//		{
//			[MRProgressOverlayView showOverlayAddedTo:self.view
//												title:NSLocalizedString(@"During movie shooting.",nil)
//												 mode:MRProgressOverlayViewModeIndeterminate
//											 animated:YES
//											stopBlock:^(MRProgressOverlayView *progressOverlayView) {
//												// STOP処理
//												[self progressOff];
//												[self progressOnTitle:NSLocalizedString(@"Saveing...",nil)];
//												[mData.ptpConnection operateSession:^(PtpIpSession *session){
//													BOOL result = [session terminateOpenCapture: mTransactionId];
//													LOG(@"terminateOpenCapture: result=%d", result);
//													dispatch_async_main(^{
//														self.buCapture.enabled = YES;
//													});
//												}];
//												return;
//											}];
//		}	break;
//			
//		default:
//			break;
//	}
//	
//	[mData.ptpConnection operateSession:^(PtpIpSession *session){
//		// This block is running at PtpConnection#gcd thread.
//
//		// シャッタースピード
//		//     AUTO(0),
//		//     1/8000, 1/6400, 1/5000, 1/4000, 1/3200,
//		//     1/2500, 1/2000, 1/1600, 1/1250, 1/1000,
//		//     1/800, 1/640, 1/500, 1/400, 1/320,
//		//     1/250, 1/200, 1/160, 1/125, 1/100,
//		//     1/80, 1/60, 1/50, 1/40, 1/30,
//		//     1/25, 1/15, 1/13, 1/10, 10/75
//		// [session setShutterSpeed: PtpIpRationalMake(1,400)]; // 1/400sec
//		if (mShutterSpeed < 7) {
//			[session setShutterSpeed: PtpIpRationalMake(0,0)]; // Auto
//		} else if (mShutterSpeed < 10) {
//			[session setShutterSpeed: PtpIpRationalMake(10,75)]; // 10/75 = 1/7.5
//		} else {
//			[session setShutterSpeed: PtpIpRationalMake(1,mShutterSpeed)];
//		}
//		
//		// ISO感度
//		//     100, 125, 160, 200, 250, 320, 400, 500, 640,
//		//     800, 1000, 1250, 1600,
//		//     AUTOMATIC(0xFFFF)
//		// [session setExposureIndex: 100]; // ISO100
//		[session setExposureIndex: mFilmIso];
//
//		// ホワイトバランス
//		//     AUTOMATIC, DAYLIGHT(屋外), SHADE(日陰), CLOUDY(曇天),
//		//     TUNGSTEN1(白熱灯1),  TUNGSTEN2(白熱灯2),
//		//     FLUORESCENT1(蛍光灯1(昼光色)), FLUORESCENT2(蛍光灯2(昼白色)),
//		//     FLUORESCENT3(蛍光灯3(白色)), FLUORESCENT4(蛍光灯4(電球色))
//		// [session setWhiteBalance: PTPIP_WHITE_BALANCE_DAYLIGHT]; // 屋外
//		[session setWhiteBalance: mWhiteBalance];
//
//		// 露出補正値
//		//     2000, 1700, 1300, 1000, 700, 300,
//		//     0, -300, -700, -1000, -1300, -1700, -2000
//		//[session setExposureBiasCompensation: 300]; // +1/3EV
//		[session setExposureBiasCompensation: 0];
//		
//		// set シャッターの音量
//		[session setAudioVolume: mData.volumeLevel];
//		
//		switch (mCaptureMode) {
//			case CAPTURE_MODE_NORMAL:
//			{
//				BOOL rtn = [session initiateCapture];
//				LOG(@"execShutter[rtn:%d]", rtn);
//				
//				if (rtn != 1) {
//					dispatch_async_main(^{
//						[self dismissViewControllerAnimated:YES completion:nil];
//					});
//				}
//			}	break;
//
//			case CAPTURE_MODE_TIMELAPSE:
//			{
//				mTransactionId = [session initiateOpenCapture];
//				LOG(@"mTransactionId:%ld", mTransactionId);
//			}	break;
//				
//			case CAPTURE_MODE_MOVIE:
//			{
//				mTransactionId = [session initiateOpenCapture];
//				LOG(@"mTransactionId:%ld", mTransactionId);
//			}	break;
//
//			default:
//				break;
//		}
//	 }];
//}

- (void)viewRefresh
{
	dispatch_async_main(^{
		self.buCapture.enabled = YES;
		
		// 音量
		[self volumeShow];
		
		// 充電レベル
		[self viewRefreshBattery];
		
		[self progressOff];
	});
}

- (void)viewRefreshBattery
{
	TheTaManager *thetama = [TheTaManager sharedInstance];
	// 充電レベル   FULL(100), HALF(67), NEAR_END(33), END(0)
	self.batteryLabel.text = [NSString stringWithFormat:@"%ld%%", (unsigned long)thetama.batteryLevel];
	float ff = (float)thetama.batteryLevel / 100.0;
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
}

- (void)timerCheck:(NSTimer*)timer
{	// Wi-Fi接続状態を監視する、切れると第一画面へ
	LOG_FUNC
#if TARGET_IPHONE_SIMULATOR
	return;
#endif
	//[mTimerCheck invalidate];	//タイマー停止
	
	if (![TheTaManager sharedInstance].isConnected) {
		[self progressOff];
		[self dismissViewControllerAnimated:YES completion:nil];
		return;
	}

//	[mConnection operateSession:^(PtpIpSession *session) {
//		// 充電レベル
//		mData.batteryLevel = [session getBatteryLevel];
//		dispatch_async_main(^{
//			[self viewRefreshBattery];
//		});
//		//[mTimerCheck fire]; //タイマー再開
//	}];
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
	mData.listBottom = YES; // ListViewにて最終行を表示させる
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

- (IBAction)swPreviewChanged:(UISwitch*)sender
{
	mData.capturePreview = sender.on;
	
	if (!mData.capturePreview) {
		[self thumbnailOff];
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

- (void)thumbnail:(UIImage*)img title:(NSString*)title
{
	self.ivThumbnail.image = img;
	self.lbThumbnail.text = title;
	self.buThumbnail.enabled = YES;
	[self viewRefresh];
}

- (void)thumbnailOff
{
	self.ivThumbnail.image = mImageThumb;
	self.lbThumbnail.text = nil;
	self.buThumbnail.enabled = NO;
	[self viewRefresh];
}



#pragma mark - Life cycle.

- (void)viewDidLoad
{
	[super viewDidLoad];
	LOG_FUNC
	
	AppDelegate * app = [UIApplication sharedApplication].delegate;
	mData = [app getDataObject];
	assert(mData != nil);
	
//	mCapture = [app getCaptureObject];
//	assert(mCapture != nil);

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
	
	self.lbThumbnail.text = nil;
	
	// 監視タイマー生成
//	mTimerCheck = [NSTimer	scheduledTimerWithTimeInterval:5.0f
//												   target:self
//												 selector:@selector(timerCheck:)
//												 userInfo:nil
//												  repeats:YES ];

	mTimerCheck = [NSTimer timerWithTimeInterval:6.0f target:self selector:@selector(timerCheck:) userInfo:nil repeats:YES];

}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
//	mCapture.delegate = self;
//	mCapture.view = self.view;
	[TheTaManager sharedInstance].delegate = self;
	[TheTaManager sharedInstance].view = self.view;
	
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
	
	mData.capturePreview = YES; //常にYES: プレビューOFFにしてもレスポンス変わらず廃案とした
	self.swPreview.on = mData.capturePreview;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	LOG_FUNC

	[self applicationWillEnterForeground]; //[self viewRefresh];

	[mTimerCheck fire]; //タイマー開始   //TODO:リピートされない？
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
	//mData.batteryLevel = 88; // TEST Dummy.
	[self viewRefresh];
#else
	[self viewRefresh];
	
	TheTaManager* thetama = [TheTaManager sharedInstance];
	// コネクト・チェック
	if (thetama.isConnected) {
		switch (thetama.captureMode) {
			case CAPTURE_MODE_NORMAL:
				mImageThumb = [UIImage imageNamed:@"Tama2.svg"];
				break;
			case CAPTURE_MODE_MOVIE:
				mImageThumb = [UIImage imageNamed:@"Tama2.svg-Movie"];
				break;
			case CAPTURE_MODE_TIMELAPSE:
				mImageThumb = [UIImage imageNamed:@"Tama2.svg-Timelapse"];
				break;
			default:
				mImageThumb = nil;
				break;
		}
		[self thumbnailOff];
	}
	else {
		// ConnectView
		[self dismissViewControllerAnimated:YES completion:nil];
		return;
	}
#endif

}

@end
