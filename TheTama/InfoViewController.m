//
//  InfoViewController.m
//  TheTama
//
//  Created by masa on 2015/04/20.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

//#import <StoreKit/StoreKit.h>
#import "BDToastAlert.h"
#import "MRProgress.h"		// http://cocoadocs.org/docsets/MRProgress/0.2.2/

//#import "RMPurchasesViewController.h"
#import "RMStore.h"
//#import "RMStoreTransactionReceiptVerificator.h"
//#import "RMStoreAppReceiptVerificator.h"
#import "RMStoreKeychainPersistence.h"

#import "Azukid.h"
#import "TheTama-Swift.h"

#import "InfoViewController.h"


@interface InfoViewController () <UITableViewDelegate, UITableViewDataSource, RMStoreObserver>
{
	DataObject * mData;
	
	//id<RMStoreReceiptVerificator> _receiptVerificator;
	RMStoreKeychainPersistence *mPersistence;
	BOOL mProductsRequestFinished;
	NSArray *mProductIDs;
	NSArray *mPurchasedProductIDs;

}
@property (nonatomic, strong) IBOutlet UITableView * tableView;
@property (nonatomic, strong) IBOutlet UIButton	* buBack;
@end


@implementation InfoViewController

#pragma mark - RMStore methods.

- (void)restoreAction
{
	[self progressOnTitle:nil];
	[[RMStore defaultStore] restoreTransactionsOnSuccess:^(NSArray *transactions) {
		[self progressOff];
		[self.tableView reloadData];
	} failure:^(NSError *error) {
		[self progressOff];
		[self alertTitle:NSLocalizedString(@"Restore Transaction Failed",nil) message:error.localizedDescription button:@"OK"];
	}];
}

- (void)trashAction
{
	[mPersistence removeTransactions];
	mPurchasedProductIDs = [[mPersistence purchasedProductIdentifiers] allObjects];
	[self.tableView reloadData];
}


#pragma mark RMStoreObserver

- (void)storeProductsRequestFinished:(NSNotification*)notification
{
	[self.tableView reloadData];
}

- (void)storePaymentTransactionFinished:(NSNotification*)notification
{
	mPurchasedProductIDs = [[mPersistence purchasedProductIdentifiers] allObjects];
	[self.tableView reloadData];
}


#pragma mark - UI events.

- (IBAction)onBackTouchUpIn:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)progressOnTitle:(NSString*)zTitle
{
	if (zTitle) {
		[MRProgressOverlayView showOverlayAddedTo:self.view
											title:zTitle	// nil だと落ちる
											 mode:MRProgressOverlayViewModeIndeterminate
										 animated:YES];
	} else {
		[MRProgressOverlayView showOverlayAddedTo:self.view animated:YES];
	}
}

- (void)progressOff
{
	[MRProgressOverlayView dismissOverlayForView:self.view animated:YES];
}

- (void)alertTitle:(NSString*)title message:(NSString*)message button:(NSString*)button
{
	UIAlertController *alertController = [UIAlertController
										  alertControllerWithTitle:title
										  message:message
										  preferredStyle:UIAlertControllerStyleAlert];
	// addActionした順に左から右にボタンが配置されます
	[alertController addAction:[UIAlertAction actionWithTitle:button
														style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
								{
									// ボタンが押された時の処理
								}]];
	[self presentViewController:alertController animated:YES completion:nil];
}


