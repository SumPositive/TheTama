//
//  InfoViewController
//
//  Created by Sum Positive on 11/10/06.
//  Copyright (c) 2011 Azukid. All rights reserved.
//
#undef  NSLocalizedString		//⇒ AZLocalizedString  AZClass専用にすること

#import <StoreKit/StoreKit.h>
#import "BDToastAlert.h"
#import "MRProgress.h"		// http://cocoadocs.org/docsets/MRProgress/0.2.2/

#import "Azukid.h"
#import "TheTama-Swift.h"

#import "AZStoreCell.h"
#import "VerificationController.h"

#import "InfoViewController.h"


#define SK_INIT			@"Init"
#define SK_BAN			@"Ban"
#define SK_NoSALE		@"NoSale"
#define SK_CLOSED		@"Closed"

#define TAG_ActivityIndicator			109
#define TAG_GoAppStore					118

#define TAG_BU_RESTORE					200 //〜299  =200 + indexPath.row;
#define TAG_BU_BUY						300	//〜399  =300 + indexPath.row;


@interface InfoViewController () <UITableViewDelegate, UITableViewDataSource,
									SKProductsRequestDelegate, SKPaymentTransactionObserver,
									VerificationControllerDelegate>
{
	DataObject * mData;
	
//	UITextField						*mTfGiftCode;
	UIAlertView						*mAlertActivity;
	UIActivityIndicatorView			*mAlertActivityIndicator;
	SKProductsRequest				*mProductRequest;
	
//	BOOL							mIsPad;
	NSSet							*mProductIDs;
	NSMutableArray					*mProducts;
	
//	NSString						*mGiftDetail;	//=nil; 招待パスなし
//	NSString						*mGiftProductID;
//	NSString						*mGiftSecretKey;//1615AzPackList
	//NSUInteger					mDidSelect_ProductNo;
	NSString						*mPurchasedProductID;
}
@property (nonatomic, strong) IBOutlet UITableView * tableView;
@end


@implementation InfoViewController

#pragma mark - UI events.

- (IBAction)onBackTouchUpIn:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)alertActivityOn:(NSString*)zTitle
{
//	[mAlertActivity setTitle:zTitle];
//	[mAlertActivity show];
//	[mAlertActivityIndicator setFrame:CGRectMake((mAlertActivity.bounds.size.width-50)/2, mAlertActivity.frame.size.height-130, 50, 50)];
//	[mAlertActivityIndicator startAnimating];
	
	[MRProgressOverlayView showOverlayAddedTo:self.view
										title:zTitle
										 mode:MRProgressOverlayViewModeIndeterminate
									 animated:YES];
}

- (void)alertActivityOff
{
//	[mAlertActivityIndicator stopAnimating];
//	[mAlertActivity dismissWithClickedButtonIndex:mAlertActivity.cancelButtonIndex animated:YES];

	[MRProgressOverlayView dismissOverlayForView:self.view animated:YES];
}
/*
- (void)alertCommError
{
	alertBox(AZLocalizedString(@"AZStore CommError", nil), AZLocalizedString(@"AZStore CommError msg", nil), @"OK");
}*/



//- (void)actionBack:(id)sender
//{
//	if (mIsPad) {
//		[self dismissModalViewControllerAnimated:YES];
//	} else {
//		[self.navigationController popViewControllerAnimated:YES];	// < 前のViewへ戻る
//	}
//}

