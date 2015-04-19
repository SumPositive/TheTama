//
//  ListViewController.m
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import "SVProgressHUD.h"
#import "Azukid.h"

#import "TheTama-Swift.h"
#import "ListViewController.h"
#import "PtpConnection.h"
#import "PtpLogging.h"
#import "PtpObject.h"
#import "TableCellTama.h"

#import "ViewerViewController.h"
#import "EGORefreshTableHeaderView.h"


inline static void dispatch_async_main(dispatch_block_t block)
{
	dispatch_async(dispatch_get_main_queue(), block);
}

@interface ListViewController () <PtpIpEventListener, UITableViewDelegate, UITableViewDataSource, EGORefreshTableHeaderDelegate>
{
	DataObject * mData;
	PtpIpStorageInfo * mStorageInfo;
	BOOL mTableBottom;

	EGORefreshTableHeaderView * mRefreshHeaderView;
	BOOL mReloading;
	//NSString * _cell_string;	// Cellの文字列、更新時に変更
}
@property (nonatomic, strong) IBOutlet UITableView * tableView;
@end


@implementation ListViewController


#pragma mark - PtpIpEventListener delegates.

-(void)ptpip_eventReceived:(int)code :(uint32_t)param1 :(uint32_t)param2 :(uint32_t)param3
{
	LOG_FUNC
	// PTP/IP-Event callback.
	// This method is running at PtpConnection#gcd thread.
	switch (code) {
		default:
			LOG(@"Event(0x%04x) received", code);
			break;
	}
	dispatch_async_main(^{
		[SVProgressHUD dismiss];
	});
}

-(void)ptpip_socketError:(int)err
{
	// socket error callback.
	// This method is running at PtpConnection#gcd thread.
	
	// If libptpip closed the socket, `closed` is non-zero.
	BOOL closed = PTP_CONNECTION_CLOSED(err);
	
	// PTPIP_PROTOCOL_*** or POSIX error number (errno()).
	err = PTP_ORIGINAL_PTPIPERROR(err);
	
	NSArray* errTexts = @[@"Socket closed",              // PTPIP_PROTOCOL_SOCKET_CLOSED
						  @"Brocken packet",             // PTPIP_PROTOCOL_BROCKEN_PACKET
						  @"Rejected",                   // PTPIP_PROTOCOL_REJECTED
						  @"Invalid session id",         // PTPIP_PROTOCOL_INVALID_SESSION_ID
						  @"Invalid transaction id.",    // PTPIP_PROTOCOL_INVALID_TRANSACTION_ID
						  @"Unrecognided command",       // PTPIP_PROTOCOL_UNRECOGNIZED_COMMAND
						  @"Invalid receive state",      // PTPIP_PROTOCOL_INVALID_RECEIVE_STATE
						  @"Invalid data length",        // PTPIP_PROTOCOL_INVALID_DATA_LENGTH
						  @"Watchdog expired",           // PTPIP_PROTOCOL_WATCHDOG_EXPIRED
						  ];
	NSString* desc;
	if ((PTPIP_PROTOCOL_SOCKET_CLOSED<=err) && (err<=PTPIP_PROTOCOL_WATCHDOG_EXPIRED)) {
		desc = [errTexts objectAtIndex:err-PTPIP_PROTOCOL_SOCKET_CLOSED];
	} else {
		desc = [NSString stringWithUTF8String:strerror(err)];
	}
	
	dispatch_async_main(^{
		LOG(@"socket error(0x%X,closed=%@).\n--- %@", err, closed? @"YES": @"NO", desc);
		[SVProgressHUD dismiss];
		// Back Model Connect View
		[self dismissViewControllerAnimated:YES completion:nil];
	});
}


#pragma mark - UI events.

- (IBAction)onBackTouchUpIn:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

//- (IBAction)onReloadTouchUpIn:(id)sender
//{
//	[self reloadTamaObjects];
//}

- (void)prepareForSegue:(UIStoryboardSegue*)segue sender:(id)sender
{
	id dvc = [segue destinationViewController];
	if ([dvc isKindOfClass:[ViewerViewController class]]) {
		//ViewerViewController* dest = (ViewerViewController*)dvc;
		TableCellTama* cell = (TableCellTama*)sender;
		mData.tamaViewer = [mData.tamaObjects objectAtIndex:cell.objectIndex];
	}
}


#pragma mark - PTP/IP Operations.

- (void)reloadTamaObjects

