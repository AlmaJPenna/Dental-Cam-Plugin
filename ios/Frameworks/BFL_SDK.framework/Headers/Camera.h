//
//  Camera.h
//  BLF_SDK
//
//  Created by Neo on 2019/5/15.
//  Copyright © 2019 bouffalolab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class Camera;

@protocol CameraDelegate <NSObject>

- (void)camera:(Camera *)server image:(UIImage *)image appendix:(NSString *)appendix;
- (void)camera:(Camera *)server bytesPerSec:(NSInteger)bps framePerSec:(NSInteger)fps;
- (void)camera:(Camera *)server errorMessage:(NSString *)error;
- (void)camera:(Camera *)server Message:(int)message Electricity:(int)electricity Light:(int)light Control:(int)control;

@end

@interface Camera : NSObject
@property (nonatomic, weak) id <CameraDelegate>delegate;

@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) NSString *ackHost;
@property (nonatomic, assign) uint16_t ackPort;

+ (Camera *)sharedCamera;

- (void)start;
- (void)stop;
- (void)airParm:(NSArray *)array;
- (int) set_QPara1:(int) q1 QPara2:(int) q2 Thres1:(int) t1 Thres2:(int) t2;

@end

