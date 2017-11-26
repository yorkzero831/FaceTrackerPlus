//
//  SessionHandler.h
//  FaceTrackerPlus
//
//  Created by york on 2017/11/26.
//  Copyright © 2017年 FaceTrackerPlus. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface SessionHandler : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate>

- (void) openSession;

- (AVSampleBufferDisplayLayer*) getLayer;

@end
