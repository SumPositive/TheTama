//
//  CaptureViewController.m
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import "TheTama-Swift.h"
#import "CaptureViewController.h"
#import "PtpConnection.h"
#import "PtpLogging.h"
#import "PtpObject.h"
#import "TableCell.h"


inline static void dispatch_async_main(dispatch_block_t block)
{
	dispatch_async(dispatch_get_main_queue(), block);
}

@interface CaptureViewController () <PtpIpEventListener, UITableViewDelegate, UITableViewDataSource>
{
	DataObject * mData;
}
@property (nonatomic, strong) IBOutlet UILabel * batteryLabel;
@property (nonatomic, strong) IBOutlet UIProgressView * batteryProgress;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView * indicator;
@property (nonatomic, strong) IBOutlet UIButton * captureButton;
@property (nonatomic, strong) IBOutlet UITableView * contentsView;
@end


@implementation CaptureViewController

#pragma mark - PtpIpEventListener delegates.

-(void)ptpip_eventReceived:(int)code :(uint32_t)param1 :(uint32_t)param2 :(uint32_t)param3
{
	// PTP/IP-Event callback.
	// This method is running at PtpConnection#gcd thread.
	switch (code) {
		default:
			NSLog(@"Event(0x%04x) received", code);
			break;
			
		case PTPIP_OBJECT_ADDED:
		{
			// It will be receive when the camera has taken a new photo.
			NSLog(@"Object added Event(0x%04x) - 0x%08x", code, param1);
			
			[mData.ptpConnection operateSession:^(PtpIpSession *session) {
				[mData.tamaObjects addObject:[self loadObject:param1 session:session]];
				NSIndexPath* pos = [NSIndexPath indexPathForRow:mData.tamaObjects.count-1 inSection:1];
				dispatch_async_main(^{
					[_contentsView beginUpdates];
					[_contentsView insertRowsAtIndexPaths:@[pos]
										 withRowAnimation:UITableViewRowAnimationRight];
					[_contentsView endUpdates];
				});
				// Get Battery level.
				mData.batteryLevel = [session getBatteryLevel];
				[self viewRefresh];
			}];
		}
			break;
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
	
	dispatch_async_main(^{
		NSLog(@"socket error(0x%X,closed=%@).\n--- %@", err, closed? @"YES": @"NO", desc);
		if (closed) {
			//[_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
			[mData.tamaObjects removeAllObjects];
			[_contentsView reloadData];
		}
	});
}


#pragma mark - UI events.

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
	_captureButton.enabled = NO;
	[mData.ptpConnection operateSession:^(PtpIpSession *session)
	 {
		 // シャッターの音量
		 // Set Volume level.
		 [session setAudioVolume: mData.volumeLevel];
		 
		 // This block is running at PtpConnection#gcd thread.
		 BOOL rtn = [session initiateCapture];
		 NSLog(@"execShutter[rtn:%d]", rtn);

		 _captureButton.enabled = YES;
	 }];
}

- (void)viewRefresh
{
	// バッテリー残量
	self.batteryLabel.text = [NSString stringWithFormat:@"%ld%%", mData.batteryLevel];
	float ff = (float)mData.batteryLevel / 100.0;
	if (ff < 0.2) {
		self.batteryProgress.progressTintColor = [UIColor redColor];
	}
	else if (ff < 0.5) {
		self.batteryProgress.progressTintColor = [UIColor yellowColor];
	}
	else {
		self.batteryProgress.progressTintColor = [UIColor blueColor];
	}
	self.batteryProgress.progress = ff;
	
}


#pragma mark - PTP/IP Operations.

