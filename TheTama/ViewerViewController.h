//
//  ViewerViewController.h
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import <UIKit/UIKit.h>


#define KSTR_NONE_INERTIA           @"none"
#define KSTR_SHORT_INERTIA          @"weak"
#define KSTR_LONG_INERTIA           @"strong"

#define KINT_HIGHT_INTERVAL_BUTTON  54

typedef enum : int {
	NoneInertia = 0,
	ShortInertia,
	LongInertia
} enumInertia;


@interface ViewerViewController : UIViewController

@end