- (void)cellActionRestore
{	// [Restore] [購入済み復元]
	//GA_TRACK_METHOD
	// インジケータ開始
	//[self	alertActivityOn:NSLocalizedString(@"AZStore Progress",nil)];
	[MRProgressOverlayView showOverlayAddedTo:self.view
										title:NSLocalizedString(@"AZStore Progress",nil)
										 mode:MRProgressOverlayViewModeIndeterminate animated:YES];
	
	[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)azAlertTitle:(NSString*)title message:(NSString*)message button:(NSString*)button
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


- (void)cellActionBuy:(SKProduct*)product
{	// [Buy] [購入]
	//GA_TRACK_METHOD
	if (product) {
		// インジケータ開始
		[self alertActivityOn:NSLocalizedString(@"AZStore Progress",nil)];
		// アドオン購入処理開始
		[[SKPaymentQueue defaultQueue] addTransactionObserver: self]; //<SKPaymentTransactionObserver>
		SKPayment *payment = [SKPayment paymentWithProduct: product];
		[[SKPaymentQueue defaultQueue] addPayment:payment];
	}
	else {
		// 販売停止中
		//[mProducts replaceObjectAtIndex:idx withObject:SK_NoSALE];
		[self.tableView reloadData];
	}
}

// productID の購入確定処理
- (void)actPurchasedProductID:(NSString*)productID
{
	//GA_TRACK_METHOD
	// AZClass規則： 購入済み記録は、standardUserDefaults:へ最優先に記録し判定に使用すること。
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setBool:YES  forKey:productID];  //YES=購入済み
	[userDefaults synchronize];
	// 他デバイス同期のため KVS が有効ならばKVSへも記録する
	NSUbiquitousKeyValueStore *kvs = [NSUbiquitousKeyValueStore defaultStore];
	if (kvs) {
		[kvs setBool:YES  forKey:productID];  //YES=購入済み
		[kvs synchronize]; // 保存同期
	}
	
//	if ([self.delegate respondsToSelector:@selector(azStorePurchesed:)]) {
//		[self.delegate azStorePurchesed: productID];	// 呼び出し側にて、再描画など実施
//	}
	
	
	
	mData.option1payed = YES;

	
	// 再表示
	[self.tableView reloadData];
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
	
	
	// 製品 ID
	mProductIDs = [[NSSet alloc] initWithObjects:@"com.azukid.TheTama.BenefitsPackage", nil];
	
}

//- (void)viewDidLoad
//{
//    [super viewDidLoad];
//	self.title = NSLocalizedString(@"AZStore",nil);
//	
//	// alertActivityOn/Off のための準備
//	mAlertActivity = [[UIAlertView alloc] initWithTitle:@"" message:@"\n\n" delegate:self 
//									  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
//									  otherButtonTitles:nil]; // deallocにて解放
//	mAlertActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
//	mAlertActivityIndicator.frame = CGRectMake(0, 0, 50, 50);
//	[mAlertActivity addSubview:mAlertActivityIndicator];
//}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	
//	//NSLog(@"self.navigationController.viewControllers={%@}", self.navigationController.viewControllers);
//	if ([self.navigationController.viewControllers count]==1) {	// viewDidLoad:では未設定であり判断できない
//		// 最初のPushViewには <Back ボタンが無いので、左側に追加する ＜＜ iPadの場合
//		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
//												 initWithTitle:NSLocalizedString(@"<Back", nil)
//												 style:UIBarButtonItemStyleBordered
//												 target:self action:@selector(actionBack:)];
//	}

	mProducts = [[NSMutableArray alloc] initWithObjects:SK_INIT, nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
	
	if ([self.ppSharedSecret length]<10) {
		//GA_TRACK_ERROR(@"AZStore .ppSharedSecret NG：非消費型でもレシートチェックが必要になった。");
		// 購入が禁止されています。
		//[mProducts replaceObjectAtIndex:0 withObject:SK_BAN];
		//[self.tableView reloadData];
		//return;
		abort();
	}
	
	// Products 一覧表示
	if ([SKPaymentQueue canMakePayments] && mProductIDs) { // 課金可能であるか確認する
		// 課金可能
		[self alertActivityOn:NSLocalizedString(@"AZStore Progress",nil)];
		// 商品情報リクエスト
		mProductRequest = [[SKProductsRequest alloc] initWithProductIdentifiers: mProductIDs];
		mProductRequest.delegate = self;		//viewDidUnloadにて、cancel, nil している。さもなくば落ちる
		[mProductRequest start];  //---> productsRequest:didReceiveResponse:が呼び出される
	} else {
		// 購入が禁止されています。
		[mProducts replaceObjectAtIndex:0 withObject:SK_BAN];
		[self.tableView reloadData];
	}
}

//- (void)viewWillDisappear:(BOOL)animated
//{
//    [super viewWillDisappear:animated];
//}
//
//- (void)viewDidDisappear:(BOOL)animated
//{
//    [super viewDidDisappear:animated];
//}
//
//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
//{
//	return YES;	// FormSheet窓対応
//}

#pragma mark unload
- (void)viewDidUnload		//＜＜実験では、呼ばれなかった！
{
    [super viewDidUnload];
}

