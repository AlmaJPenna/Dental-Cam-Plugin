#import "DentalCameraS700cPlugin.h"
#import <Flutter/Flutter.h>
#import "CameraView.h"
#import <UIKit/UIKit.h>

@interface CameraViewFactory : NSObject <FlutterPlatformViewFactory>
@property (nonatomic, strong) CameraView *cameraView;
@end

@implementation CameraViewFactory

- (instancetype)init {
    self = [super init];
    if (self) {
        _cameraView = [[CameraView alloc] initWithFrame:CGRectZero viewIdentifier:0 arguments:nil];
    }
    return self;
}

- (NSObject<FlutterPlatformView> *)createWithFrame:(CGRect)frame viewIdentifier:(int64_t)viewId arguments:(id)args {
    // Potresti voler creare una nuova istanza di CameraView qui se necessario
    return _cameraView;
}

@end

@interface DentalCameraS700cPlugin ()
@property (nonatomic, strong) FlutterMethodChannel *channel;
@property (nonatomic, strong) CameraViewFactory *cameraViewFactory;
@end

@implementation DentalCameraS700cPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
        methodChannelWithName:@"dental_camera_s700c_plugin"
              binaryMessenger:[registrar messenger]];
    DentalCameraS700cPlugin* instance = [[DentalCameraS700cPlugin alloc] init];
    instance.channel = channel; // Memorizza il canale per un uso futuro
    [registrar addMethodCallDelegate:instance channel:channel];

    CameraViewFactory* cameraViewFactory = [[CameraViewFactory alloc] init];
    [registrar registerViewFactory:cameraViewFactory withId:@"my_uikit_view"];
    instance.cameraViewFactory = cameraViewFactory; // Associa la factory all'istanza del plugin
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"foto_ios" isEqualToString:call.method]) {
        NSLog(@"[DEBUG] foto_ios method call received");
        [self.cameraViewFactory.cameraView capturePhotoWithResult:result];
    } else if ([@"startVideoRecording" isEqualToString:call.method]) {
        NSLog(@"[DEBUG] startVideoRecording method call received");
        [self.cameraViewFactory.cameraView startVideoRecordingWithResult:result];
        [self.channel invokeMethod:@"RECORDING_STARTED" arguments:nil];
    } else if ([@"stopVideoRecording" isEqualToString:call.method]) {
        NSLog(@"[DEBUG] stopVideoRecording method call received");
        [self.cameraViewFactory.cameraView stopVideoRecordingWithResult:result];
        [self.channel invokeMethod:@"RECORDING_STOPPED" arguments:nil];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end
