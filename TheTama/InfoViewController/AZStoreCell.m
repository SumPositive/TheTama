//
//  AZStoreCell.m
//  AzBodyNote
//
//  Created by Matsuyama Masakazu on 12/06/28.
//  Copyright (c) 2012年 Azukid - Sum Positive. All rights reserved.
//
#import "AZStoreCell.h"

@implementation AZStoreCell
@synthesize delegate;
@synthesize ppProduct;
@synthesize ppErrTitle;


/***通らない
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
		
    }
    return self;
}*/

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    // Configure the view for the selected state
}

- (IBAction)ibBuRestoreTouch:(UIButton *)button
{	// [Restore] [購入済み復元]
	[self.delegate cellActionRestore];
}

- (IBAction)ibBuBuyTouch:(UIButton *)button
{	// [Buy] [購入]
	[self.delegate cellActionBuy:self.ppProduct];
}

- (void)drawRect:(CGRect)rect
{	// ここは初期化時にしか通らない。　更新処理は、refresh にて
	[ibBuRestore setTitle:NSLocalizedString(@"AZStore Restore", nil) forState:UIControlStateNormal];
	[ibBuBuy setTitle:NSLocalizedString(@"AZStore Buy", nil) forState:UIControlStateNormal];
}

- (void)refresh
{
	if (self.ppProduct==nil) {
		// 販売停止中
		//cell.imageView.image = [UIImage imageNamed:@"AZStore-Stop-32"];
		ibLbTitle.text = self.ppErrTitle;  // AZLocalizedString(@"AZStore Closed", nil);
		ibLbDetail.text = nil;
		ibBuRestore.hidden = YES;
		ibBuBuy.hidden = YES;
		return;
	}
	
	//cell.textLabel.font = [UIFont systemFontOfSize:18];
	ibLbTitle.text = self.ppProduct.localizedTitle;
	
	NSUbiquitousKeyValueStore *kvs = [NSUbiquitousKeyValueStore defaultStore];
	// AZClass規則： 購入済み記録は、standardUserDefaults:へ最優先に記録し判定に使用すること。
	if ([kvs boolForKey: self.ppProduct.productIdentifier]) {
		// 購入済み
		ibLbDetail.textColor = [UIColor blueColor];
		ibLbDetail.text = NSLocalizedString(@"AZStore Purchased", nil);
		ibBuRestore.hidden = YES;
		ibBuBuy.hidden = YES;
	} else {
		// Price 金額単位表示する
		NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
		[fmt setNumberStyle:NSNumberFormatterCurrencyStyle]; // 通貨スタイル（先頭に通貨記号が付く）
		[fmt setLocale: self.ppProduct.priceLocale];  //[NSLocale currentLocale]]; 
		ibLbDetail.text = [NSString stringWithFormat:@"Price: %@\n%@", 
									 [fmt stringFromNumber:self.ppProduct.price],
									 self.ppProduct.localizedDescription];
		ibBuRestore.hidden = NO;
		ibBuBuy.hidden = NO;
	}
}

@end
