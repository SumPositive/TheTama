//
//  Azukid.h
//
//  Created by masa on 2015/04/11.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#ifndef Azukid_h
#define Azukid_h

// TheTama Original Define.
#define LIST_CHUNK_FIRST	7		// ListViewTableでTHETAから１度に読み込む画像数
#define LIST_CHUNK_NEXT		15		// ListViewTableでTHETAから１度に読み込む画像数



#include "TargetConditionals.h"
#if TARGET_IPHONE_SIMULATOR
// シミュレーター上でのみ実行される処理
#else
// 実機でのみ実行される処理
#endif


#ifdef DEBUG
#define LOG(...) NSLog(__VA_ARGS__)
#define LOG_PRINTF(FORMAT, ...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#define LOG_FUNC NSLog(@"%s", __func__);
#else
#define LOG(...)
#define LOG_PRINTF(FORMAT, ...)
#define LOG_FUNC
#endif

#ifdef DEBUG
#define LOG_POINT(p) NSLog(@"%f, %f", p.x, p.y)
#define LOG_SIZE(p) NSLog(@"%f, %f", p.width, p.height)
#define LOG_RECT(p) NSLog(@"%f, %f - %f, %f", p.origin.x, p.origin.y, p.size.width, p.size.height)
#else
#define LOG_POINT(p)
#define LOG_SIZE(p)
#define LOG_RECT(p)
#endif


#endif
