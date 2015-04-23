//
//  CaptureViewController.h
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CaptureViewController : UIViewController

typedef enum {
	CAPTURE_MODE_NORMAL		= 1,
	CAPTURE_MODE_TIMELAPSE	= 2,
	CAPTURE_MODE_MOVIE		= 3,
} CAPTURE_MODE;

@end
