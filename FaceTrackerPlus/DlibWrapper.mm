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

#include <dlib/opencv.h>

#include <opencv2/highgui/highgui.hpp>
#include <opencv2/calib3d/calib3d.hpp>

//it will be an per-row buffer offset appear when debug mode
#ifdef YORKDEBUG
#define BUFFER_OFF_SET 8
#endif

@interface DlibWrapper ()

@property (assign) BOOL prepared;

+ (std::vector<dlib::rectangle>)convertCGRectValueArray:(NSArray<NSValue *> *)rects;

@end
@implementation DlibWrapper {
    dlib::shape_predictor sp;
    
    //text on screen
    std::ostringstream outtext;
    
    std::vector<cv::Point3d> reprojectsrc;
    cv::Mat cam_matrix;
    cv::Mat dist_coeffs;
    std::vector<cv::Point3d> object_pts;
    std::vector<cv::Point2d> reprojectdst;
    
    //temp buf for decomposeProjectionMatrix()
    cv::Mat out_intrinsics;
    cv::Mat out_rotation;
    cv::Mat out_translation;
    
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
    
    [self prepareOpenCv];
}

- (void)prepareOpenCv {
    
    double height = 0.0;
    double width = 0.0;
#ifdef YORKDEBUG
    double K[9] = { 4.4438896541316552e+02, 0., 1.8302040876554358e+02, 0., 4.4487809482886513e+02, 2.4090034545907616e+02, 0., 0., 1. };
    double D[5] = { -1.5191077603745984e-01, 3.6301626740026665e+00, 8.0031819769552895e-04, 1.4423302411267826e-04, -1.6362191503389809e+01 };
    height = 480;
    width = 360;
#else
    double K[9] = { 12.8000000000000000e+02, 0., 6.4000000000000000e+02, 0., 12.8000000000000000e+02, 3.6000000000000000e+02, 0., 0., 1. };
    double D[5] = { -5.5995247272374843e-02, 1.9497813562100241e+00, 6.8687974646744108e-04, -1.5102601349837024e-03, -7.4122846033527345e+00 };
    height = 1280;
    width = 720;
#endif
    
    
    //fill in 3D ref points(world coordinates), model referenced from http://aifi.isr.uc.pt/Downloads/OpenGL/glAnthropometric3DModel.cpp
    object_pts.push_back(cv::Point3d(6.825897, 6.760612, 4.402142));     //#33 left brow left corner
    object_pts.push_back(cv::Point3d(1.330353, 7.122144, 6.903745));     //#29 left brow right corner
    object_pts.push_back(cv::Point3d(-1.330353, 7.122144, 6.903745));    //#34 right brow left corner
    object_pts.push_back(cv::Point3d(-6.825897, 6.760612, 4.402142));    //#38 right brow right corner
    object_pts.push_back(cv::Point3d(5.311432, 5.485328, 3.987654));     //#13 left eye left corner
    object_pts.push_back(cv::Point3d(1.789930, 5.393625, 4.413414));     //#17 left eye right corner
    object_pts.push_back(cv::Point3d(-1.789930, 5.393625, 4.413414));    //#25 right eye left corner
    object_pts.push_back(cv::Point3d(-5.311432, 5.485328, 3.987654));    //#21 right eye right corner
    object_pts.push_back(cv::Point3d(2.005628, 1.409845, 6.165652));     //#55 nose left corner
    object_pts.push_back(cv::Point3d(-2.005628, 1.409845, 6.165652));    //#49 nose right corner
    object_pts.push_back(cv::Point3d(2.774015, -2.080775, 5.048531));    //#43 mouth left corner
    object_pts.push_back(cv::Point3d(-2.774015, -2.080775, 5.048531));   //#39 mouth right corner
    object_pts.push_back(cv::Point3d(0.000000, -3.116408, 6.097667));    //#45 mouth central bottom corner
    object_pts.push_back(cv::Point3d(0.000000, -7.415691, 4.070434));    //#6 chin corner
    
    //fill in cam intrinsics and distortion coefficients
//    cam_matrix = cv::Mat(3, 3, CV_64FC1, K);
//    dist_coeffs = cv::Mat(5, 1, CV_64FC1, D);
    cv::Point2d center = cv::Point2d(height/2,width/2);
    cam_matrix = (cv::Mat_<double>(3,3) << height, 0, center.x, 0 , height, center.y, 0, 0, 1);
    dist_coeffs = cv::Mat::zeros(4,1,cv::DataType<double>::type);
    
    std::cout << "cam_matrix = "<< std::endl << " "  << cam_matrix << std::endl << std::endl;
    std::cout << "dist_coeffs = "<< std::endl << " "  << dist_coeffs << std::endl << std::endl;
    
    float time = 0.5;
    reprojectsrc.push_back(cv::Point3d(10.0, 10.0, 10.0) * time);
    reprojectsrc.push_back(cv::Point3d(10.0, 10.0, -10.0) * time);
    reprojectsrc.push_back(cv::Point3d(10.0, -10.0, -10.0) * time);
    reprojectsrc.push_back(cv::Point3d(10.0, -10.0, 10.0) * time);
    reprojectsrc.push_back(cv::Point3d(-10.0, 10.0, 10.0) * time);
    reprojectsrc.push_back(cv::Point3d(-10.0, 10.0, -10.0) * time);
    reprojectsrc.push_back(cv::Point3d(-10.0, -10.0, -10.0) * time);
    reprojectsrc.push_back(cv::Point3d(-10.0, -10.0, 10.0) * time);
    
    //reprojected 2D points
    reprojectdst.resize(8);
    
    //temp buf for decomposeProjectionMatrix()
    out_intrinsics = cv::Mat(3, 3, CV_64FC1);
    out_rotation = cv::Mat(3, 3, CV_64FC1);
    out_translation = cv::Mat(3, 1, CV_64FC1);
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
    long colCount = 0;
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
#ifdef YORKDEBUG
        colCount++;
        if(colCount == width){
            position += BUFFER_OFF_SET;
            colCount = 0;
        }
#endif
    }
    
    // unlock buffer again until we need it again
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    // convert the face bounds list to dlib format
    std::vector<dlib::rectangle> convertedRectangles = [DlibWrapper convertCGRectValueArray:rects];
    
    // for every detected face
    for (unsigned long j = 0; j < convertedRectangles.size(); ++j)
    {
        dlib::rectangle oneFaceRect = convertedRectangles[j];

        // detect all landmarks
        dlib::full_object_detection shape = sp(img, oneFaceRect);

        // and draw them into the image (samplebuffer)
        for (unsigned long k = 0; k < shape.num_parts(); k++) {
            dlib::point p = shape.part(k);
            draw_solid_circle(img, p, 3, dlib::rgb_pixel(0, 255, 255));
        }
    }
    
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
        