{
	LOG_FUNC
#if TARGET_IPHONE_SIMULATOR
	return;
#endif
	
	[SVProgressHUD showWithStatus:NSLocalizedString(@"Lz.Reloading", nil) //再読込...
						 maskType:SVProgressHUDMaskTypeGradient];

	[mData.tamaObjects removeAllObjects];
	
//	[mData.ptpConnection getDeviceInfo:^(const PtpIpDeviceInfo* info) {
//		// "GetDeviceInfo" completion callback.
//		// This block is running at PtpConnection#gcd thread.
//		LOG(@"DeviceInfo:%@", info);
//	}];
	
	[mData.ptpConnection operateSession:^(PtpIpSession *session) {
		// This block is running at PtpConnection#gcd thread.
		
		// Setting the RICOH THETA's clock.
		// 'setDateTime' convert from specified date/time to local-time, and send to RICOH THETA.
		// RICOH THETA work with local-time, without timezone.
		[session setDateTime:[NSDate dateWithTimeIntervalSinceNow:0]];
		
		// Get object handles for primary images.
		NSArray* objectHandles = [session getObjectHandles];
		LOG(@"getObjectHandles() recevied %zd handles.", objectHandles.count);
		
		// Get object informations and thumbnail images for each primary images.
		NSInteger cnt = objectHandles.count - 20;

		for (NSNumber* it in objectHandles) {
			if (0 < cnt) {
				cnt--;
			} else {
				uint32_t objectHandle = (uint32_t)it.integerValue;
				PtpObject * obj = [self loadObject:objectHandle session:session];
				if (obj != nil) {
					[mData.tamaObjects addObject:obj];
				}
			}
		}
		dispatch_async_main(^{
			[self.tableView reloadData];
			[self bottomTableView:self.tableView animated:NO]; //最終行へ
			mTableBottom = YES;
			[SVProgressHUD dismiss];
		});
	}];
}

- (PtpObject*)loadObject:(uint32_t)objectHandle session:(PtpIpSession*)session
{
	// This method MUST be running at PtpConnection#gcd thread.
	
	// Get object informations.
	// It containes filename, capture-date and etc.
	PtpIpObjectInfo* objectInfo = [session getObjectInfo:objectHandle];
	if (!objectInfo) {
		LOG(@"getObjectInfo(0x%08x) failed.", objectHandle);
		return nil;
	}
	
	UIImage* thumb;
	if (objectInfo.object_format==PTPIP_FORMAT_JPEG) {
		// Get thumbnail image.
		NSMutableData* thumbData = [NSMutableData data];
		BOOL result = [session getThumb:objectHandle
							onStartData:^(NSUInteger totalLength) {
								// Callback before thumb-data reception.
								LOG(@"getThumb(0x%08x) will received %zd bytes.", objectHandle, totalLength);
							}
							onChunkReceived:^BOOL(NSData *data) {
								// Callback for each chunks.
								[thumbData appendData:data];
								// Continue to receive.
								return YES;
							}];
		if (!result) {
			LOG(@"getThumb(0x%08x) failed.", objectHandle);
			thumb = nil; //[UIImage imageNamed:@"TheTama-Tran-NG.svg"];
		} else {
			thumb = [UIImage imageWithData:thumbData];
		}
	} else {
		thumb = nil; //[UIImage imageNamed:@"TheTama-Tran-NG.svg"];
	}
	return [[PtpObject alloc] initWithObjectInfo:objectInfo thumbnail:thumb];
}



#pragma mark - UITableViewDataSource delegates.

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return mData.tamaObjects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
	TableCellTama* cell;
	
//	if (indexPath.section==0) {
//		cell = [tableView dequeueReusableCellWithIdentifier:@"cameraInfo"];
//		cell.textLabel.text = [NSString stringWithFormat:@"%d[shots] %lld/%lld[MB] free",
//							   mStorageInfo.free_space_in_images,
//							   mStorageInfo.free_space_in_bytes/1000/1000,
//							   mStorageInfo.max_capacity/1000/1000];
//		cell.detailTextLabel.text = [NSString stringWithFormat:@"BATT %zd %%", mData.batteryLevel];
//	} else
	
	// NSDateFormatter to display photographing date.
	// You MUST specify `[df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]`
	// to display photographing date('PtpIpObjectInfo#capture_date') in the local time.
	// As a result, 'PtpIpObjectInfo#capture_date' and 'kCGImagePropertyExifDateTimeOriginal' will match.
	NSDateFormatter* df = [[NSDateFormatter alloc] init];
	[df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
	[df setDateStyle:NSDateFormatterShortStyle];
	[df setTimeStyle:NSDateFormatterMediumStyle];
	
	PtpObject* obj = [mData.tamaObjects objectAtIndex:indexPath.row];
	assert(obj);
	cell = [tableView dequeueReusableCellWithIdentifier:@"cellTama"];
	cell.textLabel.text = [df stringFromDate:obj.objectInfo.capture_date];
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", obj.objectInfo.filename];
	cell.imageView.image = obj.thumbnail;
	cell.objectIndex = (uint32_t)indexPath.row;
	// cell.imageViewのコーナを丸くする
	[[cell.imageView layer] setCornerRadius:12.0];
	[cell.imageView setClipsToBounds:YES];

	return cell;
}

