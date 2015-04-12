//
//  CaptureViewController.m
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "SVProgressHUD.h"
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
	NSUInteger mShutterSpeed;
	NSInteger mFilmIso;
	NSInteger mWhiteBalance;
}

@property (nonatomic, strong) IBOutlet UISegmentedControl * sgShutter1;
@property (nonatomic, strong) IBOutlet UISegmentedControl * sgShutter2;
@property (nonatomic, strong) IBOutlet UISegmentedControl * sgIso;
@property (nonatomic, strong) IBOutlet UISegmentedControl * sgMode;

@property (nonatomic, strong) IBOutlet UILabel * batteryLabel;
@property (nonatomic, strong) IBOutlet UIProgressView * batteryProgress;

@property (nonatomic, strong) IBOutlet UILabel  * volumeLabel;
@property (nonatomic, strong) IBOutlet UISlider * volumeSlider;
@property (nonatomic, strong) IBOutlet UIButton * volumeMute;
@property (nonatomic, strong) IBOutlet UIButton * volumeMax;

@property (nonatomic, strong) IBOutlet UIImageView * ivThumbnail;
//@property (nonatomic, strong) IBOutlet UIButton * buThumbnail;

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
			
		case PTPIP_OBJECT_ADDED:
		{
			// It will be receive when the camera has taken a new photo.
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
		}
			break;
	}
	dispatch_async_main(^{
		[SVProgressHUD dismiss];
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
	
	dispatch_async_main(^{
		[SVProgressHUD showWithStatus:@"THETA\nDisconnect." maskType:SVProgressHUDMaskTypeGradient];
		LOG(@"socket error(0x%X,closed=%@).\n--- %@", err, closed? @"YES": @"NO", desc);
		[self disconnect];
		[SVProgressHUD dismiss];
		// Back Model Connect View
		[self dismissViewControllerAnimated:YES completion:nil];
	});
}


#pragma mark - PTP/IP Operations.

- (void)connect
{
	LOG_FUNC
	
	_captureButton.enabled = NO;
	//[self.indicator startAnimating];
	//[SVProgressHUD show];
	[SVProgressHUD showWithStatus:@"THETA\nConnecting..." maskType:SVProgressHUDMaskTypeGradient];
	
	//[self appendLog:[NSString stringWithFormat:@"connecting %@...", _ipField.text]];
	
	// Setup `target IP`(camera IP).
	// Product default is "192.168.1.1".
	[mData.ptpConnection setTargetIp: @"192.168.1.1"]; // _ipField.text];
	
	// Connect to target.
	[mData.ptpConnection connect:^(BOOL connected) {
		// "Connect" and "OpenSession" completion callback.
		// This block is running at PtpConnection#gcd thread.
		
		if (connected) {
			// "Connect" is succeeded.
			LOG(@"connected.");
			
			dispatch_async_main(^{
				self.captureButton.enabled = YES;
			});
			
		} else {
			// "Connect" is failed.
			// "-(void)ptpip_socketError:(int)err" will run later than here.
			LOG(@"connect failed.");
			
			dispatch_async_main(^{
				// Back Model Connect View
				[self dismissViewControllerAnimated:YES completion:nil];
			});
			
		}
		dispatch_async_main(^{
			[SVProgressHUD dismiss];
		});
	}];
}

- (void)disconnect
{
	LOG_FUNC
	[SVProgressHUD showWithStatus:@"THETA\nDisconnecting..." maskType:SVProgressHUDMaskTypeGradient];

	[mData.ptpConnection close:^{
		// "CloseSession" and "Close" completion callback.
		// This block is running at PtpConnection#gcd thread.

		dispatch_async_main(^{
			LOG(@"disconnected.");
			[SVProgressHUD dismiss];
			[self dismissViewControllerAnimated:YES completion:nil];
		});
	}];
}

//- (void)enumObjects
//{
//	assert([mData.ptpConnection connected]);
//	assert(mData.tamaObjects != nil);
//	
//	[self.indicator startAnimating];
//	[mData.tamaObjects removeAllObjects];
//	
//	[mData.ptpConnection operateSession:^(PtpIpSession *session) {
//		// This block is running at PtpConnection#gcd thread.
//		
//		// Setting the RICOH THETA's clock.
//		// 'setDateTime' convert from specified date/time to local-time, and send to RICOH THETA.
//		// RICOH THETA work with local-time, without timezone.
//		[session setDateTime:[NSDate dateWithTimeIntervalSinceNow:0]];
//		
//		// Get storage information.
//		mData.storageInfo = [session getStorageInfo];
//		
//		// Get Battery level.
//		mData.batteryLevel = [session getBatteryLevel];
//		
//		// Set Volume level.
//		[session setAudioVolume: mData.volumeLevel];
//		
//		
//		// Get object handles for primary images.
//		NSArray* objectHandles = [session getObjectHandles];
//		dispatch_async_main(^{
//			NSLog(@"getObjectHandles() recevied %zd handles.", objectHandles.count);
//		});
//		
//		// Get object informations and thumbnail images for each primary images.
//		for (NSNumber* it in objectHandles) {
//			uint32_t objectHandle = (uint32_t)it.integerValue;
//			[mData.tamaObjects addObject:[self loadObject:objectHandle session:session]];
//		}
//		dispatch_async_main(^{
//			[_contentsView reloadData];
//			[self viewRefresh];
//			[self.indicator stopAnimating];
//		});
//	}];
//}

- (UIImage *)imageThumbnail:(uint32_t)objectHandle session:(PtpIpSession*)session
{
	LOG_FUNC
	// This method MUST be running at PtpConnection#gcd thread.
	//mData.tamaObjectHandle = objectHandle;
	mData.tamaObject = nil;
	
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
			thumb = [UIImage imageNamed:@"TheTama-NG"];
		} else {
			// OK
			thumb = [UIImage imageWithData:thumbData];
			//set mData
			PtpObject * tamaObj = [[PtpObject alloc] initWithObjectInfo:objectInfo thumbnail:thumb];
			assert(tamaObj);
			[mData.tamaObjects addObject:tamaObj];
			mData.tamaObject = tamaObj;
			LOG(@"mData.tamaObjects.count=%ld", mData.tamaObjects.count);
		}
	} else {
		thumb = [UIImage imageNamed:@"TheTama-NG"];
	}
	return thumb;
}