- (void)connect
{
	_captureButton.enabled = NO;
	[self.indicator startAnimating];
	
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
			NSLog(@"connected.");
			
			// Start enum objects.
			[self enumObjects];
			
			_captureButton.enabled = YES;
			
		} else {
			// "Connect" is failed.
			// "-(void)ptpip_socketError:(int)err" will run later than here.
			NSLog(@"connect failed.");
			
			// アラート表示
			UIAlertController *alertController = [UIAlertController
												  alertControllerWithTitle:@""
												  message:@"設定 ＞ Wi-Fi ＞ THETAxxxxxxx に接続してください。"
												  preferredStyle:UIAlertControllerStyleAlert];
			[alertController addAction:[UIAlertAction
										actionWithTitle:@"設定"
										style:UIAlertActionStyleDefault
										handler:^(UIAlertAction *action)
										{
											// 設定画面へのURLスキーム
											NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
											[[UIApplication sharedApplication] openURL:url];
										}]];
			[alertController addAction:[UIAlertAction
										actionWithTitle:@"再接続"
										style:UIAlertActionStyleCancel
										handler:^(UIAlertAction *action)
										{
											// Retry
											[self connect];
										}]];
			[self presentViewController:alertController animated:YES completion:nil];
			
		}
		dispatch_async_main(^{
			[self.indicator stopAnimating];
		});
	}];
}

//- (void)disconnect
//{
//	NSLog(@"disconnecting...");
//	
//	[mData.ptpConnection close:^{
//		// "CloseSession" and "Close" completion callback.
//		// This block is running at PtpConnection#gcd thread.
//		
//		dispatch_async_main(^{
//			NSLog(@"disconnected.");
//			//[self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];
//			[mData.tamaObjects removeAllObjects];
//		});
//	}];
//}

- (void)enumObjects
{
	assert([mData.ptpConnection connected]);
	assert(mData.tamaObjects != nil);

	[self.indicator startAnimating];
	[mData.tamaObjects removeAllObjects];
	
	[mData.ptpConnection operateSession:^(PtpIpSession *session) {
		// This block is running at PtpConnection#gcd thread.
		
		// Setting the RICOH THETA's clock.
		// 'setDateTime' convert from specified date/time to local-time, and send to RICOH THETA.
		// RICOH THETA work with local-time, without timezone.
		[session setDateTime:[NSDate dateWithTimeIntervalSinceNow:0]];
		
		// Get storage information.
		mData.storageInfo = [session getStorageInfo];
		
		// Get Battery level.
		mData.batteryLevel = [session getBatteryLevel];
		
		// Set Volume level.
		[session setAudioVolume: mData.volumeLevel];

		
		// Get object handles for primary images.
		NSArray* objectHandles = [session getObjectHandles];
		dispatch_async_main(^{
			NSLog(@"getObjectHandles() recevied %zd handles.", objectHandles.count);
		});
		
		// Get object informations and thumbnail images for each primary images.
		for (NSNumber* it in objectHandles) {
			uint32_t objectHandle = (uint32_t)it.integerValue;
			[mData.tamaObjects addObject:[self loadObject:objectHandle session:session]];
		}
		dispatch_async_main(^{
			[_contentsView reloadData];
			[self viewRefresh];
			[self.indicator stopAnimating];
		});
	}];
}

- (PtpObject*)loadObject:(uint32_t)objectHandle session:(PtpIpSession*)session
{
	// This method MUST be running at PtpConnection#gcd thread.
	
	// Get object informations.
	// It containes filename, capture-date and etc.
	PtpIpObjectInfo* objectInfo = [session getObjectInfo:objectHandle];
	if (!objectInfo) {
		dispatch_async_main(^{
			NSLog(@"getObjectInfo(0x%08x) failed.", objectHandle);
		});
		return nil;
	}
	
	UIImage* thumb;
	if (objectInfo.object_format==PTPIP_FORMAT_JPEG) {
		// Get thumbnail image.
		NSMutableData* thumbData = [NSMutableData data];
		BOOL result = [session getThumb:objectHandle
							onStartData:^(NSUInteger totalLength) {
								// Callback before thumb-data reception.
								NSLog(@"getThumb(0x%08x) will received %zd bytes.", objectHandle, totalLength);
								
							} onChunkReceived:^BOOL(NSData *data) {
								// Callback for each chunks.
								[thumbData appendData:data];
								
								// Continue to receive.
								return YES;
							}];
		if (!result) {
			dispatch_async_main(^{
				NSLog(@"getThumb(0x%08x) failed.", objectHandle);
			});
			thumb = [UIImage imageNamed:@"nothumb.png"];
		} else {
			thumb = [UIImage imageWithData:thumbData];
		}
	} else {
		thumb = [UIImage imageNamed:@"nothumb.png"];
	}
	return [[PtpObject alloc] initWithObjectInfo:objectInfo thumbnail:thumb];
}