/// 最終行を表示する
- (void)bottomTableView:(UITableView *)tableView animated:(BOOL)animated
{
	long section = [tableView numberOfSections] - 1;
	long row = [tableView numberOfRowsInSection:section] - 1;
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
	[tableView scrollToRowAtIndexPath:indexPath
					  atScrollPosition:UITableViewScrollPositionBottom
							  animated:animated];
}


//#pragma mark Data Source Loading / Reloading Methods
//
//- (void)reloadTableViewDataSource{
//	
//	//  should be calling your tableviews data source model to reload
//	//  put here just for demo
//	_reloading = YES;
//	
//	
//	[self onReloadTouchUpIn:nil];
//}
//
//- (void)doneLoadingTableViewData
//{	// 更新終了をライブラリに通知
//	_reloading = NO;
//	[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
//}

#pragma mark UIScrollViewDelegate Methods
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	[mRefreshHeaderView egoRefreshScrollViewDidScroll:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	[mRefreshHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
}

#pragma mark EGORefreshTableHeaderDelegate Methods

- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view
{	// テーブルを下に引っ張って離せば、ここが呼ばれる
	mReloading = YES;
	// 非同期処理
	NSOperationQueue *queue = [[NSOperationQueue alloc] init];
	[queue addOperationWithBlock:^{
		// 更新処理など重い処理を書く

		if (mData.option1Pay) {
			[self reloadTamaObjects];
		}
		else {
			
		}

		
//		// 今回は3秒待ち、_cell_stringをUpdateに変更
//		[NSThread sleepForTimeInterval:3];

		//_cell_string = @"Update";
		[self.tableView reloadData];
		
		// メインスレッドで更新完了処理
		[[NSOperationQueue mainQueue] addOperationWithBlock:^{
			// 更新終了をライブラリに通知
			mReloading = NO;
			[mRefreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
		}];
	}];
}

- (BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view
{	// 更新状態を返す
	return mReloading; // should return if data source model is reloading
}

- (NSDate*)egoRefreshTableHeaderDataSourceLastUpdated:(EGORefreshTableHeaderView*)view
{	// 最終更新日表示する日付を返す
	return [NSDate date]; // should return date data source was last changed
}



#pragma mark - Life cycle.

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	AppDelegate * app = [UIApplication sharedApplication].delegate;
	mData = [app getDataObject];
	assert(mData != nil);

	// UITableView
	self.tableView.dataSource = self;
	mTableBottom = NO;
	
	//  通知受信の設定
	NSNotificationCenter*   nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(applicationWillEnterForeground) name:@"applicationWillEnterForeground" object:nil];
	[nc addObserver:self selector:@selector(applicationDidEnterBackground) name:@"applicationDidEnterBackground" object:nil];

	// View が潜り込むのを防止
	self.edgesForExtendedLayout = UIRectEdgeNone;
	// EGOTableViewPullRefresh
	if (mRefreshHeaderView == nil) {
		EGORefreshTableHeaderView *view = [[EGORefreshTableHeaderView alloc]
										   initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height,
																	self.view.frame.size.width, self.tableView.bounds.size.height)];
		view.delegate = self;
		[self.tableView addSubview:view];
		mRefreshHeaderView = view;
	
	}
	//  update the last update date
	[mRefreshHeaderView refreshLastUpdatedDate];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
#if TARGET_IPHONE_SIMULATOR
#else
	// コネクト・チェック
	if (mData.connected) {
		// Ready to PTP/IP.
		[mData.ptpConnection setLoglevel:PTPIP_LOGLEVEL_WARN];
		// PtpIpEventListener delegates.
		[mData.ptpConnection setEventListener:self]; //画面遷移の都度、デリゲート指定必須
		
		[mData.ptpConnection operateSession:^(PtpIpSession *session) {
			// Get
			mStorageInfo = [session getStorageInfo];
			mData.volumeLevel = [session getAudioVolume];
			mData.batteryLevel = [session getBatteryLevel];
		}];
	}
	else {
		[self onBackTouchUpIn:nil];
	}
#endif
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

	if (0 < mData.tamaObjects.count) {
		[self.tableView reloadData];
		if (mTableBottom==NO) {
			[self bottomTableView:self.tableView animated:NO];
			mTableBottom = YES;
		}
	}
	else {
		[self reloadTamaObjects];
	}
}

#pragma mark Memory Management
- (void)viewDidUnload {
	mRefreshHeaderView = nil;
}


- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

- (void)dealloc {
	mRefreshHeaderView = nil;
}


#pragma mark Notification

//2回目以降のフォアグラウンド実行になった際に呼び出される (Background --> Foreground)
- (void)applicationWillEnterForeground
{
	LOG_FUNC
	[self onBackTouchUpIn:nil];
}

//バックグランド実行になった際に呼び出される（Foreground --> Background)
- (void)applicationDidEnterBackground
{
	LOG_FUNC
	[self onBackTouchUpIn:nil];
}


@end
