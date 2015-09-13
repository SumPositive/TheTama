//
//  TheTaManager
//  TheTama
//
//  Created by masa on 2015/05/06.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import <objc/runtime.h>
#import "MRProgress.h"		// http://cocoadocs.org/docsets/MRProgress/0.2.2/

#import "Azukid.h"
//#import "TheTama-Swift.h"
#import "TheTaManager.h"

#define KEY_CONNECT_COMPLETION		@"KEY_CONNECT_COMPLETION"
#define KEY_CAPTURE_COMPLETION		@"KEY_CAPTURE_COMPLETION"


inline static void dispatch_async_main(dispatch_block_t block)
{
	dispatch_async(dispatch_get_main_queue(), block);
}

@interface TheTaManager() <PtpIpEventListener>
{
	//PtpConnection	*	_connection;
	NSInteger			mTransactionId;
}
@end


@implementation TheTaManager
//@synthesize connection = mConnection;
//@synthesize connected = mConnected;

/// Singleton 固有インスタンスを返す
+ (TheTaManager*)sharedInstance {
	static TheTaManager *singleton;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		singleton = [[TheTaManager alloc] initSharedInstance];
	});
	return singleton;
}

- (id)initSharedInstance {
	self = [super init];
	if (self) {

		_connection = [[PtpConnection alloc] init];
		_tamaObjects = [NSMutableArray new];
		
	}
	return self;
}

- (id)init {
	// alloc init するとエラー発生させる
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}



#pragma mark - PTP/IP Operations.