- (void)unloadStore
{	// 必ず最後に呼ばれる
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self]; // これが無いと、しばらくすると落ちる
	if (mProductRequest) {
		[mProductRequest cancel];			// 中断
		mProductRequest.delegate = nil;  // これないと、通信中に閉じると落ちる
	}
}

- (void)dealloc
{
	[self unloadStore];
}


//#pragma mark - Method - set
///*
//- (void)setTitle:(NSString *)title {  NG ＜＜無限ループになる
//	self.title = title;
//}*/
//
//- (void)setProductIDs:(NSSet *)pids {
//	assert(0<[pids count]);
//	// ここでリクエスト処理すると表示が遅くなるため、viewDidAppear:にて処理する。
//	mProductIDs = pids;
//}

//- (void)setGiftDetail:(NSString *)detail productID:(NSString*)pid secretKey:(NSString*)skey 
//{
//	if (detail && pid && skey) {
//		mGiftDetail = detail;
//		mGiftProductID = pid;
//		mGiftSecretKey = skey;
//	} else {
//		mGiftDetail = nil;
//		mGiftProductID = nil;
//		mGiftSecretKey = nil;
//	}
//}


//#pragma mark - <UIAlertViewDelegate>
//- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
//{
//	if (buttonIndex==alertView.cancelButtonIndex) {
//		[self unloadStore];
//		[self alertActivityOff];
//		[self actionBack:nil];	// 戻る
//	}
//}


#pragma mark - <UITableViewDataSource>

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{	// セクション数
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{	// 各セクションの行数
	switch (section) {
		case 0:	// アプリ情報
			return 2;
			
		case 1:	// ショップ
			return [mProducts count];
			
		default:
			return 0;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{	// セクション・タイトル
	switch(section) {
		case 0: // アプリ情報
			return NSLocalizedString(@"Lz.InfoApp",nil);
			break;
		case 1: // ショップ
			return NSLocalizedString(@"Lz.InfoPurchase",nil);
			break;
	}
	return nil; //ビルド警告回避用
}

//- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
//{	// セクション・フッタ
//	switch (section) {
//		case 0:	return NSLocalizedString(@"AZStore Products Footer", nil);
//		//case 1:	return NSLocalizedString(@"AZStore Gift Footer", nil);
//		case 2:	return @"\n" AZClass_COPYRIGHT @"\n\n";	//広告スペースを考慮
//	}
//	return nil;
//}

// セルの高さを指示する
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	switch (indexPath.section) {
		case 1:	// Store
			return 105;
	}
	return 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	//NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	//NSUbiquitousKeyValueStore *kvs = [NSUbiquitousKeyValueStore defaultStore];
	if (indexPath.section==0) {
		// アプリ情報
		static NSString *idCell = @"CellValue1";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:idCell];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
										  reuseIdentifier:idCell];
		}
		switch (indexPath.row) {
			case 0:	// アプリ名
			{
				cell.textLabel.text = NSLocalizedString(@"Lz.InfoNameTitle", nil);
				cell.detailTextLabel.text = @"TheTama";
			} break;
			case 1:	// バージョン
			{
				cell.textLabel.text = NSLocalizedString(@"Lz.InfoVersionTitle", nil);
				cell.detailTextLabel.text = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
			} break;
		}
		return cell;
	}
	else if (indexPath.section==1) {
		// Store
		static NSString *idAZStoreCell = @"AZStoreCell";	//AZStoreCell.xib CustomCell
		AZStoreCell *cell = (AZStoreCell *)[tableView dequeueReusableCellWithIdentifier:idAZStoreCell];
		if (cell == nil) {
			UINib* nib = [UINib nibWithNibName:idAZStoreCell bundle:nil];
			NSArray* array = [nib instantiateWithOwner:nil options:nil];
			cell = (AZStoreCell *) [array objectAtIndex:0];
			cell.delegate = self;
		}
		
		if (0<=indexPath.row && indexPath.row<[mProducts count]) 
		{
			if ([[mProducts objectAtIndex: indexPath.row] isKindOfClass:[SKProduct class]]) 
			{	// 商品あり　　AZStoreCell
				cell.ppProduct = [mProducts objectAtIndex: indexPath.row];
			}
			else if ([[mProducts objectAtIndex: indexPath.row] isEqualToString:SK_INIT])
			{
				cell.ppProduct = nil;
				cell.ppErrTitle = NSLocalizedString(@"AZStore Progress", nil);
			}
			else if ([[mProducts objectAtIndex: indexPath.row] isEqualToString:SK_BAN])
			{
				cell.ppProduct = nil;
				cell.ppErrTitle = NSLocalizedString(@"AZStore Ban", nil);
			}
			else if ([[mProducts objectAtIndex: indexPath.row] isEqualToString:SK_NoSALE])
			{
				cell.ppProduct = nil;
				cell.ppErrTitle = NSLocalizedString(@"AZStore Closed", nil);
			}
			else if ([[mProducts objectAtIndex: indexPath.row] isEqualToString:SK_CLOSED])
			{
				cell.ppProduct = nil;
				cell.ppErrTitle = NSLocalizedString(@"AZStore Closed", nil);
			}
			// 再描画する
			[cell refresh];
			return cell;
		}
	}
    return nil;
}
/*
// Display customization
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell 
															forRowAtIndexPath:(NSIndexPath *)indexPath
{

}*/