#pragma mark - UITableViewDataSource delegates.

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section==0) {
		return [mData.ptpConnection connected] ? 1: 0;
	}
	return mData.tamaObjects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
	TableCell* cell;
	
	if (indexPath.section==0) {
		cell = [tableView dequeueReusableCellWithIdentifier:@"cameraInfo"];
		cell.textLabel.text = [NSString stringWithFormat:@"%d[shots] %lld/%lld[MB] free",
							   mData.storageInfo.free_space_in_images,
							   mData.storageInfo.free_space_in_bytes/1000/1000,
							   mData.storageInfo.max_capacity/1000/1000];
		cell.detailTextLabel.text = [NSString stringWithFormat:@"BATT %zd %%", mData.batteryLevel];
	} else {
		// NSDateFormatter to display photographing date.
		// You MUST specify `[df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]`
		// to display photographing date('PtpIpObjectInfo#capture_date') in the local time.
		// As a result, 'PtpIpObjectInfo#capture_date' and 'kCGImagePropertyExifDateTimeOriginal' will match.
		NSDateFormatter* df = [[NSDateFormatter alloc] init];
		[df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
		[df setDateStyle:NSDateFormatterShortStyle];
		[df setTimeStyle:NSDateFormatterMediumStyle];
		
		PtpObject* obj = [mData.tamaObjects objectAtIndex:indexPath.row];
		cell = [tableView dequeueReusableCellWithIdentifier:@"customCell"];
		cell.textLabel.text = [df stringFromDate:obj.objectInfo.capture_date];
		cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", obj.objectInfo.filename];
		cell.imageView.image = obj.thumbnail;
		cell.objectIndex = (uint32_t)indexPath.row;
	}
	return cell;
}

#pragma mark - Life cycle.

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	AppDelegate * app = [UIApplication sharedApplication].delegate;
	mData = [app getDataObject];
	assert(mData != nil);

	_contentsView.dataSource = self;
	
	// Ready to PTP/IP.
	if (mData.ptpConnection==nil) {
		mData.ptpConnection = [[PtpConnection alloc] init];
	}
	[mData.ptpConnection setLoglevel:PTPIP_LOGLEVEL_WARN];
	[mData.ptpConnection setEventListener:self];
	
	if (mData.tamaObjects==nil) {
		mData.tamaObjects = [NSMutableArray new];
	}
	
	//  通知受信の設定
	NSNotificationCenter*   nc = [NSNotificationCenter defaultCenter];
	//[nc addObserver:self selector:@selector(applicationDidEnterBackground) name:@"applicationDidEnterBackground" object:nil];
	[nc addObserver:self selector:@selector(applicationWillEnterForeground) name:@"applicationWillEnterForeground" object:nil];

}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	self.batteryProgress.transform = CGAffineTransformMakeScale( 1.0f, 5.0f ); // 横方向に1倍、縦方向に3倍して表示する
	[self viewRefresh];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	[self applicationWillEnterForeground];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

//2回目以降のフォアグラウンド実行になった際に呼び出される(Backgroundにアプリがある場合)
- (void)applicationWillEnterForeground
{
	NSLog(@"applicationWillEnterForeground");

	[mData.ptpConnection setLoglevel:PTPIP_LOGLEVEL_WARN];

	if ([mData.ptpConnection connected]) {
		_captureButton.enabled = YES;
	} else {
		_captureButton.enabled = NO;
		[self connect];
	}
}


@end
