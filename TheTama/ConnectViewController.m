//
//  ConnectViewController.m
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import <iAd/iAd.h>
//#import "SVProgressHUD.h"
#import "MRProgress.h"		// http://cocoadocs.org/docsets/MRProgress/0.2.2/

#import "Azukid.h"
#import "TheTama-Swift.h"
#import "Capture.h"

#import "ConnectViewController.h"
#import "PtpConnection.h"
#import "PtpLogging.h"


inline static void dispatch_async_main(dispatch_block_t block)
{
	dispatch_async(dispatch_get_main_queue(), block);
}

@interface ConnectViewController () <CaptureDelegate> //<PtpIpEventListener>
{
	DataObject *	mData;
	Capture *		mCapture;
}

@property (nonatomic, weak) IBOutlet UILabel * lbConnect;
@property (nonatomic, weak) IBOutlet UIButton * buSetting;
@property (nonatomic, weak) IBOutlet UIButton * buRetry;
@property (nonatomic, weak) IBOutlet ADBannerView * iAd;

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
		[self progressOff];
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
	
	LOG(@"socket error(0x%X,closed=%@).\n--- %@", err, closed? @"YES": @"NO", desc);
	if (closed) {
		//[mData.ptpConnection setEventListener:nil];
		
		dispatch_async_main(^{
			[self progressOff];
			//[self progressOnTitle:NSLocalizedString(@"Lz.Disconnect", nil)];
			//[self disconnect];
			//[SVProgressHUD dismiss];
			//[self progressOff];
		});
	}
}


#pragma mark - PTP/IP Operations.

//- (void)connect
//{
//	LOG_FUNC
//	//[SVProgressHUD showWithStatus:NSLocalizedString(@"Lz.Connecting",nil)
//	//					 maskType:SVProgressHUDMaskTypeGradient];
//
//	//	[MRProgressOverlayView showOverlayAddedTo:self.view
//	//										title:NSLocalizedString(@"Lz.Connecting", nil)
//	//										 mode:MRProgressOverlayViewModeIndeterminate
//	//									 animated:YES stopBlock:^(MRProgressOverlayView *progressOverlayView){
//	//		// STOP
//	//		[self progressOff];
//	//	}];
//
//	[self progressOnTitle:NSLocalizedString(@"Lz.Connecting", nil)];
//	
//	
//	self.buSetting.enabled = NO;
//	self.buRetry.enabled = NO;
//
//	assert(mData.ptpConnection);
//	// Ready to PTP/IP.
//	[mData.ptpConnection setLoglevel:PTPIP_LOGLEVEL_WARN];
//	[mData.ptpConnection setTimeLimitForResponse:PTP_TIMEOUT];
//	
//	// PtpIpEventListener delegates.
//	[mData.ptpConnection setEventListener:self]; //画面遷移の都度、デリゲート指定必須
//
//	// Setup `target IP`(camera IP).
//#if TARGET_IPHONE_SIMULATOR
//	[mData.ptpConnection setTargetIp: @"192.168.1.5"]; //SIMULATOR Wi-Fi
//#else
//	[mData.ptpConnection setTargetIp: @"192.168.1.1"]; //THETA DEF.
//#endif
//	
//	// Connect to target.
//	[mData.ptpConnection connect:^(BOOL connected) {
//		// "Connect" and "OpenSession" completion callback.
//		// This block is running at PtpConnection#gcd thread.
//		
//		if (connected) {
//			// "Connect" is succeeded.
//			mData.connected = true;
//			LOG(@"connected.");
//			LOG(@"  mData.ptpConnection.connected=%d", mData.ptpConnection.connected);
//			
//			// Goto Capture View
//			[self performSegueWithIdentifier:@"segCapture" sender:self];
//			
//		} else {
//			// "Connect" is failed.
//			mData.connected = false;
//			LOG(@"connect failed.");
//			// Retry after 5sec.
//#if TARGET_IPHONE_SIMULATOR
//			[self performSegueWithIdentifier:@"segCapture" sender:self];
//#endif
//		}
//		dispatch_async_main(^{
//			//[SVProgressHUD dismiss];
//			[self progressOff];
//			self.buSetting.enabled = YES;
//			self.buRetry.enabled = YES;
//		});
//	}];
//}
//
//- (void)disconnect:(BOOL)connect
//{
//	LOG_FUNC
//	[self progressOnTitle:NSLocalizedString(@"Lz.Connecting", nil)];
//	
//	[mData.ptpConnection close:^{
//		// "CloseSession" and "Close" completion callback.
//		// This block is running at PtpConnection#gcd thread.
//		dispatch_async_main(^{
//			LOG(@"disconnected.");
//			[self progressOff];
//			
//			if (connect) {
//				[self connect];
//			}
//		});
//	}];
//}