#pragma mark  <UITableViewDelegate>

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.tableView deselectRowAtIndexPath:indexPath animated:YES]; // 選択解除

	if (indexPath.section==1) {
		// Store
		if (0<=indexPath.row && indexPath.row<[mProducts count]) 
		{
			UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
			if (cell.selectionStyle==UITableViewCellSelectionStyleBlue)
			{	// 選択時ハイライト ＜＜選択許可
				SKProduct *prod = [mProducts objectAtIndex: indexPath.row];
				if (prod) {
					[self alertActivityOn:NSLocalizedString(@"AZStore Progress",nil)];
					// アドオン購入処理開始
					[[SKPaymentQueue defaultQueue] addTransactionObserver: self]; //<SKPaymentTransactionObserver>
					SKPayment *payment = [SKPayment paymentWithProduct: prod];
					[[SKPaymentQueue defaultQueue] addPayment:payment];
				}
				else {
					// 販売停止中
					[mProducts replaceObjectAtIndex:indexPath.row withObject:SK_NoSALE];
					[self.tableView reloadData];
				}
			}
			else {
					// 選択不可、　購入済み
			}
		}
	}
}



#pragma mark - <SKProductsRequestDelegate> 販売情報

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{	// 商品情報を取得して購入ボタン表示などを整える
	[self alertActivityOff];
	if (0 < [response.invalidProductIdentifiers count]) {
		//GA_TRACK_EVENT_ERROR(@"Invalid ProductIdentifiers", 0);
		NSLog(@"*** Invalid ProductIdentifiers: アイテムIDが不正");
		[mProducts replaceObjectAtIndex:0 withObject:SK_CLOSED];
		[self.tableView reloadData];
		return;
	}
	[mProducts removeAllObjects];
	for (SKProduct *product in response.products) 
	{
		[mProducts addObject:product];
	}	
	[self.tableView reloadData];
}


#pragma mark - <VerificationControllerDelegate>
- (void)verificationResult:(BOOL)result
{
	if (result) {	// OK
		// productID の購入確定処理   ＜＜この中でセル再描画している
		[self actPurchasedProductID: mPurchasedProductID];
	} else {
		//GA_TRACK_ERROR(@"AZStore ReceiptNG");
		// NG Receipt ERROR
		[self azAlertTitle:NSLocalizedString(@"AZStore Failed",nil) message:NSLocalizedString(@"AZStore ReceiptNG",nil) button:@"OK"];
	}
	// インジケータ消す
	[self alertActivityOff];
}


