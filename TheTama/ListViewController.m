//
//  ListViewController.m
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

//#import "SVProgressHUD.h"
#import "MRProgress.h"		// http://cocoadocs.org/docsets/MRProgress/0.2.2/

#import "Azukid.h"
#import "TheTama-Swift.h"
#import "Capture.h"

#import "ListViewController.h"
#import "PtpConnection.h"
#import "PtpLogging.h"
#import "PtpObject.h"
#import "TableCellTama.h"

#import "CaptureViewController.h"
#import "ViewerViewController.h"


inline static void dispatch_async_main(dispatch_block_t block)
{
	dispatch_async(dispatch_get_main_queue(), block);
}

@interface ListViewController () <CaptureDelegate, UITableViewDelegate, UITableViewDataSource>
{
	DataObject *	mData;
	Capture *		mCapture;

	PtpIpStorageInfo *	mStorageInfo;
	BOOL				mTableBottom;
	UIRefreshControl *	mRefreshControl;
	//NSInteger			mIndexPrev;
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
		[self progressOff];
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
		[self progressOff];
		// Back Model Connect View
		[self dismissViewControllerAnimated:YES completion:nil];
	});
}


#pragma mark - UI events.

- (IBAction)onBackTouchUpIn:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onReloadTouchUpIn:(id)sender
{
	[self reloadTamaObjects];
}

