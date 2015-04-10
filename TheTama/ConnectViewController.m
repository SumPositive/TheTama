//
//  ConnectViewController.m
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import "SVProgressHUD.h"

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
	// PTP/IP-Event callback.
	// This method is running at PtpConnection#gcd thread.
	switch (code) {
		default:
			NSLog(@"Event(0x%04x) received", code);
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
		NSLog(@"socket error(0x%X,closed=%@).\n--- %@", err, closed? @"YES": @"NO", desc);
		if (closed) {
			//[_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
			//[mData.tamaObjects removeAllObjects];
			//[_contentsView reloadData];
		}
	});
}


#pragma mark - PTP/IP Operations.

- (void)connect
{
	[SVProgressHUD showWithStatus:@"THETA\nConnecting..." maskType:SVProgressHUDMaskTypeGradient];

	self.buSetting.enabled = NO;
	self.buRetry.enabled = NO;

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
			
			// Goto Model Capture View
			[self performSegueWithIdentifier:@"segCapture" sender:self];
			
		} else {
			// "Connect" is failed.
			// "-(void)ptpip_socketError:(int)err" will run later than here.
			NSLog(@"connect failed.");
			// Retry after 5sec.
			
			
		}
		dispatch_async_main(^{
			[SVProgressHUD dismiss];
			self.buSetting.enabled = YES;
			self.buRetry.enabled = YES;
		});
	}];
}


#pragma mark - UI events.

- (IBAction)onSettingTouchUpIn:(id)sender
{
	// 設定画面へのURLスキーム
	NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
	[[UIApplication sharedApplication] openURL:url];
}

- (IBAction)onRetryTouchUpIn:(id)sender
{
	[self connect];
}


#pragma mark - Life cycle.

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	AppDelegate * app = [UIApplication sharedApplication].delegate;
	mData = [app getDataObject];
	assert(mData != nil);
	
	// Ready to PTP/IP.
	if (mData.ptpConnection==nil) {
		mData.ptpConnection = [[PtpConnection alloc] init];
	}
	[mData.ptpConnection setLoglevel:PTPIP_LOGLEVEL_WARN];
	[mData.ptpConnection setEventListener:self];
	
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
	
	[self connect];
}

@end
