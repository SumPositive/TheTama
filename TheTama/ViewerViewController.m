//
//  ViewerViewController.m
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import <GLKit/GLKit.h>
#import "PtpConnection.h"
#import "PtpObject.h"
#import "RicohEXIF.h"
#import "ExifTags.h"

#import <QuartzCore/QuartzCore.h>
#import "SVProgressHUD.h"

#import "TheTama-Swift.h"
#import "ViewerViewController.h"
#import "glkViewController.h"
#import "GLRenderView.h"


inline static void dispatch_async_main(dispatch_block_t block)
{
	dispatch_async(dispatch_get_main_queue(), block);
}

@interface ViewerViewController ()
{
	DataObject * mData;

	PtpObject* _ptpObject;
	NSMutableData *_imageData;
	int imageWidth;
	int imageHeight;
	GlkViewController *glkViewController;
	float _yaw;
	float _roll;
	float _pitch;
//	UIView *_configView;
//	UIButton *_configButton1;
//	UIButton *_configButton2;
//	UIButton *_configButton3;
}
@property (nonatomic, strong) IBOutlet UIImageView* imageView;
@property (nonatomic, strong) IBOutlet UILabel * lbTitle;
@property (nonatomic, strong) IBOutlet UIProgressView* progressView;
//@property (nonatomic, strong) IBOutlet UIButton *closeButton;
//@property (nonatomic, strong) IBOutlet UIButton *configButton;
@end


@implementation ViewerViewController


#pragma mark - UI events.

- (IBAction)onBackTouchUpIn:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - PTP/IP Operation

- (void)getObject:(PtpConnection *)ptpConnection ptpObject:(PtpObject *)ptpObject
{
	_ptpObject = ptpObject;
	dispatch_async(dispatch_get_main_queue(), ^{
		_progressView.progress = 0.0;
		_progressView.hidden = NO;
	});
	
	[ptpConnection operateSession:^(PtpIpSession *session) {
		// This block is running at PtpConnection#gcd thread.
		
		NSMutableData* imageData = [NSMutableData data];
		uint32_t objectHandle = (uint32_t)_ptpObject.objectInfo.object_handle;
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
												 _progressView.progress = (float)imageData.length / total;
											 });
											 
											 // Continue to receive.
											 return YES;
										 }];
		_progressView.progress = 1.0;
		if (!result) {
			dispatch_async(dispatch_get_main_queue(), ^{
				_progressView.hidden = YES;
			});
			return;
		}
		_imageData = imageData;
		
		// Parse EXIF data, it contains the data to correct the tilt.
		RicohEXIF* exif = [[RicohEXIF alloc] initWithNSData:imageData];
		
		// If there is no information, yaw, pitch and roll method returns NaN.
		NSString* tiltInfo = [NSString stringWithFormat:@"yaw:%0.1f pitch:%0.1f roll:%0.1f",
							  exif.yaw,
							  exif.pitch,
							  exif.roll];
		
		if (isnan(exif.yaw)) {
			_yaw = 0.0f;
		} else {
			_yaw = exif.yaw;
		}
		if (isnan(exif.pitch)) {
			_pitch = 0.0f;
		} else {
			_pitch = exif.pitch;
		}
		if (isnan(exif.roll)) {
			_roll = 0.0f;
		} else {
			_roll = exif.roll;
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			_progressView.hidden = YES;
			//[self appendLog:tiltInfo];
			NSLog(@"tiltInfo: %@", tiltInfo);
			[self startGLK];
		});
	}];
}


#pragma make - operation

- (void)startGLK
{
	glkViewController = [[GlkViewController alloc] init:_imageView.frame image:_imageData width:imageWidth height:imageHeight yaw:_yaw roll:_roll pitch:_pitch];
	glkViewController.view.frame = _imageView.frame;
 
	
	NSLog(@"startGLK imageData: %@", [[NSString alloc] initWithData:_imageData encoding:NSUTF8StringEncoding]);
	NSLog(@"startGLK: frame %f %f %f %f", _imageView.frame.origin.x, _imageView.frame.origin.y, _imageView.frame.size.width, _imageView.frame.size.height);
	
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
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	// Thumbnailコーナを丸くする
	[[self.imageView layer] setCornerRadius:20.0];
	[self.imageView setClipsToBounds:YES];

	self.progressView.transform = CGAffineTransformMakeScale( 1.0f, 3.0f ); // 横方向に1倍、縦方向に3倍して表示する
//	[self viewRefresh];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	if (mData.ptpConnection==nil || mData.tamaObject==nil) {
		[self dismissViewControllerAnimated:YES completion:nil];
		return;
	}
	
	[self getObject:mData.ptpConnection ptpObject:mData.tamaObject];

	
//	[self applicationWillEnterForeground];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
	self.lbTitle.text = nil;
	self.imageView.image = nil;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end

