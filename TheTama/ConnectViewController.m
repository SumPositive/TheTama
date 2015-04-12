//
//  ConnectViewController.m
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import "SVProgressHUD.h"
#import <iAd/iAd.h>
#import "Azukid.h"

#import "TheTama-Swift.h"
#import "ConnectViewController.h"
#import "PtpConnection.h"
#import "PtpLogging.h"



inline static void dispatch_async_main(dispatch_block_t block)
{
	dispatch_async(dispatch_get_main_queue(), block);
}

@interface ConnectViewController () <PtpIpEventListener>
{
	DataObject * mData;
}

@property (nonatomic, strong) IBOutlet UILabel * lbConnect;
@property (nonatomic, strong) IBOutlet UIButton * buSetting;
@property (nonatomic, strong) IBOutlet UIButton * buRetry;

@end


@implementation ConnectViewController



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
			
	}
	dispatch_async_main(^{
		[SVProgressHUD dismiss];
		
	});
}

-(void)ptpip_socketError:(int)err
{
	LOG_FUNC
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
	});
}


#pragma mark - PTP/IP Operations.

- (void)connect
{
	LOG_FUNC
	[SVProgressHUD showWithStatus:@"THETA\nConnecting..." maskType:SVProgressHUDMaskTypeGradient];

	self.buSetting.enabled = NO;
	self.buRetry.enabled = NO;

	// Setup `target IP`(camera IP).
	// Product default is "192.168.1.1".
	[mData.ptpConnection setTargetIp: @"192.168.1.1"]; // _ipField.text];
	
	assert(mData.ptpConnection);
	// Connect to target.
	[mData.ptpConnection connect:^(BOOL connected) {
		// "Connect" and "OpenSession" completion callback.
		// This block is running at PtpConnection#gcd thread.
		
		if (connected) {
			// "Connect" is succeeded.
			LOG(@"connected.");
			
			// Goto Capture View
			[self performSegueWithIdentifier:@"segCapture" sender:self];
			
		} else {
			// "Connect" is failed.
			// "-(void)ptpip_socketError:(int)err" will run later than here.
			LOG(@"connect failed.");
			// Retry after 5sec.
#if DEBUG_NO_DEVICE_TEST
			[self performSegueWithIdentifier:@"segCapture" sender:self];
#endif
		}
		dispatch_async_main(^{
			[SVProgressHUD dismiss];
			self.buSetting.enabled = YES;
			self.buRetry.enabled = YES;
		});
	}];
}

- (void)disconnect
{
	LOG_FUNC
	
	[mData.ptpConnection close:^{
		// "CloseSession" and "Close" completion callback.
		// This block is running at PtpConnection#gcd thread.
		
		dispatch_async_main(^{
			LOG(@"disconnected.");
			//[self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];
			//[mData.tamaObjects removeAllObjects];
		});
	}];
}


#pragma mark - UI events.

- (IBAction)onSettingTouchUpIn:(id)sender
{
	LOG_FUNC
	// 設定画面へのURLスキーム
	NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
	[[UIApplication sharedApplication] openURL:url];
}

- (IBAction)onRetryTouchUpIn:(id)sender
{
	LOG_FUNC
	[self connect];
}


#pragma mark - Life cycle.

- (void)viewDidLoad
{
	[super viewDidLoad];
	LOG_FUNC
	
	AppDelegate * app = [UIApplication sharedApplication].delegate;
	mData = [app getDataObject];
	assert(mData != nil);
	assert(mData.ptpConnection != nil);
	
#if DEBUG_NO_DEVICE_TEST
#else
	// Ready to PTP/IP.
	[mData.ptpConnection setLoglevel:PTPIP_LOGLEVEL_WARN];
	// PtpIpEventListener delegates.
	[mData.ptpConnection setEventListener:self];
#endif
	
	// iAd
	self.canDisplayBannerAds = YES;
	
	//  通知受信の設定
	NSNotificationCenter*   nc = [NSNotificationCenter defaultCenter];
	//[nc addObserver:self selector:@selector(applicationDidEnterBackground) name:@"applicationDidEnterBackground" object:nil];
	[nc addObserver:self selector:@selector(applicationWillEnterForeground) name:@"applicationWillEnterForeground" object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
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
	[self connect];
}

@end
