//
//  TheTaManager
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


@protocol TheTaManagerDelegate <NSObject>
@optional
- (void)connected:(BOOL)succeeded;
- (void)disconnected;
//- (void)captured:(BOOL)result thumb:(UIImage*)thumb date:(NSDate *)capture_date;
- (void)strageFull;
- (void)socketError;
@end


@interface TheTaManager : NSObject

typedef enum {
	CAPTURE_MODE_NORMAL		= 1,
	CAPTURE_MODE_TIMELAPSE	= 2,
	CAPTURE_MODE_MOVIE		= 3,
} CAPTURE_MODE;

@property (nonatomic, weak) id<TheTaManagerDelegate> delegate;

@property (nonatomic, readonly) PtpConnection*	connection;
@property (nonatomic, readonly) BOOL			isConnected;

@property (nonatomic, readwrite) UIView* 		progressBlockView;
@property (nonatomic, readwrite) NSUInteger		volumeLevel;
@property (nonatomic, readwrite) NSUInteger		batteryLevel;
@property (nonatomic, readwrite) NSUInteger		shutterSpeed;
@property (nonatomic, readwrite) NSInteger		filmIso;
@property (nonatomic, readwrite) NSInteger		whiteBalance;
@property (nonatomic, readwrite) CAPTURE_MODE	captureMode;

@property (nonatomic, readwrite) NSMutableArray*	tamaObjects;	// 全写真情報を保持
@property (nonatomic, readwrite) PtpObject*		tamaCapture;		// 撮影直後または選択中の写真情報
@property (nonatomic, readwrite) PtpObject*		tamaViewer;			// 3D-Viewerで表示する写真情報


/// Singleton 固有インスタンスを返す
+ (TheTaManager*)sharedInstance;

//- (void)connect;
- (void)connectCompletion:(ConnectCompletion)completion;
- (void)disconnect:(BOOL)connect;
//- (void)capture;
- (void)captureCompletion:(CaptureCompletion)completion;
- (UIImage *)imageThumbnail:(uint32_t)objectHandle session:(PtpIpSession *)session;


@end