- (void)prepareForSegue:(UIStoryboardSegue*)segue sender:(id)sender
{
	id dvc = [segue destinationViewController];

	if ([dvc isKindOfClass:[ViewerViewController class]]) {	// ViewerViewController:へ遷移するとき
		//ViewerViewController* dest = (ViewerViewController*)dvc;
		TableCellTama* cell = (TableCellTama*)sender;
		mData.tamaViewer = [mData.tamaObjects objectAtIndex:cell.objectIndex];
	}
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


#pragma mark - PTP/IP Operations.

- (void)reloadTamaObjects
{
	LOG_FUNC
#if TARGET_IPHONE_SIMULATOR
	return;
#endif
	
	[mCapture.connection operateSession:^(PtpIpSession *session) {
		// This block is running at PtpConnection#gcd thread.
		
		// Setting the RICOH THETA's clock.
		// 'setDateTime' convert from specified date/time to local-time, and send to RICOH THETA.
		// RICOH THETA work with local-time, without timezone.
		[session setDateTime:[NSDate dateWithTimeIntervalSinceNow:0]];
		
		// Get object handles for primary images.
		NSArray* objectHandles = [session getObjectHandles];
		LOG(@"getObjectHandles() recevied %zd handles.", objectHandles.count);
		
		// Get object informations and thumbnail images for each primary images.
		NSArray * arPrev;
		NSRange rgTama;

		if ([mData.tamaObjects count] <= 0) {
			if (LIST_CHUNK_FIRST < objectHandles.count) {
				rgTama.location = objectHandles.count - LIST_CHUNK_FIRST;
				rgTama.length = LIST_CHUNK_FIRST;
			} else {
				rgTama.location = 0;
				rgTama.length = objectHandles.count;
			}
			arPrev = nil;
		}
		else {
			NSInteger indexPrev = [objectHandles count] - [mData.tamaObjects count] - 1;
			if (LIST_CHUNK_NEXT < indexPrev) {
				rgTama.location = indexPrev - LIST_CHUNK_NEXT;
				rgTama.length = LIST_CHUNK_NEXT;
			} else {
				rgTama.location = 0;
				rgTama.length = indexPrev;
			}
			//直前のListを保存
			arPrev = [[NSArray alloc] initWithArray:mData.tamaObjects];
		}
		//Listクリア
		[mData.tamaObjects removeAllObjects];
		
		//新たにListへ追加するobjects
		NSArray * arHandles = [objectHandles subarrayWithRange: rgTama];
		
		//新たにListへ追加するPtpObject
		for (NSNumber * it in arHandles) {
			uint32_t objectHandle = (uint32_t)it.integerValue;
			PtpObject * obj = [self loadObject:objectHandle session:session];
			if (obj != nil) {
				[mData.tamaObjects addObject:obj];
			}
		}
		
		if (arPrev) {
			//直前のListがあれば末尾へ追加する
			[mData.tamaObjects addObjectsFromArray:arPrev];
		}
		
		dispatch_async_main(^{
			[self.tableView reloadData];
			//[self progressOff];
			
			if (0 < [arPrev count] && 0 < [arHandles count] && !mData.listBottom) {
				// 最上行を復元
				NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[arHandles count] inSection:0];
				[self.tableView scrollToRowAtIndexPath:indexPath
									  atScrollPosition:UITableViewScrollPositionTop
											  animated:NO];
			} else {
				// 最下行へ
				[self bottomTableView:self.tableView animated:NO];
				mData.listBottom = NO;
			}
			
			// UIRefreshControl更新終了時に呼び出す
			[mRefreshControl endRefreshing];
			[self progressOff];
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
			thumb = nil;
		} else {
			thumb = [UIImage imageWithData:thumbData];
		}
	} else {
		thumb = nil;
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

	cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
	if (obj.thumbnail) {
		cell.imageView.image = obj.thumbnail;
	} else if ([obj.objectInfo.filename hasSuffix:@".MOV"]) {
		cell.imageView.image = [UIImage imageNamed:@"Tama2.svg-Movie"];
	} else {
		cell.imageView.image = [UIImage imageNamed:@"Tama2.svg"];
	}
	// cell.imageViewのコーナを丸くする
	[[cell.imageView layer] setCornerRadius:28.0];
	[cell.imageView setClipsToBounds:YES];
	
	// Original param.
	cell.objectIndex = (uint32_t)indexPath.row;

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



#pragma mark - Life cycle.

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	AppDelegate * app = [UIApplication sharedApplication].delegate;
	mData = [app getDataObject];
	assert(mData != nil);

	mCapture = [app getCaptureObject];
	assert(mCapture != nil);

	
	// UITableView
	self.tableView.delegate = self;
	self.tableView.dataSource = self;
	mTableBottom = YES;	//最初に１度だけ最終行へ移動させる
	
	//  通知受信の設定
	NSNotificationCenter*   nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(applicationWillEnterForeground) name:@"applicationWillEnterForeground" object:nil];
	[nc addObserver:self selector:@selector(applicationDidEnterBackground) name:@"applicationDidEnterBackground" object:nil];


	// viewDidLoadなどで下記コードにて初期化し、viewDidUnloadでreleaseしてください.
	mRefreshControl = [[UIRefreshControl alloc] init];
	[mRefreshControl addTarget:self
					   action:@selector(tableRefresh:)
			 forControlEvents:UIControlEventValueChanged];
	[mRefreshControl setTintColor:[UIColor blueColor]];
	
	
	// self.refreshControl にセットする前に行うこと！
	mRefreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Loading...",nil) attributes:nil];
	
	//self.refreshControl = mRefreshControl;		//UITableViewControllerの場合
	[self.tableView addSubview:mRefreshControl];	//UITableViewの場合
}

// UIRefreshControl-Action テーブルを下へ引きずって離したとき呼び出される
- (void)tableRefresh:(id)sender
{
	NSLog(@"tableRefresh!");
	[mRefreshControl beginRefreshing];
	
	// ここにリフレッシュ時の処理を記述.
	[self reloadTamaObjects];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	mCapture.delegate = self;
	mCapture.view = self.view;

#if TARGET_IPHONE_SIMULATOR
#else
	// コネクト・チェック
	if (mCapture.connected) {
		[mCapture.connection operateSession:^(PtpIpSession *session) {
			// Get
			mStorageInfo = [session getStorageInfo];
			mCapture.batteryLevel = [session getBatteryLevel];
		}];
	}
	else {
		[self onBackTouchUpIn:nil];
	}
#endif

	if (0 < mData.tamaObjects.count) {
		//[self.tableView reloadData];
		if (mData.listBottom) {
			// 最下行へ
			[self bottomTableView:self.tableView animated:NO];
			mData.listBottom = NO;
		}
	}
	else {
		//[self progressOnTitle:NSLocalizedString(@"Loading...",nil)];
		//キャンセル可能にするため
		[MRProgressOverlayView showOverlayAddedTo:self.view
											title:NSLocalizedString(@"Loading...",nil)
											 mode:MRProgressOverlayViewModeIndeterminate
										 animated:YES
										stopBlock:^(MRProgressOverlayView *progressOverlayView) {
											// CANCEL処理
											[self progressOff];
											[self onBackTouchUpIn:nil];
											return;
										}];
		[self reloadTamaObjects];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[self.tableView reloadData];	//選択（反転）を解除するため
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

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
