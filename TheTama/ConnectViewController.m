//
//  ConnectViewController.m
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import <iAd/iAd.h>
#import "TheTamaBase.h"



@interface ConnectViewController () <TheTaManagerDelegate>
{
	//__weak IBOutlet UILabel*		_lbConnect;
	__weak IBOutlet UIButton*		_buSetting;
	__weak IBOutlet UIButton*		_buRetry;
	__weak IBOutlet ADBannerView*	_iAd;
	
	//DataObject *	mData;
	//Capture *		mCapture;
}
@end


@implementation ConnectViewController



//-------------------------------------------------------------
#pragma mark - Public Life cycle.

- (void)viewDidLoad
{
	[super viewDidLoad];
	LOG_FUNC
	self.navigationController.navigationBarHidden = YES; //ナビバー非表示
	
//	AppDelegate * app = [UIApplication sharedApplication].delegate;
//	mData = [app getDataObject];
//	assert(mData != nil);
	
	//	mCapture = [app getCaptureObject];
	//	assert(mCapture != nil);
	
	
	// iAd
#if TARGET_IPHONE_SIMULATOR
	self.canDisplayBannerAds = NO;
	[_iAd removeFromSuperview];
#else
	self.canDisplayBannerAds = YES;
	[UIViewController prepareInterstitialAds];
	self.interstitialPresentationPolicy = ADInterstitialPresentationPolicyAutomatic;
#endif
	
	//  通知受信の設定
	NSNotificationCenter*   nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(applicationWillEnterForeground) name:@"applicationWillEnterForeground" object:nil];
	[nc addObserver:self selector:@selector(applicationDidEnterBackground) name:@"applicationDidEnterBackground" object:nil];

	//全ボタン設置後、ボタン同時押し対策する
	[Azukid banMultipleTouch:self.view];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[TheTaManager sharedInstance].delegate = self;
	[TheTaManager sharedInstance].progressBlockView = self.view;
	
	if ([[[TheTaManager sharedInstance] dataObject] option1payed]) {
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
	[[TheTaManager sharedInstance] connectCompletion:nil];
#endif
}

- (void)applicationDidEnterBackground
{
	// 閉じるとき切断する、さもなくば他の(THETA純正)アプリから接続できない
	//[self disconnect:NO];
	[[TheTaManager sharedInstance] disconnect:NO];
}


//-------------------------------------------------------------
#pragma mark - Public other.



//-------------------------------------------------------------
#pragma mark - UI events.

- (IBAction)onSettingTouchUpIn:(id)sender
{
	LOG_FUNC
	[Azukid banBarrage:sender];//連打対策
	// 設定画面へのURLスキーム
	NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
	[[UIApplication sharedApplication] openURL:url];
	
	//iOS5以前//[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"prefs://"]];
}

- (IBAction)onRetryTouchUpIn:(id)sender
{
	LOG_FUNC
	[Azukid banBarrage:sender];//連打対策
	[[TheTaManager sharedInstance] disconnect:YES];  //YES= Disconnectの後、Connectする
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


//-------------------------------------------------------------
#pragma mark - Private



//-------------------------------------------------------------
#pragma mark - <TheTaManagerDelegate>

- (void)connected:(BOOL)succeeded
{
	LOG_FUNC
	if (succeeded) {
		// "Connect" is succeeded.
		dispatch_async_main(^{
			// Goto Capture View
			CaptureViewController* vc = [[CaptureViewController alloc] init];
			[self.navigationController pushViewController:vc animated:YES];
		});
	}
	else {
		// "Connect" is failed.
#if TARGET_IPHONE_SIMULATOR
		//[self performSegueWithIdentifier:@"segCapture" sender:self];
#endif
	}
	dispatch_async_main(^{
		_buSetting.enabled = YES;
		_buRetry.enabled = YES;
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


//-------------------------------------------------------------
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


@end