#pragma mark - <CaptureDelegate>

- (void)connected:(BOOL)result
{
	LOG_FUNC
	if (result) {
		// "Connect" is succeeded.
		// Goto Capture View
		[self performSegueWithIdentifier:@"segCapture" sender:self];
	}
	else {
		// "Connect" is failed.
#if TARGET_IPHONE_SIMULATOR
		[self performSegueWithIdentifier:@"segCapture" sender:self];
#endif
	}
	dispatch_async_main(^{
		self.buSetting.enabled = YES;
		self.buRetry.enabled = YES;
	});
}

- (void)disconnected
{
	LOG_FUNC
}

//- (void)captured:(BOOL)result thumb:(UIImage*)thumb
//{
//	LOG_FUNC
//}

- (void)strageFull
{
	LOG_FUNC
}

- (void)socketError
{
	LOG_FUNC
}


#pragma mark - UI events.

- (IBAction)onSettingTouchUpIn:(id)sender
{
	LOG_FUNC
	// 設定画面へのURLスキーム
	NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
	[[UIApplication sharedApplication] openURL:url];
	
	//iOS5以前//[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"prefs://"]];
}

- (IBAction)onRetryTouchUpIn:(id)sender
{
	LOG_FUNC
	[mCapture disconnect:YES];  //YES= Disconnectの後、Connectする
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


//#pragma mark - iAd delegate
//
////iAd取得成功
//- (void)bannerViewDidLoadAd:(ADBannerView *)banner
//{
//	NSLog(@"iAd取得成功");
//	self.iAd.hidden = NO;
//	//self.canDisplayBannerAds = NO;
//}
//
////iAd取得失敗
//- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error
//{
//	NSLog(@"iAd取得失敗");
//	self.iAd.hidden = YES;
//	//self.canDisplayBannerAds = YES;
//}


#pragma mark - Life cycle.

- (void)viewDidLoad
{
	[super viewDidLoad];
	LOG_FUNC
	
	AppDelegate * app = [UIApplication sharedApplication].delegate;
	mData = [app getDataObject];
	assert(mData != nil);
	
	mCapture = [app getCaptureObject];
	assert(mCapture != nil);
	

	// iAd
#if TARGET_IPHONE_SIMULATOR
	self.canDisplayBannerAds = NO;
	[self.iAd removeFromSuperview];
#else
	self.canDisplayBannerAds = YES;
	[UIViewController prepareInterstitialAds];
	self.interstitialPresentationPolicy = ADInterstitialPresentationPolicyAutomatic;
#endif

	//  通知受信の設定
	NSNotificationCenter*   nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(applicationWillEnterForeground) name:@"applicationWillEnterForeground" object:nil];
	[nc addObserver:self selector:@selector(applicationDidEnterBackground) name:@"applicationDidEnterBackground" object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	mCapture.delegate = self;
	mCapture.view = self.view;
	
	if (mData.option1payed) {
		self.canDisplayBannerAds = NO;
	}
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
#else
	[mCapture connectCompletion:nil];
#endif
}

- (void)applicationDidEnterBackground
{
	// 閉じるとき切断する、さもなくば他の(THETA純正)アプリから接続できない
	//[self disconnect:NO];
	[mCapture disconnect:NO];
}

@end