#pragma mark - <UITableViewDataSource>

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{	// セクション数
#if false	//TODO: Store
	return 3;
#else
	return 1;
#endif
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{	// 各セクションの行数
	switch (section) {
		case 0:	// アプリ情報
			return 2;
			
		case 1:	// 購入済み製品数
			return mPurchasedProductIDs.count <= 0 ? 1 : mPurchasedProductIDs.count;
			
		case 2:	// 製品数
			return mProductsRequestFinished ? mProductIDs.count : 1;
		
		default:
			return 0;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{	// セクション・タイトル
	switch(section) {
		case 0: // アプリ情報
			return NSLocalizedString(@"App Information",nil);
			break;
		case 1: // 購入済み製品
			return NSLocalizedString(@"Purchased producs",nil);
			break;
		case 2: // 製品
			return NSLocalizedString(@"Producs list",nil);
			break;
	}
	return nil; //ビルド警告回避用
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
	static NSString *idCell = @"CellValue1";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:idCell];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:idCell];
	}

	if (indexPath.section==0) {
		// アプリ情報
		switch (indexPath.row) {
			case 0:	// アプリ名
			{
				cell.textLabel.text = NSLocalizedString(@"Title", nil);
				cell.detailTextLabel.text = @"TheTama";
			} break;
			case 1:	// バージョン
			{
				cell.textLabel.text = NSLocalizedString(@"Version", nil);
				cell.detailTextLabel.text = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
			} break;
		}
		return cell;
	}
	else if (indexPath.section==1) {
		// 購入済み製品
		if (mPurchasedProductIDs.count <= 0) {
			cell.detailTextLabel.text = NSLocalizedString(@"Nothing", nil);
		}
		else {
			NSString *productID = [mPurchasedProductIDs objectAtIndex:indexPath.row];
			SKProduct *product = [[RMStore defaultStore] productForIdentifier:productID];
			cell.textLabel.text = product ? product.localizedTitle : productID;
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld",
										 (long)[mPersistence countProductOfdentifier:productID]];
		}
		return cell;
	}
	else if (indexPath.section==2) {
		// 製品
		if (mProductsRequestFinished) {
			NSString *productID = [mProductIDs objectAtIndex:indexPath.row];
			SKProduct *product = [[RMStore defaultStore] productForIdentifier:productID];
			cell.textLabel.text = product ? product.localizedTitle : productID;
			cell.detailTextLabel.text = [RMStore localizedPriceOfProduct:product];
		} else {
			cell.detailTextLabel.text = NSLocalizedString(@"In preparation", nil);
		}
		return cell;
	}
	return nil;
}

#pragma mark  <UITableViewDelegate>

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:YES]; // 選択解除
	
	if (![RMStore canMakePayments]) return;
	
	if (indexPath.section==1) {
		// 購入済み製品
		if (mPurchasedProductIDs.count <= 0 && mPurchasedProductIDs.count <= indexPath.row) {
			return;
		}
		else {
			NSString *productID = [mPurchasedProductIDs objectAtIndex:indexPath.row];
			const BOOL consumed = [mPersistence consumeProductOfIdentifier:productID];
			if (consumed)
			{
				[self.tableView reloadData];
			}
		}
	}
	else if (indexPath.section==2) {
		// 製品
		if (mProductsRequestFinished && 0<=indexPath.row && indexPath.row<[mProductIDs count])
		{
			NSString *productID = [mProductIDs objectAtIndex:indexPath.row];
			[self progressOnTitle:nil];
			[[RMStore defaultStore] addPayment:productID success:^(SKPaymentTransaction *transaction) {
				[self progressOff];
			} failure:^(SKPaymentTransaction *transaction, NSError *error) {
				[self progressOff];
				[self alertTitle:NSLocalizedString(@"Payment Transaction Failed",nil) message:error.localizedDescription button:@"OK"];
			}];
		}
	}
}


#pragma mark - Life cycle.

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	AppDelegate * app = [UIApplication sharedApplication].delegate;
	mData = [app getDataObject];
	assert(mData != nil);
	
	// UITableView
	self.tableView.delegate = self;
	self.tableView.dataSource = self;
	
#if false	//TODO: Store
	//_receiptVerificator = [[RMStoreAppReceiptVerificator alloc] init];
	//[RMStore defaultStore].receiptVerificator = _receiptVerificator;
	
	mPersistence = [[RMStoreKeychainPersistence alloc] init];
	[RMStore defaultStore].transactionPersistor = mPersistence;
	
	// 製品 ID
	mProductIDs = @[@"com.azukid.TheTama.BenefitsPackage"];
	
	[self progressOnTitle:nil];
	[[RMStore defaultStore] requestProducts:[NSSet setWithArray:mProductIDs] success:^(NSArray *products, NSArray *invalidProductIdentifiers){
		[self progressOff];
		mProductsRequestFinished = YES;
		[self.tableView reloadData];
	} failure:^(NSError *error) {
		[self progressOff];
		//[self alertTitle:NSLocalizedString(@"Products Request Failed",nil) message:error.localizedDescription button:@"OK"];
		//単にテーブル行が無い状態
	}];

	// 購入済み製品情報
	RMStore *store = [RMStore defaultStore];
	[store addStoreObserver:self];
	mPersistence = store.transactionPersistor;
	mPurchasedProductIDs = [[mPersistence purchasedProductIdentifiers] allObjects];
#endif
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

- (void)dealloc
{
#if false	//TODO: Store
	[[RMStore defaultStore] removeStoreObserver:self];
#endif
}


@end
