//
//  CaptureViewController.m
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "TheTamaBase.h"



@interface CaptureViewController () <TheTaManagerDelegate>
{
	__weak IBOutlet UISegmentedControl* _segShutter1;
	__weak IBOutlet UISegmentedControl* _segShutter2;
	__weak IBOutlet UISegmentedControl* _segIso;
	__weak IBOutlet UISegmentedControl* _segWhite1;
	__weak IBOutlet UISegmentedControl* _segWhite2;
	
	__weak IBOutlet UILabel *			_lbBatteryPer;
	__weak IBOutlet UIProgressView *	_progBattery;
	__weak IBOutlet UILabel  *			_lbVolumePer;
	__weak IBOutlet UISlider *			_sliderVolume;
	__weak IBOutlet UIImageView *		_ivThumbnail;
	__weak IBOutlet UILabel  *			_lbThumbnail;
	__weak IBOutlet UIButton *			_buThumbnail;
	__weak IBOutlet UIButton *			_buCapture;
	__weak IBOutlet UISwitch *			_swPreview;

	
	DataObject*		_dataObject;
	//TheTaManager*	mCapture;
	
	NSUInteger		mShutterSpeed;
	NSInteger		mFilmIso;
	NSInteger		mWhiteBalance;
	CAPTURE_MODE	mCaptureMode;
	NSInteger		mTransactionId;
	UIImage*		mImageThumb;
	NSTimer*		mTimerCheck;
}


@end


@implementation CaptureViewController

//-------------------------------------------------------------
#pragma mark - Public life cycle.

- (void)viewDidLoad
{
	[super viewDidLoad];
	LOG_FUNC
	self.navigationController.navigationBarHidden = YES; //ナビバー非表示
	
	AppDelegate * app = [UIApplication sharedApplication].delegate;
	_dataObject = [app getDataObject];
	assert(_dataObject != nil);
	
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
	[[_ivThumbnail layer] setCornerRadius: _ivThumbnail.frame.size.height / 3.0];
	[_ivThumbnail setClipsToBounds:YES];
	
	_lbThumbnail.text = nil;
	
	// 監視タイマー生成
	//	mTimerCheck = [NSTimer	scheduledTimerWithTimeInterval:5.0f
	//												   target:self
	//												 selector:@selector(timerCheck:)
	//												 userInfo:nil
	//												  repeats:YES ];
	
	mTimerCheck = [NSTimer timerWithTimeInterval:6.0f target:self selector:@selector(timerCheck:) userInfo:nil repeats:YES];
	
	//全ボタン設置後、ボタン同時押し対策する
	[Azukid banMultipleTouch:self.view];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	//	mCapture.delegate = self;
	//	mCapture.view = self.view;
	[TheTaManager sharedInstance].delegate = self;
	[TheTaManager sharedInstance].progressBlockView = self.view;
	
	//_progBattery.transform = CGAffineTransformMakeScale( 1.0f, 3.0f ); // 横方向に1倍、縦方向に3倍して表示する
	//	[UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
	//		_progBattery.transform = CGAffineTransformMakeScale( 1.0f, 0.0f );
	//	} completion:^(BOOL finished) {
	//		_progBattery.transform = CGAffineTransformMakeScale( 1.0f, 3.0f );
	//	}];
	
	_segShutter1.selectedSegmentIndex = 0;
	_segShutter2.selectedSegmentIndex = UISegmentedControlNoSegment;
	_segIso.selectedSegmentIndex = 0;
	_segWhite1.selectedSegmentIndex = 0;
	_segWhite2.selectedSegmentIndex = UISegmentedControlNoSegment;
	
	_dataObject.capturePreview = YES; //常にYES: プレビューOFFにしてもレスポンス変わらず廃案とした
	_swPreview.on = _dataObject.capturePreview;
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
	_dataObject.volumeLevel = 33; // TEST Dummy.
	//_dataObject.batteryLevel = 88; // TEST Dummy.
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
		dispatch_async_main(^{
			// ConnectView
			[self.navigationController popToRootViewControllerAnimated:YES];
		});
		return;
	}
#endif
	
}

//-------------------------------------------------------------
#pragma mark - Public methods.


//#pragma mark - <CaptureDelegate>
//
//- (void)connected:(BOOL)result
//{
//	LOG_FUNC
//	[self progressOff];
//}
//
//- (void)disconnected
//{
//	LOG_FUNC
//}

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
//			_buCapture.enabled = YES;
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
		// ConnectView
		[self.navigationController popToRootViewControllerAnimated:YES];
	});
}


//-------------------------------------------------------------
#pragma mark - Private UI events.