#pragma mark - UI events.

- (IBAction)volumeSliderChanged:(UISlider*)sender
{
	mData.volumeLevel = sender.value;
	[self volumeShow];
}
- (void)volumeShow
{
	self.volumeLabel.text = [NSString stringWithFormat:@"%ld%%", (long)mData.volumeLevel];
	
	self.volumeMute.enabled = YES;
	self.volumeMax.enabled = YES;
	
	if (mData.volumeLevel <= 0) {
		self.volumeMute.enabled = NO;
		self.volumeSlider.value = 0;
		//self.volumeLabel.text = self.volumeMute.titleLabel.text;
	}
	else if (100 <= mData.volumeLevel) {
		self.volumeMax.enabled = NO;
		self.volumeSlider.value = 100;
		//self.volumeLabel.text = self.volumeMax.titleLabel.text;
	}
	else {
		self.volumeSlider.value = mData.volumeLevel;
	}
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
	//[self.indicator startAnimating];
	//[SVProgressHUD show];
	[SVProgressHUD showWithStatus:@"Capture..." maskType:SVProgressHUDMaskTypeGradient];

	self.captureButton.enabled = NO;
	self.ivThumbnail.image = nil;
	
	[mData.ptpConnection operateSession:^(PtpIpSession *session){

		// シャッタースピード
		//     AUTO(0),
		//     1/8000, 1/6400, 1/5000, 1/4000, 1/3200,
		//     1/2500, 1/2000, 1/1600, 1/1250, 1/1000,
		//     1/800, 1/640, 1/500, 1/400, 1/320,
		//     1/250, 1/200, 1/160, 1/125, 1/100,
		//     1/80, 1/60, 1/50, 1/40, 1/30,
		//     1/25, 1/15, 1/13, 1/10, 10/75
		// [session setShutterSpeed: PtpIpRationalMake(1,400)]; // 1/400sec
		[session setShutterSpeed: PtpIpRationalMake(mShutterSpeed==0?0:1, mShutterSpeed)];
		
		// 露出補正値
		//     2000, 1700, 1300, 1000, 700, 300,
		//     0, -300, -700, -1000, -1300, -1700, -2000
		//[session setExposureBiasCompensation: 300]; // +1/3EV
		
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

		// set シャッターの音量
		[session setAudioVolume: mData.volumeLevel];
		
		 // This block is running at PtpConnection#gcd thread.
		 BOOL rtn = [session initiateCapture];
		 LOG(@"execShutter[rtn:%d]", rtn);
		 
		dispatch_async_main(^{
			self.captureButton.enabled = YES;
		});
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
	
	
	
	//[self.indicator stopAnimating];
	[SVProgressHUD dismiss];
}


- (IBAction)onThumbnailTouchUpIn:(id)sender
{
	// サムネイル画像を押したとき
	if (mData.tamaObject != nil) {
		// Goto Viewer View
		[self performSegueWithIdentifier:@"segViewer" sender:self];
	}
}

- (IBAction)onDisconnectTouchUpIn:(id)sender
{
	// Disconnect > を押したとき
	[self disconnect];
}

- (IBAction)onListTouchUpIn:(id)sender
{
	// List > を押したとき
	// Goto Model Viewer View
	[self performSegueWithIdentifier:@"segList" sender:self];
}


#pragma mark - Life cycle.

- (void)viewDidLoad
{
	[super viewDidLoad];
	LOG_FUNC
	
	AppDelegate * app = [UIApplication sharedApplication].delegate;
	mData = [app getDataObject];
	assert(mData != nil);
	
#if DEBUG_NO_DEVICE_TEST
#else
	// Ready to PTP/IP.
	[mData.ptpConnection setLoglevel:PTPIP_LOGLEVEL_WARN];
	// PtpIpEventListener delegates.
	[mData.ptpConnection setEventListener:self];
#endif
	
	//
	mShutterSpeed = 0;  //AUTO(0)
	mFilmIso = 0xFFFF;  //AUTOMATIC(0xFFFF)
	mWhiteBalance = PTPIP_WHITE_BALANCE_AUTOMATIC;
	
	//  通知受信の設定
	NSNotificationCenter*   nc = [NSNotificationCenter defaultCenter];
	//[nc addObserver:self selector:@selector(applicationDidEnterBackground) name:@"applicationDidEnterBackground" object:nil];
	[nc addObserver:self selector:@selector(applicationWillEnterForeground) name:@"applicationWillEnterForeground" object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	// Thumbnailコーナを丸くする
	[[self.ivThumbnail layer] setCornerRadius:20.0];
	[self.ivThumbnail setClipsToBounds:YES];
	
	self.batteryProgress.transform = CGAffineTransformMakeScale( 1.0f, 3.0f ); // 横方向に1倍、縦方向に3倍して表示する
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
	
	// サムネイル画像クリア
	//self.ivThumbnail.image = nil;
	//mData.tamaObject = nil;
	
#if DEBUG_NO_DEVICE_TEST
	//
#else
	// コネクト
	if ([mData.ptpConnection connected]) {
		[mData.ptpConnection operateSession:^(PtpIpSession *session) {
			// Get Volume level.
			mData.volumeLevel = [session getAudioVolume];
			// Get Battery level.
			mData.batteryLevel = [session getBatteryLevel];
			
			[self viewRefresh];
		}];
	}
	else {
		//[self connect];
		[self dismissViewControllerAnimated:YES completion:nil];
	}
#endif
}

@end
