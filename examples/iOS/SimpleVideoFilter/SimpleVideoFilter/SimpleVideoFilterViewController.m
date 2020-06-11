#import "SimpleVideoFilterViewController.h"
#import <AssetsLibrary/ALAssetsLibrary.h>

@interface SimpleVideoFilterViewController ()
@property (nonatomic, strong) NSURL *tmpVidURL;
@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *filter;
@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, assign) BOOL isFlashOn;
@property (retain, nonatomic) IBOutlet UIButton *recButton;
@property (retain, nonatomic) IBOutlet UIButton *flashButton;
@end

@implementation SimpleVideoFilterViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    
    return self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    //[self setHaloToButton:self.recButton color:[UIColor blackColor] radius:4.0 offset:CGSizeMake(0, 0)];
    [self setBGToButton:self.recButton color:[UIColor colorWithWhite:0.0 alpha:0.15] cornerRadius:8.0];
    [self setBGToButton:self.flashButton color:[UIColor colorWithWhite:0.0 alpha:0.15] cornerRadius:8.0];
    [self setupPaths];
    [self setupVideoCamera];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscapeRight;
}

- (void)setupPaths {
    NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.mov"];
    unlink([pathToMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
    self.tmpVidURL = [NSURL fileURLWithPath:pathToMovie];
}

- (void)setupVideoCamera {
    self.videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1920x1080 cameraPosition:AVCaptureDevicePositionBack];
    self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeRight;
    self.videoCamera.horizontallyMirrorFrontFacingCamera = NO;
    self.videoCamera.horizontallyMirrorRearFacingCamera = NO;
    
    self.flashButton.hidden = !self.videoCamera.hasFlash;

//    filter = [[GPUImageSepiaFilter alloc] init];
//    filter.intensity = 1.0;
//    filter = [[GPUImageTiltShiftFilter alloc] init];
//    [(GPUImageTiltShiftFilter *)filter setTopFocusLevel:0.65];
//    [(GPUImageTiltShiftFilter *)filter setBottomFocusLevel:0.85];
//    [(GPUImageTiltShiftFilter *)filter setBlurSize:1.5];
//    [(GPUImageTiltShiftFilter *)filter setFocusFallOffRate:0.2];
    
//    filter = [[GPUImageSketchFilter alloc] init];
//    filter = [[GPUImageColorInvertFilter alloc] init];
//    filter = [[GPUImageSmoothToonFilter alloc] init];
//    GPUImageRotationFilter *rotationFilter = [[GPUImageRotationFilter alloc] initWithRotation:kGPUImageRotateRightFlipVertical];
    
    self.filter = [[GPUImageCustomLUTFilter alloc] initWithLUTName:@"miss_etikate"];
    
    [self.videoCamera addTarget:self.filter];
    GPUImageView *camPreview = (GPUImageView *)self.view;
    camPreview.fillMode = kGPUImageFillModePreserveAspectRatioAndFill; //kGPUImageFillModeStretch
    
    [self recreateMovieWriter];
    [self.filter addTarget:camPreview];
    
    [self.videoCamera startCameraCapture];
}

- (void)recreateMovieWriter {
    if (self.movieWriter) {
        [self.filter removeTarget:self.movieWriter];
        self.videoCamera.audioEncodingTarget = nil;
        self.movieWriter = nil;
        [self setupPaths];
    }
    
    self.movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:self.tmpVidURL size:CGSizeMake(1920.0, 1080.0)];
    self.movieWriter.encodingLiveVideo = YES;
    [self.filter addTarget:self.movieWriter];
    self.videoCamera.audioEncodingTarget = self.movieWriter;
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return NO; // Support all orientations.
}

- (IBAction)updateSliderValue:(id)sender {
    [(GPUImageSepiaFilter *)self.filter setIntensity:[(UISlider *)sender value]];
}

- (IBAction)onRecButton:(id)sender {
    if (!self.isRecording) {
        NSLog(@"Start recording");
        
        [self.movieWriter startRecording];
        
        self.isRecording = YES;
        [self.recButton setTitle:@"■" forState:UIControlStateNormal];
    }
    else {
        [self.movieWriter finishRecording];
        [self.videoCamera stopCameraCapture];
        NSLog(@"Movie completed");
        
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:self.tmpVidURL])
        {
            [library writeVideoAtPathToSavedPhotosAlbum:self.tmpVidURL completionBlock:^(NSURL *assetURL, NSError *error) {
                 dispatch_async(dispatch_get_main_queue(), ^{
//                     if (error) {
//                         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"
//                                                                        delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//                         [alert show];
//                     } else {
//                         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album"
//                                                                        delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
//                         [alert show];
//                     }
                     
                     self.isRecording = NO;
                     [self.recButton setTitle:@"●" forState:UIControlStateNormal];
                     [self recreateMovieWriter];
                     [self.videoCamera startCameraCapture];
                 });
             }];
        }
    }
}

- (IBAction)onFlashButton:(id)sender {
    self.isFlashOn = !self.isFlashOn;
    
    if (self.isFlashOn) {
        
    }
    else {
        
    }
    
    [self.videoCamera.inputCamera lockForConfiguration:nil];
    [self.videoCamera.inputCamera setTorchMode:self.isFlashOn ? AVCaptureTorchModeOn : AVCaptureTorchModeOff];
    [self.videoCamera.inputCamera unlockForConfiguration];
}

- (void)setHaloToButton:(UIButton *)btn color:(UIColor *)clr radius:(CGFloat)radius offset:(CGSize)offset {
    btn.titleLabel.layer.shadowOffset = offset;
    btn.titleLabel.layer.shadowColor = clr.CGColor;
    btn.titleLabel.layer.shadowRadius = radius;
    btn.titleLabel.layer.shadowOpacity = 1.0;
    btn.titleLabel.layer.masksToBounds = NO;
}

- (void)setBGToButton:(UIButton *)btn color:(UIColor *)clr cornerRadius:(CGFloat)radius {
    btn.layer.cornerRadius = radius;
    btn.layer.backgroundColor = clr.CGColor;
}

- (void)dealloc {
    self.recButton = nil;
    self.flashButton = nil;
}
@end
