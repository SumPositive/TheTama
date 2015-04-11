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
#import "TableCell.h"

#import "ViewerViewController.h"


inline static void dispatch_async_main(dispatch_block_t block)
{
	dispatch_async(dispatch_get_main_queue(), block);
}

@interface ListViewController () <PtpIpEventListener, UITableViewDelegate, UITableViewDataSource>
{
	DataObject * mData;
	PtpIpStorageInfo * mStorageInfo;
}
@property (nonatomic, strong) IBOutlet UITableView * contentsView;
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

- (void)prepareForSegue:(UIStoryboardSegue*)segue sender:(id)sender
{
	id dvc = [segue destinationViewController];
	if ([dvc isKindOfClass:[ViewerViewController class]]) {
		//ViewerViewController* dest = (ViewerViewController*)dvc;
		TableCell* cell = (TableCell*)sender;
		mData.tamaObject = [mData.tamaObjects objectAtIndex:cell.objectIndex];
	}
}


#pragma mark - PTP/IP Operations.


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
	TableCell* cell;
	
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
	cell = [tableView dequeueReusableCellWithIdentifier:@"customCell"];
	cell.textLabel.text = [df stringFromDate:obj.objectInfo.capture_date];
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", obj.objectInfo.filename];
	cell.imageView.image = obj.thumbnail;
	cell.objectIndex = (uint32_t)indexPath.row;
	// cell.imageViewのコーナを丸くする
	[[cell.imageView layer] setCornerRadius:20.0];
	[cell.imageView setClipsToBounds:YES];

	return cell;
}

#pragma mark - Life cycle.

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	AppDelegate * app = [UIApplication sharedApplication].delegate;
	mData = [app getDataObject];
	assert(mData != nil);

	// UITableView
	self.contentsView.dataSource = self;
	
	//  通知受信の設定
	NSNotificationCenter*   nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(applicationWillEnterForeground) name:@"applicationWillEnterForeground" object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	// PtpIpEventListener delegates.
	[mData.ptpConnection setEventListener:self];

	[mData.ptpConnection operateSession:^(PtpIpSession *session) {
		// Get Volume level.
		mStorageInfo = [session getStorageInfo];
	}];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	[self.contentsView reloadData];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

//2回目以降のフォアグラウンド実行になった際に呼び出される(Backgroundにアプリがある場合)
- (void)applicationWillEnterForeground
{
	NSLog(@"applicationWillEnterForeground");
	
	[self onBackTouchUpIn:nil];
}


@end
