//
//  Azukid.h
//
//  Created by masa on 2015/04/11.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#ifndef Azukid_h
#define Azukid_h

#import <UIKit/UIKit.h>


/// DEBUG Code
#ifdef DEBUG

#define LOG(...) NSLog(__VA_ARGS__)
#define LOG_PRINTF(FORMAT, ...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#define LOG_FUNC NSLog(@"%s", __func__);
#define LOG_E(FORMAT, ...) printf("[ERROR]%s %s\n",__func__,[[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#define LOG_W(FORMAT, ...) printf("[WARN]%s %s\n",__func__,[[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#define LOG_L(FORMAT, ...) printf("[LOG]%s %s\n",__func__,[[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);


#define LOG_POINT(p) NSLog(@"%f, %f", p.x, p.y)
#define LOG_SIZE(p) NSLog(@"%f, %f", p.width, p.height)
#define LOG_RECT(p) NSLog(@"%f, %f - %f, %f", p.origin.x, p.origin.y, p.size.width, p.size.height)

#else

#define LOG(...)
#define LOG_PRINTF(FORMAT, ...)
#define LOG_FUNC
//#define LOG_E(FORMAT, ...) //リリースしても有効にするため個人機密情報に注意！
#define LOG_W(FORMAT, ...)
#define LOG_L(FORMAT, ...)

#define LOG_POINT(p)
#define LOG_SIZE(p)
#define LOG_RECT(p)

#endif


/// nil | NSNull --> @""
#define NZ(a)		((a && a!=[NSNull null])?a:@"")

/// NSNull --> nil
#define NN(a)		(a!=[NSNull null]?a:nil)



///
#include "TargetConditionals.h"
#if TARGET_IPHONE_SIMULATOR
	// シミュレーター上でのみ実行される処理
#else
	// 実機でのみ実行される処理
#endif


/// UI処理・メインスレッド
inline static void dispatch_async_main(dispatch_block_t block)
{
	dispatch_async(dispatch_get_main_queue(), block);
}



@interface Azukid : NSObject

/// view以下にあるボタンの複数同時押しを禁止する
+ (void)banMultipleTouch:(UIView*)view;

/// ボタン連打防止
+ (void)banBarrage:(UIButton*)button;

@end



#endif