- (void)connectCompletion:(ConnectCompletion)completion
{
	LOG_FUNC
	assert(_connection);

	// completionオブジェクトを保持する
	objc_setAssociatedObject(self,
							 KEY_CONNECT_COMPLETION,
							 [completion copy],
							 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	//Progressなどのビュー表示は、ここでは禁止（Watch対応のため）
	//[self progressOnTitle:NSLocalizedString(@"Lz.Connecting", nil)];
	
	// Ready to PTP/IP.
	[_connection setLoglevel:PTPIP_LOGLEVEL_WARN];
	[_connection setTimeLimitForResponse:PTP_TIMEOUT];
	
	// PtpIpEventListener delegates.
	[_connection setEventListener:self]; //画面遷移の都度、デリゲート指定必須
	
	// Setup `target IP`(camera IP).
#if TARGET_IPHONE_SIMULATOR
	[_connection setTargetIp: @"192.168.1.5"]; //SIMULATOR Wi-Fi
#else
	[_connection setTargetIp: @"192.168.1.1"]; //THETA DEF.
#endif
	
	
	// Connect to target.
	[_connection connect:^(BOOL connected) {
		// "Connect" and "OpenSession" completion callback.
		// This block is running at PtpConnection#gcd thread.
		
		//[self progressOff];

		if (_isConnected) {
			// "Connect" is succeeded.
			_isConnected = true;
			LOG(@"connected.");
			LOG(@"  mData.ptpConnection.connected=%d", _connection.connected);
			
			[_connection operateSession:^(PtpIpSession *session) {

				// 充電レベル   FULL(100), HALF(67), NEAR_END(33), END(0)
				self.batteryLevel = [session getBatteryLevel];
				
				
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
				
				if (stillCaptureMode==0 || stillCaptureMode==PTPIP_STILL_CAPTURE_MODE_MOVIE) {
					self.captureMode = CAPTURE_MODE_MOVIE;
					
					// 動画記録時間(秒)(型番：RICOH THETA m15)
					NSUInteger recordingTime = [session getRecordingTime];
					LOG(@"recordingTime=%ld",(long)recordingTime);
					
					// 動画の残り記録時間（秒）(型番：RICOH THETA m15)
					NSUInteger remainingRecordingTime = [session getRemainingRecordingTime];
					LOG(@"remainingRecordingTime=%ld",(long)remainingRecordingTime);
				}
				else if	(stillCaptureMode==PTPIP_STILL_CAPTURE_MODE_TIMELAPSE) {
					self.captureMode = CAPTURE_MODE_TIMELAPSE;
					// インターバル撮影の上限枚数
					//     0(上限なし), 2-65535
					NSInteger timelapseNumber = [session getTimelapseNumber];
					LOG(@"timelapseNumber=%ld",(long)timelapseNumber);
					
					// インターバル撮影の撮影間隔
					//     5000-3600000 msec
					NSInteger timelapseInterval= [session getTimelapseInterval];
					LOG(@"timelapseInterval=%ld",(long)timelapseInterval);
				}
				else {
					self.captureMode = CAPTURE_MODE_NORMAL;
				}
				
				if ([self.delegate respondsToSelector:@selector(connected:)]) {
					[self.delegate connected:YES];
				}
			}];
		}
		else {
			// "Connect" is failed.
			_isConnected = false;
			LOG(@"connect failed.");
			if ([self.delegate respondsToSelector:@selector(connected:)]) {
				[self.delegate connected:NO];
			}
		}
		
		// completionオブジェクトを取得する
		ConnectCompletion completion = objc_getAssociatedObject(self, KEY_CONNECT_COMPLETION);
		if (completion) {
			completion(_isConnected, nil);
		}
		
		
	}];
}

- (void)disconnect:(BOOL)connect
{
	LOG_FUNC
	[self progressOnTitle:NSLocalizedString(@"Lz.Connecting", nil)];
	
	[_connection close:^{
		// "CloseSession" and "Close" completion callback.
		// This block is running at PtpConnection#gcd thread.
		LOG(@"disconnected.");
		
		[self progressOff];
		
		if (connect) {
			[self connectCompletion:nil];
		}
		else {
			if ([self.delegate respondsToSelector:@selector(disconnected)]) {
				[self.delegate disconnected];
			}
		}
	}];
}


- (void)captureCompletion:(CaptureCompletion)completion
{
	// completionオブジェクトを保持する
	objc_setAssociatedObject(self,
							 KEY_CAPTURE_COMPLETION,
							 [completion copy],
							 OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	
	//Progressなどのビュー表示は、ここでは禁止（Watch対応のため）
	switch (self.captureMode) {
		case CAPTURE_MODE_NORMAL:
		{
			[self progressOnTitle:NSLocalizedString(@"During 360° Capture.", nil)];
		}	break;
			
		case CAPTURE_MODE_TIMELAPSE:
		{
			[MRProgressOverlayView showOverlayAddedTo:self.view
												title:NSLocalizedString(@"During timelapse shooting.",nil)
												 mode:MRProgressOverlayViewModeIndeterminate
											 animated:YES
											stopBlock:^(MRProgressOverlayView *progressOverlayView) {
												// STOP処理
												[self progressOff];
												[self progressOnTitle:NSLocalizedString(@"Saveing...", nil)];
												[_connection operateSession:^(PtpIpSession *session){
													BOOL result = [session terminateOpenCapture: mTransactionId];
													LOG(@"terminateOpenCapture: result=%d", result);
													if (completion) {
														completion(YES, nil, nil, nil);
													}
												}];
												return;
											}];
		}	break;
			
		case CAPTURE_MODE_MOVIE:
		{
			[MRProgressOverlayView showOverlayAddedTo:self.view
												title:NSLocalizedString(@"During movie shooting.",nil)
												 mode:MRProgressOverlayViewModeIndeterminate
											 animated:YES
											stopBlock:^(MRProgressOverlayView *progressOverlayView) {
												// STOP処理
												[self progressOff];
												[self progressOnTitle:NSLocalizedString(@"Saveing...", nil)];
												[_connection operateSession:^(PtpIpSession *session){
													BOOL result = [session terminateOpenCapture: mTransactionId];
													LOG(@"terminateOpenCapture: result=%d", result);
													if (completion) {
														completion(YES, nil, nil, nil);
													}
												}];
												return;
											}];
		}	break;
			
		default:
			break;
	}
	
	[_connection operateSession:^(PtpIpSession *session){
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
		if (self.shutterSpeed < 7) {
			[session setShutterSpeed: PtpIpRationalMake(0,0)]; // Auto
		} else if (self.shutterSpeed < 10) {
			[session setShutterSpeed: PtpIpRationalMake(10,75)]; // 10/75 = 1/7.5
		} else {
			[session setShutterSpeed: PtpIpRationalMake(1,self.shutterSpeed)];
		}
		
		// ISO感度
		//     100, 125, 160, 200, 250, 320, 400, 500, 640,
		//     800, 1000, 1250, 1600,
		//     AUTOMATIC(0xFFFF)
		// [session setExposureIndex: 100]; // ISO100
		[session setExposureIndex: self.filmIso];
		
		// ホワイトバランス
		//     AUTOMATIC, DAYLIGHT(屋外), SHADE(日陰), CLOUDY(曇天),
		//     TUNGSTEN1(白熱灯1),  TUNGSTEN2(白熱灯2),
		//     FLUORESCENT1(蛍光灯1(昼光色)), FLUORESCENT2(蛍光灯2(昼白色)),
		//     FLUORESCENT3(蛍光灯3(白色)), FLUORESCENT4(蛍光灯4(電球色))
		// [session setWhiteBalance: PTPIP_WHITE_BALANCE_DAYLIGHT]; // 屋外
		[session setWhiteBalance: self.whiteBalance];
		
		// 露出補正値
		//     2000, 1700, 1300, 1000, 700, 300,
		//     0, -300, -700, -1000, -1300, -1700, -2000
		//[session setExposureBiasCompensation: 300]; // +1/3EV
		[session setExposureBiasCompensation: 0];
		
		// set シャッターの音量
		[session setAudioVolume: self.volumeLevel];
		
		switch (self.captureMode) {
			case CAPTURE_MODE_NORMAL:
			{
				BOOL rtn = [session initiateCapture]; //---> PtpIpEventListener delegates.
				LOG(@"execShutter[rtn:%d]", rtn);
				
				if (!rtn) {
					// NG
					if (completion) {
						completion(NO, nil, nil, nil);
					}
				}
			}	break;
				
			case CAPTURE_MODE_TIMELAPSE:
			{
				mTransactionId = [session initiateOpenCapture];
				LOG(@"mTransactionId:%ld", mTransactionId);
			}	break;
				
			case CAPTURE_MODE_MOVIE:
			{
				mTransactionId = [session initiateOpenCapture];
				LOG(@"mTransactionId:%ld", mTransactionId);
			}	break;
				
			default:
				break;
		}
	}];
}



//- (void)imageThumbnail:(uint32_t)objectHandle session:(PtpIpSession*)session
- (UIImage *)imageThumbnail:(uint32_t)objectHandle session:(PtpIpSession*)session
{
	LOG_FUNC
	// This method MUST be running at PtpConnection#gcd thread.
	
	//	mData.tamaCapture = nil;
	
	// Get object informations.
	// It containes filename, capture-date and etc.
	PtpIpObjectInfo* objectInfo = [session getObjectInfo:objectHandle];
	if (!objectInfo) {
		LOG(@"getObjectInfo(0x%08x) failed.", objectHandle);
		//mData.tamaObjectHandle = 0;
		return nil;
	}
	
	//UIImage* thumb = mImageThumb;
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
		if (result) {
			// OK
			return [UIImage imageWithData:thumbData];
		} else {
			LOG(@"getThumb(0x%08x) failed.", objectHandle);
		}
	}
	return nil;
}



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
			
		case PTPIP_DEVICE_PROP_CHANGED:
		{	// デバイスのプロパティに変化あり
			return;
		} break;
			
		case PTPIP_CAPTURE_COMPLETE:
		{	// 撮影が完了した際に呼び出される
//			dispatch_async_main(^{
//				//[self progressOff];
//				[self viewRefresh];
//			});
		} break;
			
		case PTPIP_OBJECT_ADDED:
		{	// 撮影などを行った際にオブジェクトが作成された際に呼び出される
			LOG(@"Object added Event(0x%04x) - 0x%08x", code, param1);
			[_connection operateSession:^(PtpIpSession *session) {
				NSDate * capture_date = nil;
				PtpIpObjectInfo* objectInfo = [session getObjectInfo:param1];
				if (objectInfo) {
					capture_date = objectInfo.capture_date; //撮影日時
				}
				// サムネイルを取得し、表示する
				// completionオブジェクトを取得する
				CaptureCompletion completion = objc_getAssociatedObject(self, KEY_CAPTURE_COMPLETION);
				if (completion) {
					completion(YES, [self imageThumbnail:param1 session:session], capture_date, nil);
				}
			}];
		} break;
			
		case PTPIP_STORE_FULL:
		{	// ストレージFULL
			if ([self.delegate respondsToSelector:@selector(strageFull)]) {
				[self.delegate strageFull];
			}
			return;
		} break;
	}
	
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
	[_connection setEventListener:nil];
	
	[self progressOff];

	if ([self.delegate respondsToSelector:@selector(socketError)]) {
		[self.delegate socketError];
	}
}


#pragma mark - UI events.

- (void)progressOnTitle:(NSString*)zTitle
{
	assert(self.view);
	dispatch_async_main(^{
		if (zTitle) {
			[MRProgressOverlayView showOverlayAddedTo:self.view
												title:zTitle	// nil だと落ちる
												 mode:MRProgressOverlayViewModeIndeterminate
											 animated:YES];
		} else {
			[MRProgressOverlayView showOverlayAddedTo:self.view animated:YES];
		}
	});
}

- (void)progressOff
{
	assert(self.view);
	dispatch_async_main(^{
		[MRProgressOverlayView dismissOverlayForView:self.view animated:YES];
	});
}



@end
