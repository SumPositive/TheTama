//
//  Capture.h
//  TheTama
//
//  Created by masa on 2015/05/06.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PtpConnection.h"
#import "PtpLogging.h"
#import "PtpObject.h"


typedef void (^ConnectCompletion)(BOOL success, NSError *error);
typedef void (^CaptureCompletion)(BOOL success, UIImage * thumbnail, NSDate * capture_date, NSError *error);


@protocol CaptureDelegate <NSObject>
@optional
- (void)connected:(BOOL)result;
- (void)disconnected;
//- (void)captured:(BOOL)result thumb:(UIImage*)thumb date:(NSDate *)capture_date;
- (void)strageFull;
- (void)socketError;
@end


@interface Capture : NSObject

typedef enum {
	CAPTURE_MODE_NORMAL		= 1,
	CAPTURE_MODE_TIMELAPSE	= 2,
	CAPTURE_MODE_MOVIE		= 3,
} CAPTURE_MODE;

@property (nonatomic, weak) id<CaptureDelegate> delegate;

@property (readonly) PtpConnection *connection;
@property (readonly) BOOL			connected;

@property (readwrite) UIView *		view;
@property (readwrite) NSUInteger	volumeLevel;
@property (readwrite) NSUInteger	batteryLevel;
@property (readwrite) NSUInteger	shutterSpeed;
@property (readwrite) NSInteger		filmIso;
@property (readwrite) NSInteger		whiteBalance;
@property (readwrite) CAPTURE_MODE	captureMode;

@property (readwrite) NSMutableArray *	tamaObjects;		// 全写真情報を保持
@property (readwrite) PtpObject *		tamaCapture;		// 撮影直後または選択中の写真情報
@property (readwrite) PtpObject *		tamaViewer;			// 3D-Viewerで表示する写真情報


//- (void)connect;
- (void)connectCompletion:(ConnectCompletion)completion;
- (void)disconnect:(BOOL)connect;
//- (void)capture;
- (void)captureCompletion:(CaptureCompletion)completion;
- (UIImage *)imageThumbnail:(uint32_t)objectHandle session:(PtpIpSession *)session;


@end