#ifdef YORKDEBUG
        colCount++;
        if(colCount == width){
            position += BUFFER_OFF_SET ;
            colCount = 0;
        }
#endif
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

- (void)doWorkOnSampleBuffer:(CMSampleBufferRef)sampleBuffer inRects:(NSArray<NSValue *> *)rects {
    
    if (!self.prepared) {
        [self prepare];
    }
    
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    
    size_t bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
    size_t bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    //unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    char *baseBuffer = (char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    cv::Mat image = cv::Mat(bufferHeight, bufferWidth, CV_8UC4, baseBuffer, bytesPerRow);
    
    dlib::cv_image<dlib::rgb_alpha_pixel> cimg(image);
    
    std::vector<dlib::rectangle> convertedRectangles = [DlibWrapper convertCGRectValueArray:rects];
    
    for (unsigned long j = 0; j < convertedRectangles.size(); ++j) {
        dlib::rectangle oneFaceRect = convertedRectangles[j];
        // detect all landmarks
        dlib::full_object_detection shape = sp(cimg, oneFaceRect);
        
        //draw Point
        for (unsigned int i = 0; i < 68; ++i)
        {
            circle(image, cv::Point(shape.part(i).x(), shape.part(i).y()), 2, cv::Scalar(0, 0, 255), -1);
        }
        
        for (unsigned int i = 0; i < object_pts.size(); ++i) {
            circle(image, cv::Point(object_pts[i].x, object_pts[i].y), 2, cv::Scalar(0, 0, 255), -1);
        }
        
        std::vector<cv::Point2d> image_pts;
        //fill in 2D ref points, annotations follow https://ibug.doc.ic.ac.uk/resources/300-W/
        image_pts.push_back(cv::Point2d(shape.part(17).x(), shape.part(17).y())); //#17 left brow left corner
        image_pts.push_back(cv::Point2d(shape.part(21).x(), shape.part(21).y())); //#21 left brow right corner
        image_pts.push_back(cv::Point2d(shape.part(22).x(), shape.part(22).y())); //#22 right brow left corner
        image_pts.push_back(cv::Point2d(shape.part(26).x(), shape.part(26).y())); //#26 right brow right corner
        image_pts.push_back(cv::Point2d(shape.part(36).x(), shape.part(36).y())); //#36 left eye left corner
        image_pts.push_back(cv::Point2d(shape.part(39).x(), shape.part(39).y())); //#39 left eye right corner
        image_pts.push_back(cv::Point2d(shape.part(42).x(), shape.part(42).y())); //#42 right eye left corner
        image_pts.push_back(cv::Point2d(shape.part(45).x(), shape.part(45).y())); //#45 right eye right corner
        image_pts.push_back(cv::Point2d(shape.part(31).x(), shape.part(31).y())); //#31 nose left corner
        image_pts.push_back(cv::Point2d(shape.part(35).x(), shape.part(35).y())); //#35 nose right corner
        image_pts.push_back(cv::Point2d(shape.part(48).x(), shape.part(48).y())); //#48 mouth left corner
        image_pts.push_back(cv::Point2d(shape.part(54).x(), shape.part(54).y())); //#54 mouth right corner
        image_pts.push_back(cv::Point2d(shape.part(57).x(), shape.part(57).y())); //#57 mouth central bottom corner
        image_pts.push_back(cv::Point2d(shape.part(8).x(), shape.part(8).y()));   //#8 chin corner
        
        
        //result
        cv::Mat rotation_vec;                           //3 x 1
        cv::Mat rotation_mat;                           //3 x 3 R
        cv::Mat translation_vec;                        //3 x 1 T
        cv::Mat pose_mat = cv::Mat(3, 4, CV_64FC1);     //3 x 4 R | T
        cv::Mat euler_angle = cv::Mat(3, 1, CV_64FC1);
        
        //calc pos
        cv::solvePnP(object_pts, image_pts, cam_matrix, dist_coeffs, rotation_vec, translation_vec);
//        std::cout << "rotation_vec = "<< std::endl << " "  << rotation_vec << std::endl << std::endl;
//        std::cout << "translation_vec = "<< std::endl << " "  << translation_vec << std::endl << std::endl;
        
        //reproject
        cv::projectPoints(reprojectsrc, rotation_vec, translation_vec, cam_matrix, dist_coeffs, reprojectdst);
        
        
        //draw axis
        line(image, reprojectdst[0], reprojectdst[1], cv::Scalar(0, 0, 255));
        line(image, reprojectdst[1], reprojectdst[2], cv::Scalar(0, 0, 255));
        line(image, reprojectdst[2], reprojectdst[3], cv::Scalar(0, 0, 255));
        line(image, reprojectdst[3], reprojectdst[0], cv::Scalar(0, 0, 255));
        line(image, reprojectdst[4], reprojectdst[5], cv::Scalar(0, 0, 255));
        line(image, reprojectdst[5], reprojectdst[6], cv::Scalar(0, 0, 255));
        line(image, reprojectdst[6], reprojectdst[7], cv::Scalar(0, 0, 255));
        line(image, reprojectdst[7], reprojectdst[4], cv::Scalar(0, 0, 255));
        line(image, reprojectdst[0], reprojectdst[4], cv::Scalar(0, 0, 255));
        line(image, reprojectdst[1], reprojectdst[5], cv::Scalar(0, 0, 255));
        line(image, reprojectdst[2], reprojectdst[6], cv::Scalar(0, 0, 255));
        line(image, reprojectdst[3], reprojectdst[7], cv::Scalar(0, 0, 255));
    
        
        
        //calc euler angle
        cv::Rodrigues(rotation_vec, rotation_mat);
        cv::hconcat(rotation_mat, translation_vec, pose_mat);
        cv::decomposeProjectionMatrix(pose_mat, out_intrinsics, out_rotation, out_translation, cv::noArray(), cv::noArray(), cv::noArray(), euler_angle);
        
        //show angle result
        outtext << "X: " << std::setprecision(3) << euler_angle.at<double>(0);
        cv::putText(image, outtext.str(), cv::Point(50, 40), cv::FONT_HERSHEY_SIMPLEX, 0.75, cv::Scalar(0, 0, 0));
        outtext.str("");
        outtext << "Y: " << std::setprecision(3) << euler_angle.at<double>(1);
        cv::putText(image, outtext.str(), cv::Point(50, 60), cv::FONT_HERSHEY_SIMPLEX, 0.75, cv::Scalar(0, 0, 0));
        outtext.str("");
        outtext << "Z: " << std::setprecision(3) << euler_angle.at<double>(2);
        cv::putText(image, outtext.str(), cv::Point(50, 80), cv::FONT_HERSHEY_SIMPLEX, 0.75, cv::Scalar(0, 0, 0));
        outtext.str("");

    }
    
    //cv::putText(image, "Test", cv::Point(50, 40), cv::FONT_HERSHEY_SIMPLEX, 0.75, cv::Scalar(0, 0, 0));
    
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
}

@end
