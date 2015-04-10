//
//  ViewerViewController.m
//  TheTama
//
//  Created by masa on 2015/04/07.
//  Copyright (c) 2015年 Azukid. All rights reserved.
//

#import "ViewerViewController.h"

@interface ViewerViewController ()

@end

@implementation ViewerViewController


#pragma mark - UI events.

- (IBAction)onBackTouchUpIn:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
}



- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
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
