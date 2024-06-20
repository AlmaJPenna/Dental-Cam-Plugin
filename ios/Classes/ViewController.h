#import <UIKit/UIKit.h>
#import <Flutter/Flutter.h>
#import <BFL_SDK/Camera.h>
#import <BFL_SDK/BFL_SDK.h>

@interface ViewController : UIViewController <CameraDelegate>
@property (nonatomic, strong, readwrite) UIImage *capturedImage;
@property (nonatomic, strong, readwrite) Camera *camera;
@property (nonatomic, strong, readwrite) UIImageView *imageView;

- (UIImage *)getCurrentFrame;


@end
