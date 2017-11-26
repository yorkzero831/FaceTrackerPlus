//
//  ViewController.m
//  FaceTrackerPlus
//
//  Created by york on 2017/11/26.
//  Copyright © 2017年 FaceTrackerPlus. All rights reserved.
//

#import "ViewController.h"
#import "SessionHandler.h"

@interface ViewController ()

@end

@implementation ViewController{
    SessionHandler *sessionHandler;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    sessionHandler = [[SessionHandler alloc] init];
    
    [sessionHandler openSession];
    
    AVSampleBufferDisplayLayer *layer = [sessionHandler getLayer];
    CGRect rect = _videoView.bounds;
    layer.frame = _videoView.bounds;
    
    [_videoView.layer addSublayer:layer];
    
    //[self.view layoutIfNeeded];
    
}


@end
