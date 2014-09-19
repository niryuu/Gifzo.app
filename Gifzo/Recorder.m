//
//  Recorder.m
//  Gifzo
//
//  Created by uiureo on 13/05/08.
//  Copyright (c) 2013年 uiureo. All rights reserved.
//

#import "Recorder.h"

@implementation Recorder {
    AVCaptureSession *_captureSession;
    AVCaptureStillImageOutput *_stillImageOutput;
    NSTimer *_timer;
    CGImageDestinationRef _dest;
    NSString *_path;
    NSMutableArray *_stillImageArray;
}

- (void)startRecordingWithOutputURL:(NSURL *)outputFileURL croppingRect:(NSRect)rect screen:(NSScreen *)screen
{
    _stillImageArray = [NSMutableArray array];
    NSString *home = NSHomeDirectory();
    _path = [home stringByAppendingString:@"/Desktop/animated.gif"];
    _captureSession = [[AVCaptureSession alloc] init];

    _captureSession.sessionPreset = AVCaptureSessionPresetHigh;

    NSDictionary *screenDictionary = [screen deviceDescription];
    NSNumber *screenID = [screenDictionary objectForKey:@"NSScreenNumber"];

    CGDirectDisplayID displayID = [screenID unsignedIntValue];

    AVCaptureScreenInput *input = [[AVCaptureScreenInput alloc] initWithDisplayID:displayID];
    [input setCropRect:NSRectToCGRect(rect)];

    if ([_captureSession canAddInput:input]) {
        [_captureSession addInput:input];
    }

    _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];

    if ([_captureSession canAddOutput:_stillImageOutput]) {
        [_captureSession addOutput:_stillImageOutput];
    }

    [_captureSession startRunning];

    if ([[NSFileManager defaultManager] fileExistsAtPath:[outputFileURL path]]) {
        NSError *err;
        if (![[NSFileManager defaultManager] removeItemAtPath:[outputFileURL path] error:&err]) {
            NSLog(@"Error deleting existing movie %@", [err localizedDescription]);
        }
    }

    _timer = [NSTimer scheduledTimerWithTimeInterval:0.2f target:self selector:@selector(captureStillImage:) userInfo:nil repeats:YES];
    
}

- (void)captureStillImage:(NSTimer *)timer
{
    AVCaptureConnection *connection = [[_stillImageOutput connections] lastObject];
    [_stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        [_stillImageArray addObject:data];
    }];
}

- (void)finishRecording
{
    NSLog(@"finish recording");
    [_timer invalidate];
    _dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:_path], kUTTypeGIF, [_stillImageArray count], nil);
    NSDictionary *frameProperties = [NSDictionary dictionaryWithObject:
                                     [NSDictionary dictionaryWithObject:
                                      [NSNumber numberWithFloat:0.2f] forKey:(NSString *)kCGImagePropertyGIFDelayTime]
                                                                forKey:(NSString *)kCGImagePropertyGIFDictionary];
    NSDictionary *gifProperties = [NSDictionary dictionaryWithObject:
                                   [NSDictionary dictionaryWithObject:
                                    [NSNumber numberWithInt:0] forKey:(NSString *)kCGImagePropertyGIFLoopCount]
                                                              forKey:(NSString *)kCGImagePropertyGIFDictionary];
    
    for(NSData* data in _stillImageArray) {
        CGDataProviderRef imgDataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)(data));
        CGImageRef imageRef = CGImageCreateWithJPEGDataProvider(imgDataProvider, NULL, true, kCGRenderingIntentDefault);
        CGImageDestinationAddImage(_dest, imageRef, (__bridge CFDictionaryRef)frameProperties);
    }
    CGImageDestinationSetProperties(_dest, (__bridge CFDictionaryRef)gifProperties);
    CGImageDestinationFinalize(_dest);
    CFRelease(_dest);
    [self.delegate performSelector:@selector(saveGIF:) withObject:nil];
}

@end
