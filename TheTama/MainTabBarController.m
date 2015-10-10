//
//  MainTabBarController
//  TheTama
//
//  Created by masa on 2015/09/29.
//  Copyright © 2015年 Azukid. All rights reserved.
//

#import "TheTamaBase.h"


@interface MainTabBarController ()

@end

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
	
	// Tab.0
	ConnectViewController* connectionVc = [[ConnectViewController alloc] init];
	// Tab.1
	CaptureViewController* captureVc = [[CaptureViewController alloc] init];
	// Tab.2
	
	
	NSArray* vcs = @[connectionVc, captureVc];
	
	[self setViewControllers:vcs];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
