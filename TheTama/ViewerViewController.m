//
//  ViewerViewController.m
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <GLKit/GLKit.h>
#import "PtpConnection.h"
#import "PtpObject.h"
#import "RicohEXIF.h"
#import "ExifTags.h"

#import "MRProgress.h"		// http://cocoadocs.org/docsets/MRProgress/0.2.2/
//#import "SVProgressHUD.h"

#import "Azukid.h"
#import "TheTama-Swift.h"

#import "ViewerViewController.h"
#import "glkViewController.h"
#import "GLRenderView.h"


//inline static void dispatch_async_main(dispatch_block_t block)
//{
//	dispatch_async(dispatch_get_main_queue(), block);
//}

@interface ViewerViewController ()
{
	DataObject * mData;

	PtpObject * mPtpObject;
	NSMutableData * mImageData;
	int imageWidth;
	int imageHeight;
	GlkViewController * glkViewController;
	float _yaw;
	float _roll;
	float _pitch;
	MRProgressOverlayView * mMrpov;
}
@property (nonatomic, strong) IBOutlet UIImageView* imageView;
@property (nonatomic, strong) IBOutlet UILabel * lbTitle;
//@property (nonatomic, strong) IBOutlet UIProgressView* progressView;
@end


@implementation ViewerViewController


#pragma mark - UI events.

- (IBAction)onBackTouchUpIn:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
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


#pragma mark - PTP/IP Operation

