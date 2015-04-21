//
//  InfoViewController.h
//  TheTama
//
//  Created by masa on 2015/04/20.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface InfoViewController : UIViewController

@property (nonatomic, assign) id			delegate;

// Important note about In-App Purchase Receipt Validation on iOS
// クラッキング対策：非消費型でもレシートチェックが必要になった。
// [Manage In-App Purchase]-[View or generate a shared secret]-[Generate]から取得した文字列をセットする
@property (nonatomic, strong) NSString	*ppSharedSecret;

//- (void)setProductIDs:(NSSet *)pids;
//- (void)setGiftDetail:(NSString *)detail productID:(NSString*)pid secretKey:(NSString*)skey;

// AZStoreCellから呼び出される
- (void)cellActionRestore;
- (void)cellActionBuy:(SKProduct*)product;
	
@end

//@protocol AZStoreDelegate <NSObject>
//#pragma mark - <AZStoreDelegate>
//- (void)azStorePurchesed:(NSString*)productID;
//@end