#pragma mark - <SKPaymentTransactionObserver>  販売処理
// 購入成功時の最終処理　＜＜ここでトランザクションをクリアする。
- (void)paymentCompleate:(SKPaymentTransaction*)tran
{	// 複数製品をリストアした場合、製品数だけ呼び出される
	// Compleate !
	[[SKPaymentQueue defaultQueue] finishTransaction:tran]; // 処理完了

	// Important note about In-App Purchase Receipt Validation on iOS
	// レシート検証
	[self	alertActivityOn:NSLocalizedString(@"AZStore Receipt Validation",nil)];
	mPurchasedProductID = tran.payment.productIdentifier;
	if (![[VerificationController sharedInstance] verifyPurchase:tran
													sharedSecret:self.ppSharedSecret	  target:self]) 
	{	//--> 結果は、verificationResult:
		// NG
		NSLog(@"%s verifyPurchase ERROR", __func__);
	}
	// レシート検証結果：　verificationResult:が呼び出される。
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{	// Observer: 
	for (SKPaymentTransaction *tran in transactions)
	{
		switch (tran.transactionState) {
			case SKPaymentTransactionStatePurchasing: // 購入中
				NSLog(@"SKPaymentTransactionStatePurchasing: tran=%@", tran);
				// インジケータ開始
				[self	alertActivityOn:NSLocalizedString(@"AZStore Progress",nil)];
				break;
				
			case SKPaymentTransactionStateFailed: // 購入失敗
			{
				//GA_TRACK_EVENT(@"AZStore", @"SKPaymentTransactionStateFailed", [tran description] , 0);
				NSLog(@"SKPaymentTransactionStateFailed: tran=%@", tran);
				[[SKPaymentQueue defaultQueue] finishTransaction:tran]; // 処理完了
				[self alertActivityOff];	// インジケータ消す
				
				if (tran.error.code == SKErrorUnknown) {
					// クレジットカード情報入力画面に移り、購入処理が強制的に終了したとき
					// 途中で止まった処理を再開する Consumable アイテムにも有効
					[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
				} else {
					//GA_TRACK_ERROR(@"SKPaymentTransactionStateFailed")
					//azAlertBox(	AZLocalizedString(@"AZStore Failed",nil), nil, @"OK" );
					[self azAlertTitle:NSLocalizedString(@"AZStore Failed",nil) message:nil button:@"OK"];
				}
#ifdef DEBUGxxx
				// 購入成功と見なしてテストする
				NSLog(@"DEBUG: SKPaymentTransactionStatePurchased: tran=%@", tran);
				[self paymentCompleate:tran];
#endif
			} break;
				
			case SKPaymentTransactionStatePurchased:	// 購入完了
			{
				NSLog(@"SKPaymentTransactionStatePurchased: tran=%@", tran);
				[self paymentCompleate:tran];
			} break;
				
			case SKPaymentTransactionStateRestored:		// 購入済み
			{
				NSLog(@"SKPaymentTransactionStateRestored: tran=%@", tran);
				[self paymentCompleate:tran];
			} break;
				
			default:
				//GA_TRACK_EVENT(@"AZStore", @"SKPaymentTransactionState: default", [tran description] , 0);
				NSLog(@"SKPaymentTransactionState: default: tran=%@", tran);
				break;
		}
	}
}

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions 
{
	[[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{	// リストアの失敗
	NSLog(@"paymentQueue: restoreCompletedTransactionsFailedWithError: ");
	//GA_TRACK_ERROR([error description]);
	// インジケータ消す
	[self alertActivityOff];
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue 
{	// 全てのリストア処理が終了
	NSLog(@"paymentQueueRestoreCompletedTransactionsFinished: ");
	// インジケータ消す
	[self alertActivityOff];
}


//#pragma mark - <UITextFieldDelegate>
//- (BOOL)textFieldShouldReturn:(UITextField *)textField
//{
//	assert(textField==mTfGiftCode);
//	assert(mGiftProductID);
//	assert(mGiftSecretKey);
//	[textField resignFirstResponder]; // キーボードを隠す
//	
//	// 招待パス生成
//	NSString *pass = azGiftCode( mGiftSecretKey ); //16進文字列（英数大文字のみ）
//	// 英大文字にしてチェック
//	if ([pass length]==10 && [pass isEqualToString: [mTfGiftCode.text uppercaseString]]) 
//	{
//		// productID の購入確定処理
//		[self actPurchasedProductID: mGiftProductID];
//		// OK
//		azAlertBox(AZLocalizedString(@"AZStore Gift OK", nil), nil, @"OK");
//	}
//	else {
//		// NG 招待パスが違う
//		azAlertBox(AZLocalizedString(@"AZStore Gift NG", nil), nil, @"OK");
//		mTfGiftCode.text = @"";
//	}
//	return YES;
//}
//
//- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range 
//replacementString:(NSString *)string 
//{	// Gift code 最大文字数制限
//    NSMutableString *text = [textField.text mutableCopy];
//    [text replaceCharactersInRange:range withString:string];
//	// 置き換えた後の長さをチェックする
//	if ([text length] <= 16) {
//		return YES;
//	} else {
//		return NO;
//	}
//}


@end
