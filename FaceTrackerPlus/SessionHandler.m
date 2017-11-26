//
//  SessionHandler.m
//  FaceTrackerPlus
//
//  Created by york on 2017/11/26.
//  Copyright © 2017年 FaceTrackerPlus. All rights reserved.
//

#import "SessionHandler.h"
#import "DlibWrapper.h"

@implementation SessionHandler {
    AVCaptureSession *session;
    AVSampleBufferDisplayLayer *layer;
    dispatch_queue_t SampleQueue;
    dispatch_queue_t faceQueue;
    NSArray *currentMetaData;
    DlibWrapper *wrapper;
}


- (instancetype)init {
    session = [[AVCaptureSession alloc] init];
    layer = [[AVSampleBufferDisplayLayer alloc] init];
    SampleQueue = dispatch_queue_create("york.FaceTrackerPlus.sampleQueque", nil);
    faceQueue = dispatch_queue_create("york.FaceTrackerPlus.faceQueue", nil);
    currentMetaData = [NSArray array];
    wrapper = [[DlibWrapper alloc] init];
    
    return [super init];
}

- (AVSampleBufferDisplayLayer*)getLayer {
    return layer;
}

- (void) openSession {
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                 mediaType:AVMediaTypeVideo
                                                                 position:AVCaptureDevicePositionFront];
    if (device == nil){
        NSLog(@"Failed on getting captureDevice");
        return;
    }
    
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    
    AVCaptureVideoDataOutput *output =[[AVCaptureVideoDataOutput alloc] init];
    [output setSampleBufferDelegate:self queue: SampleQueue];
    
    AVCaptureMetadataOutput *metaOutput = [[AVCaptureMetadataOutput alloc] init];
    [metaOutput setMetadataObjectsDelegate:self queue:faceQueue];

    
    [session beginConfiguration];
    
    if ([session canAddInput:deviceInput]) {
        [session addInput:deviceInput];
    }
    if ([session canAddOutput:output]) {
        [session addOutput:output];
    }
    if ([session canAddOutput:metaOutput]) {
        [session addOutput:metaOutput];
    }
    
    AVCaptureConnection *videoConnection = [output connectionWithMediaType:AVMediaTypeVideo];
    [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    [videoConnection setVideoMirrored:YES];
    
    AVCaptureConnection *metaConnection = [metaOutput connectionWithMediaType:AVMediaTypeMetadata];
    [metaConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    [metaConnection setVideoMirrored:YES];
    
    
    
    
//    if ([session canAddConnection:connection]) {
//        [session addConnection:connection];
//    }

#ifdef YORKDEBUG
    //Set Medium Resolution When Build With Debug
    if([session canSetSessionPreset:AVCaptureSessionPresetMedium]){
        [session setSessionPreset:AVCaptureSessionPresetMedium];
    }
#else
    //Set High Resolution When Build With Release
    if([session canSetSessionPreset:AVCaptureSessionPreset1280x720]){
        [session setSessionPreset:AVCaptureSessionPreset1280x720];
    }
#endif
    
    [session commitConfiguration];
    
    NSDictionary *settings = @{
                               (id)kCVPixelBufferPixelFormatTypeKey:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                               };
    
    [output setVideoSettings:settings];
    
    metaOutput.metadataObjectTypes = @[AVMetadataObjectTypeFace];
    
    if (wrapper != nil) {
        [wrapper prepare];
    }
    
    [session startRunning];
}

- (UIImage *)imageFromSampleBufferRef:(CMSampleBufferRef)sampleBuffer
{
    // Get Image Buffer
    CVImageBufferRef    buffer;
    buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // Lock Image Buffer
    CVPixelBufferLockBaseAddress(buffer, 0);
    // Get Image Buffer Data
    uint8_t*    base;
    size_t      width, height, bytesPerRow;
    base = CVPixelBufferGetBaseAddress(buffer);
    width = CVPixelBufferGetWidth(buffer);
    height = CVPixelBufferGetHeight(buffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    
    // Create BitMapContext
    CGColorSpaceRef colorSpace;
    CGContextRef    cgContext;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    cgContext = CGBitmapContextCreate(
                                      base, width, height, 8, bytesPerRow, colorSpace,
                                      kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    
    // Create Image
    CGImageRef  cgImage;
    UIImage*    image;
    cgImage = CGBitmapContextCreateImage(cgContext);
    image = [UIImage imageWithCGImage:cgImage scale:1.0f
                          orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
    
    // Unlock Image Buffer
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    return image;
}

- (void) captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSLog(@"DidDropSampleBuffer");
}

- (void) captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    if (currentMetaData.count != 0) {
        NSMutableArray *boundsArray = [NSMutableArray array];
        for (AVMetadataObject *object in currentMetaData) {
            AVMetadataObject* convertedObject = [output transformedMetadataObjectForMetadataObject:object connection:connection];
            [boundsArray addObject:[NSValue valueWithCGRect: convertedObject.bounds]];
        }
        
        if (wrapper != nil) {
            [wrapper doWorkOnSampleBuffer:sampleBuffer inRects:boundsArray];
        }
    }
    
    [layer enqueueSampleBuffer:sampleBuffer];
}

- (void) captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    currentMetaData = metadataObjects;
}

@end