- (void)getObject:(PtpConnection *)ptpConnection ptpObject:(PtpObject *)ptpObject
{
	LOG_FUNC
#if TARGET_IPHONE_SIMULATOR
	return;
#endif
	
	mPtpObject = ptpObject;

	dispatch_async(dispatch_get_main_queue(), ^{
		//self.progressView.progress = 0.0;
		//self.progressView.hidden = NO;
		mMrpov = [MRProgressOverlayView showOverlayAddedTo:self.imageView
											title:NSLocalizedString(@"Loading...",nil)	// nil だと落ちる
											 mode:MRProgressOverlayViewModeDeterminateCircular
										 animated:YES];
		[mMrpov setProgress:0.0f];
		
		
		NSDateFormatter* df = [[NSDateFormatter alloc] init];
		[df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
		[df setDateStyle:NSDateFormatterShortStyle];
		[df setTimeStyle:NSDateFormatterMediumStyle];
		
		self.lbTitle.text = [df stringFromDate:mPtpObject.objectInfo.capture_date];

		//cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", obj.objectInfo.filename];

	});
	
	[ptpConnection operateSession:^(PtpIpSession *session) {
		// This block is running at PtpConnection#gcd thread.
		
		NSMutableData* imageData = [NSMutableData data];
		uint32_t objectHandle = (uint32_t)mPtpObject.objectInfo.object_handle;
		__block float total = 0.0;
		
		// Get primary image that was resized to 2048x1024.
		imageWidth = 2048;
		imageHeight = 1024;
		BOOL result = [session getResizedImageObject:objectHandle
											   width:imageWidth
											  height:imageHeight
										 onStartData:^(NSUInteger totalLength) {
											 // Callback before object-data reception.
											 NSLog(@"getObject(0x%08x) will received %zd bytes.", objectHandle, totalLength);
											 total = (float)totalLength;
											 
										 } onChunkReceived:^BOOL(NSData *data) {
											 // Callback for each chunks.
											 [imageData appendData:data];
											 
											 // Update progress.
											 dispatch_async(dispatch_get_main_queue(), ^{
												 //self.progressView.progress = (float)imageData.length / total;
												 [mMrpov setProgress: (float)imageData.length / total];
											 });
											 
											 // Continue to receive.
											 return YES;
										 }];

		dispatch_async(dispatch_get_main_queue(), ^{
			//self.progressView.progress = 1.0;
			[mMrpov setProgress: 1.0f];
		});

		if (!result) {
			dispatch_async(dispatch_get_main_queue(), ^{
				//self.progressView.hidden = YES;
				[mMrpov dismiss:YES];
			});
			return;
		}
		mImageData = imageData;
		
		// Parse EXIF data, it contains the data to correct the tilt.
		RicohEXIF* exif = [[RicohEXIF alloc] initWithNSData:imageData];
		
		// If there is no information, yaw, pitch and roll method returns NaN.
		LOG(@"RicohEXIF: yaw:%0.1f pitch:%0.1f roll:%0.1f", exif.yaw, exif.pitch, exif.roll);
		
		// 方位角 0 - 360
		if (isnan(exif.yaw) || exif.yaw < 0.0f || 360.0f < exif.yaw) {
			_yaw = 0.0f;
		} else {
			_yaw = exif.yaw;
		}
		
		// 仰角 -90 - 90
		if (isnan(exif.pitch) || exif.pitch < -90.0f || 90.0f < exif.pitch) {
			_pitch = 0.0f;
		} else {
			_pitch = exif.pitch;
		}

		// 水平角 0 - 360
		if (isnan(exif.roll) || exif.roll < 0.0f || 360.0f < exif.roll) {
			_roll = 0.0f;
		} else {
			_roll = exif.roll;
		}
		
		LOG(@"Viewer: _yaw:%0.1f _pitch:%0.1f _roll:%0.1f", _yaw, _pitch, _roll);
		
		dispatch_async(dispatch_get_main_queue(), ^{
			//self.progressView.hidden = YES;
			[mMrpov dismiss:YES];
			//[self appendLog:tiltInfo];
			[self startGLK];
		});
	}];
}


#pragma make - operation

- (void)startGLK
{
	glkViewController = [[GlkViewController alloc] init:self.imageView.frame image:mImageData
												  width:imageWidth height:imageHeight
													yaw:_yaw roll:_roll pitch:_pitch];
	glkViewController.view.frame = self.imageView.frame;
 
	
	NSLog(@"startGLK imageData: %@", [[NSString alloc] initWithData:mImageData encoding:NSUTF8StringEncoding]);
	NSLog(@"startGLK: frame %f %f %f %f", self.imageView.frame.origin.x, self.imageView.frame.origin.y, self.imageView.frame.size.width, self.imageView.frame.size.height);
	
	[self.view addSubview:glkViewController.view];
	

//	UIButton *myButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
//	myButton.frame = _closeButton.frame;
//	[myButton setTitle:_closeButton.currentTitle forState:UIControlStateNormal];
//	[myButton addTarget:self action:@selector(myCloseClicked:) forControlEvents:UIControlEventTouchUpInside];
//	[glkViewController.view addSubview:myButton];
//	
//	UIButton *myConfigButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
//	myConfigButton.frame = _configButton.frame;
//	[myConfigButton setTitle:_configButton.currentTitle forState:UIControlStateNormal];
//	[myConfigButton addTarget:self action:@selector(myConfig:) forControlEvents:UIControlEventTouchUpInside];
//	[glkViewController.view addSubview:myConfigButton];
	
	[self addChildViewController:glkViewController];
	[glkViewController didMoveToParentViewController:self];
}


#pragma mark - Life cycle.

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	AppDelegate * app = [UIApplication sharedApplication].delegate;
	mData = [app getDataObject];
	assert(mData != nil);
	
	//  通知受信の設定
	NSNotificationCenter*   nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(applicationWillEnterForeground) name:@"applicationWillEnterForeground" object:nil];
	[nc addObserver:self selector:@selector(applicationDidEnterBackground) name:@"applicationDidEnterBackground" object:nil];

	
//無効	// コーナを丸くする
//	[[self.imageView layer] setCornerRadius:20.0];
//	[self.imageView setClipsToBounds:YES];

	//self.progressView.transform = CGAffineTransformMakeScale( 1.0f, 3.0f ); // 横方向に1倍、縦方向に3倍して表示する
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	//self.progressView.progress = 0.0;
	//	[self viewRefresh];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	if (!mData.connected || mData.tamaViewer==nil) {
		[self dismissViewControllerAnimated:YES completion:nil];
		return;
	}
	
	[self getObject:mData.ptpConnection ptpObject:mData.tamaViewer];

	
//	[self applicationWillEnterForeground];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
	self.lbTitle.text = nil;
	self.imageView.image = nil;
}


//2回目以降のフォアグラウンド実行になった際に呼び出される (Background --> Foreground)
- (void)applicationWillEnterForeground
{
	LOG_FUNC
	[self onBackTouchUpIn:nil];
}

//バックグランド実行になった際に呼び出される（Foreground --> Background)
- (void)applicationDidEnterBackground
{
	LOG_FUNC
	[self onBackTouchUpIn:nil];
}

@end

