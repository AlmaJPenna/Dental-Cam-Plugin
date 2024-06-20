#import "ViewController.h"

#define WIDTH [UIScreen mainScreen].bounds.size.width
#define HEIGHT [UIScreen mainScreen].bounds.size.height

@interface ViewController ()
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Initialize the camera and set delegate
    self.camera = [Camera sharedCamera];
    self.camera.delegate = self;
    
    // Setup the imageView to display camera feed
    self.imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 20, WIDTH, (0.75) * WIDTH)];
    self.imageView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.imageView];
    
    // Optional: Add a UI element to indicate the bottom of the camera feed
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(10, HEIGHT - 50, WIDTH - 20, 1)];
    [self.view addSubview:line];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.camera start];  // Start capturing video feed
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.camera stop];  // Stop capturing video feed to save resources
}

// Ensure that the image from the camera is set to the imageView
- (void)camera:(Camera *)camera image:(UIImage *)image appendix:(NSString *)appendix {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = image;
        self.capturedImage = image;  // Update captured image for any further processing
    });
}

- (UIImage *)getCurrentFrame {
    return self.imageView.image;  // Return the current frame for capture or other uses
}

@end
