//
//  DlibWrapper.m
//  DisplayLiveSamples
//
//  Created by Luis Reisewitz on 16.05.16.
//  Copyright © 2016 ZweiGraf. All rights reserved.
//

#import "DlibWrapper.h"
#import <UIKit/UIKit.h>

#include <dlib/image_processing.h>
#include <dlib/image_io.h>


@interface DlibWrapper ()

@property (assign) BOOL prepared;

+ (std::vector<dlib::rectangle>)convertCGRectValueArray:(NSArray<NSValue *> *)rects;

@end
@implementation DlibWrapper {
    dlib::shape_predictor sp;
}


- (instancetype)init {
    self = [super init];
    if (self) {
        _prepared = NO;
    }
    return self;
}

- (void)prepare {
    NSString *modelFileName = [[NSBundle mainBundle] pathForResource:@"shape_predictor_68_face_landmarks" ofType:@"dat"];
    std::string modelFileNameCString = [modelFileName UTF8String];
    
    dlib::deserialize(modelFileNameCString) >> sp;
    
    // FIXME: test this stuff for memory leaks (cpp object destruction)
    self.prepared = YES;
    
    [self Test];
}

- (void)Test {
    UIImage *myImg = [UIImage imageNamed:@"1.jpg"];
    CGImageRef imageRef = [myImg CGImage];
    
    
}

- (void)doWorkOnSampleBuffer:(CMSampleBufferRef)sampleBuffer inRects:(NSArray<NSValue *> *)rects {
    if (!self.prepared) {
        [self prepare];
    }
    
    dlib::array2d<dlib::bgr_pixel> img;
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    
    char *baseBuffer = (char *)CVPixelBufferGetBaseAddress(imageBuffer);
    
    // set_size expects rows, cols format
    img.set_size(height, width);
    
    // copy samplebuffer image data into dlib image format
    img.reset();
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            size_t position = (y * width + x) * 4;
            char b = baseBuffer[position];
            char g = baseBuffer[position + 1];
            char r = baseBuffer[position + 2];

            dlib::bgr_pixel newpixel(b, g, r);

            img[y][x] = newpixel;
        }
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    // lets put everything back where it belongs
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
//    img.reset();
//    for (size_t y = 0; y < height; y++) {
//        for (size_t x = 0; x < width; x++) {
//            size_t position = (y * width + x) * 4;
//            baseBuffer[position] = img[y][x].blue;
//            baseBuffer[position + 1] = img[y][x].green;
//            baseBuffer[position + 2] = img[y][x].red;
//        }
//    }
    
    [self drawPoint:baseBuffer :width :height :width :height];
    
    [self drawPoint:baseBuffer :width/2 :height/2 :width :height];
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
}

- (void)drawPoint: (char *)baseBuffer :(int) x :(int) y :(size_t)width :(size_t)heigth{
    for (int dx = -1; dx < 2; dx ++){
        for (int dy = -1; dy < 2; dy ++) {
            int px = x + dx;
            int py = y + dy;
            if(px < 0 || px > width || py < 0 || py > heigth) continue;
            size_t position = (py * (width-2) + px) * 4;
            
            baseBuffer[position] = char(0);
            baseBuffer[position + 1] = char(1);
            baseBuffer[position + 2] = char(1);
        }
    }
}


- (void)doWorkOnSampleBuffer2:(CMSampleBufferRef)sampleBuffer inRects:(NSArray<NSValue *> *)rects {
    
    if (!self.prepared) {
        [self prepare];
    }
    
    dlib::array2d<dlib::bgr_pixel> img;
    
    // MARK: magic
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    
    char *baseBuffer = (char *)CVPixelBufferGetBaseAddress(imageBuffer);
    
    // set_size expects rows, cols format
    img.set_size(height, width);
    
    // copy samplebuffer image data into dlib image format
    img.reset();
    long position = 0;
    while (img.move_next()) {
        dlib::bgr_pixel& pixel = img.element();

        // assuming bgra format here
        long bufferLocation = position * 4; //(row * width + column) * 4;
        char b = baseBuffer[bufferLocation];
        char g = baseBuffer[bufferLocation + 1];
        char r = baseBuffer[bufferLocation + 2];
        //        we do not need this
        //        char a = baseBuffer[bufferLocation + 3];
        
        dlib::bgr_pixel newpixel(b, g, r);
        pixel = newpixel;
        
        position++;
    }
    
    // unlock buffer again until we need it again
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    // convert the face bounds list to dlib format
    std::vector<dlib::rectangle> convertedRectangles = [DlibWrapper convertCGRectValueArray:rects];
    
    // for every detected face
//    for (unsigned long j = 0; j < convertedRectangles.size(); ++j)
//    {
//        dlib::rectangle oneFaceRect = convertedRectangles[j];
//
//        // detect all landmarks
//        dlib::full_object_detection shape = sp(img, oneFaceRect);
//
//        // and draw them into the image (samplebuffer)
//        for (unsigned long k = 0; k < shape.num_parts(); k++) {
//            dlib::point p = shape.part(k);
//            draw_solid_circle(img, p, 3, dlib::rgb_pixel(0, 255, 255));
//        }
//    }
    
    dlib::point p =  dlib::point(0,0);
    dlib::point p1 =  dlib::point(width,height);
    //draw_solid_circle(img, p, 3, dlib::rgb_pixel(0, 255, 255));
    draw_solid_circle(img, p1, 8, dlib::rgb_pixel(0, 255, 255));
    
    // lets put everything back where it belongs
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    // copy dlib image data back into samplebuffer
    img.reset();
    position = 0;
    while (img.move_next()) {
        dlib::bgr_pixel& pixel = img.element();
        
        // assuming bgra format here
        long bufferLocation = position * 4; //(row * width + column) * 4;
        baseBuffer[bufferLocation] = pixel.blue;
        baseBuffer[bufferLocation + 1] = pixel.green;
        baseBuffer[bufferLocation + 2] = pixel.red;
        //        we do not need this
        //        char a = baseBuffer[bufferLocation + 3];
        
        position++;
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

+ (std::vector<dlib::rectangle>)convertCGRectValueArray:(NSArray<NSValue *> *)rects {
    std::vector<dlib::rectangle> myConvertedRects;
    for (NSValue *rectValue in rects) {
        CGRect rect = [rectValue CGRectValue];
        long left = rect.origin.x;
        long top = rect.origin.y;
        long right = left + rect.size.width;
        long bottom = top + rect.size.height;
        dlib::rectangle dlibRect(left, top, right, bottom);

        myConvertedRects.push_back(dlibRect);
    }
    return myConvertedRects;
}

@end
