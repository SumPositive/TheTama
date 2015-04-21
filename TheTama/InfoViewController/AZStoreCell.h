//
//  AZStoreCell.h
//  AzBodyNote
//
//  Created by Matsuyama Masakazu on 12/06/28.
//  Copyright (c) 2012年 Azukid - Sum Positive. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import "InfoViewController.h"


@interface AZStoreCell : UITableViewCell
{
	IBOutlet UILabel		*ibLbTitle;
	IBOutlet UILabel		*ibLbDetail;
	IBOutlet UIButton	*ibBuRestore;
	IBOutlet UIButton	*ibBuBuy;
}

@property (nonatomic, assign) id					delegate;
@property (nonatomic, retain) SKProduct	*ppProduct;
@property (nonatomic, retain) NSString		*ppErrTitle;

- (IBAction)ibBuRestoreTouch:(UIButton *)button;	
- (IBAction)ibBuBuyTouch:(UIButton *)button;	

- (void)refresh;

@end

@protocol AZStoreCellDelegate <NSObject>
#pragma mark - <AZStoreCellDelegate>
- (void)cellActionRestore;
- (void)cellActionBuy:(SKProduct*)product;
@end