- (IBAction)volumeSliderChanged:(UISlider*)sender
{
	_dataObject.volumeLevel = sender.value;
	[self volumeShow];
}
- (void)volumeShow
{
	_sliderVolume.value = _dataObject.volumeLevel;
	_lbVolumePer.text = [NSString stringWithFormat:@"%ld%%", (long)_dataObject.volumeLevel];
}

- (IBAction)onCaptureTouchDown:(id)sender
{
	[Azukid banBarrage:sender]; //連打防止
	// シャッターボタンを押したとき撮影
	if (_dataObject.captureTouchDown) {
		[self capture];
	}
}

- (IBAction)onCaptureTouchUpInside:(id)sender
{
	[Azukid banBarrage:sender]; //連打防止
	// シャッターボタンを離したとき撮影
	if (!_dataObject.captureTouchDown) {
		[self capture];
	}
}

- (void)capture
{
	[[TheTaManager sharedInstance] captureCompletion:^(BOOL success, PtpObject* tamaObj, NSDate* capture_date, NSError* error) {
		if (success || !error) {
			//OK
			if (0 < _dataObject.tamaObjects.count) {
				[_dataObject.tamaObjects addObject:tamaObj];
			}
			LOG(@"_dataObject.tamaObjects.count=%ld", (unsigned long)_dataObject.tamaObjects.count);
			_dataObject.tamaCapture = tamaObj;
			_dataObject.listBottom = YES; // ListViewにて最終行を表示させる
		} else {
			LOG(@"[ERROR] %@", error.localizedDescription);
		}
	}];
}

- (void)viewRefresh
{
	dispatch_async_main(^{
		_buCapture.enabled = YES;
		
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
	_lbBatteryPer.text = [NSString stringWithFormat:@"%ld%%", (unsigned long)thetama.batteryLevel];
	float ff = (float)thetama.batteryLevel / 100.0;
	if (ff < 0.33) {
		_progBattery.progressTintColor = [UIColor redColor];
	}
	else if (ff < 0.67) {
		_progBattery.progressTintColor = [UIColor yellowColor];
	}
	else {
		_progBattery.progressTintColor = [UIColor blueColor];
	}
	_progBattery.progress = ff;
}

- (void)timerCheck:(NSTimer*)timer
{	// Wi-Fi接続状態を監視する、切れると第一画面へ
	LOG_FUNC
#if TARGET_IPHONE_SIMULATOR
	return;
#endif
	//[mTimerCheck invalidate];	//タイマー停止
	
	if (![TheTaManager sharedInstance].isConnected) {
		dispatch_async_main(^{
			[self progressOff];
			[self.navigationController popToRootViewControllerAnimated:YES];
		});
		return;
	}

	dispatch_async_main(^{
		[self viewRefreshBattery];
	});
}

- (IBAction)onThumbnailTouchUpIn:(id)sender
{
	// サムネイル画像を押したとき
	if (_dataObject.tamaCapture != nil) {
		// Goto Viewer View
		_dataObject.tamaViewer = _dataObject.tamaCapture;

		ViewerViewController* vc = [[ViewerViewController alloc] init];
		[self.navigationController pushViewController:vc animated:YES];
	}
}

- (IBAction)onListTouchUpIn:(id)sender
{
	// List > を押したとき
	_dataObject.listBottom = YES; // ListViewにて最終行を表示させる
	// Goto Model Viewer View
	ListViewController* vc = [[ListViewController alloc] init];
	[self.navigationController pushViewController:vc animated:YES];
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
	_segShutter2.selectedSegmentIndex = UISegmentedControlNoSegment; //クリア
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
//	_segIso.selectedSegmentIndex = 0; //Auto
}

- (IBAction)sgShutter2Changed:(UISegmentedControl*)sender
{
	_segShutter1.selectedSegmentIndex = UISegmentedControlNoSegment; //クリア
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
//	_segIso.selectedSegmentIndex = 0; //Auto
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
//	_segShutter1.selectedSegmentIndex = 0; //Auto
//	_segShutter2.selectedSegmentIndex = UISegmentedControlNoSegment; //クリア
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
	_segWhite2.selectedSegmentIndex = UISegmentedControlNoSegment; //クリア
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
	_segWhite1.selectedSegmentIndex = UISegmentedControlNoSegment; //クリア
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
	_dataObject.capturePreview = sender.on;
	
	if (!_dataObject.capturePreview) {
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
	_ivThumbnail.image = img;
	_lbThumbnail.text = title;
	_buThumbnail.enabled = YES;
	[self viewRefresh];
}

- (void)thumbnailOff
{
	_ivThumbnail.image = mImageThumb;
	_lbThumbnail.text = nil;
	_buThumbnail.enabled = NO;
	[self viewRefresh];
}



@end
