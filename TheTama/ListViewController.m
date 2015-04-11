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


//inline static void dispatch_async_main(dispatch_block_t block)
//{
//	dispatch_async(dispatch_get_main_queue(), block);
//}

@interface ListViewController () <UITableViewDelegate, UITableViewDataSource>
{
	DataObject * mData;
}
//@property (nonatomic, strong) IBOutlet UIButton * buBack;
@property (nonatomic, strong) IBOutlet UITableView * contentsView;
@end


@implementation ListViewController

#pragma mark - PtpIpEventListener delegates.

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
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section==0) {
		return [mData.ptpConnection connected] ? 1: 0;
	}
	return mData.tamaObjects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
	TableCell* cell;
	
	if (indexPath.section==0) {
		cell = [tableView dequeueReusableCellWithIdentifier:@"cameraInfo"];
		cell.textLabel.text = [NSString stringWithFormat:@"%d[shots] %lld/%lld[MB] free",
							   mData.storageInfo.free_space_in_images,
							   mData.storageInfo.free_space_in_bytes/1000/1000,
							   mData.storageInfo.max_capacity/1000/1000];
		cell.detailTextLabel.text = [NSString stringWithFormat:@"BATT %zd %%", mData.batteryLevel];
	} else {
		// NSDateFormatter to display photographing date.
		// You MUST specify `[df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]`
		// to display photographing date('PtpIpObjectInfo#capture_date') in the local time.
		// As a result, 'PtpIpObjectInfo#capture_date' and 'kCGImagePropertyExifDateTimeOriginal' will match.
		NSDateFormatter* df = [[NSDateFormatter alloc] init];
		[df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
		[df setDateStyle:NSDateFormatterShortStyle];
		[df setTimeStyle:NSDateFormatterMediumStyle];
		
		PtpObject* obj = [mData.tamaObjects objectAtIndex:indexPath.row];
		cell = [tableView dequeueReusableCellWithIdentifier:@"customCell"];
		cell.textLabel.text = [df stringFromDate:obj.objectInfo.capture_date];
		cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", obj.objectInfo.filename];
		cell.imageView.image = obj.thumbnail;
		cell.objectIndex = (uint32_t)indexPath.row;
	}
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
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
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
