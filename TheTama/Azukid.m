//
//  Azukid.m
//  TheTama
//
//  Created by masa on 2015/10/11.
//  Copyright © 2015年 Azukid. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Azukid.h"



@implementation Azukid


/// view以下にあるボタンの複数同時押しを禁止する
+ (void)banMultipleTouch:(UIView*)view
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		// UIだが表示に影響ないのでバック処理している
		for (UIView * button in [view subviews]) {
			if([button isKindOfClass:[UIButton class]])
				[((UIButton *)button) setExclusiveTouch:YES];//タッチ独占させる
		}
	});
}


/// ボタン連打防止
+ (void)banBarrage:(UIButton*)button
{
	button.enabled = NO;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		button.enabled = YES;
	});
}



@end

