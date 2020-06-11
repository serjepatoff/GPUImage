#import "SimpleVideoFilterViewController.h"
#import <AssetsLibrary/ALAssetsLibrary.h>
#import <Photos/Photos.h>

@interface SimpleVideoFilterViewController () <UITextViewDelegate>
@property (nonatomic, strong) NSURL *tmpVidURL;
@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) NSMutableArray<GPUImageOutput<GPUImageInput>*> *retroFilters;
@property (nonatomic, strong) NSMutableArray<GPUImageOutput<GPUImageInput>*> *colorFilters;
@property (nonatomic, strong) NSMutableArray<GPUImageOutput<GPUImageInput>*> *crushFilters;
@property (nonatomic, weak)  GPUImageOutput<GPUImageInput> *activeCrushFilter;
@property (nonatomic, assign) NSInteger currentRetroFilterIndex;
@property (nonatomic, assign) NSInteger currentCrushFilterIndex;
@property (nonatomic, assign) BOOL crushFilterRampingUp;
@property (nonatomic, assign) CGFloat crushFilterTau;
@property (nonatomic, assign) CGFloat crushFilterLowValue;
@property (nonatomic, assign) CGFloat crushFilterHighValue;
@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, assign) BOOL isFlashOn;
@property (retain, nonatomic) IBOutlet UIButton *recButton;
@property (retain, nonatomic) IBOutlet UIButton *flashButton;
@property (weak, nonatomic) IBOutlet UIButton *helpButton;
@property (nonatomic, assign) BOOL cameraPermissionGranted;
@property (nonatomic, assign) BOOL micPermissionGranted;
@property (nonatomic, assign) BOOL photoPermissionGranted;
@property (nonatomic, assign) BOOL permHintIsActive;
@property (nonatomic, weak)   UIScrollView *helpView;
@property (nonatomic, assign) NSTimeInterval tsHelpViewWasScrolled;
@property (weak, nonatomic)   IBOutlet UILabel *recInfoLabel;
@property (nonatomic, strong)          NSTimer *recInfoLabelTimer;
@property (nonatomic, assign)          NSInteger timerTicks;
@property (nonatomic, assign) NSTimeInterval recInfoStartTime;
@property (weak, nonatomic) IBOutlet UILabel *filterInfoLabel;
@property (weak, nonatomic) IBOutlet UIButton *dotsCrushBtn;
@property (weak, nonatomic) IBOutlet UIButton *ftbCrushBtn;
@property (weak, nonatomic) IBOutlet UIButton *pxCrushBtn;
@property (weak, nonatomic) IBOutlet UIButton *blurCrushBtn;
@end

@implementation SimpleVideoFilterViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _currentRetroFilterIndex = -1;
        _currentCrushFilterIndex = -1;
    }
    
    return self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadAll];
}

- (void)loadAll {
    self.view.backgroundColor = [UIColor blackColor];
    [self hideAllControls];
    [self setupPaths];
    [self requestPermissionsWithCallback:^{
        if (self.cameraPermissionGranted && self.micPermissionGranted && self.photoPermissionGranted) {
            [self showStartControls];
            self.view.backgroundColor = [UIColor lightGrayColor];
            [self setBGToView:self.recButton color:[UIColor colorWithWhite:0.0 alpha:0.15] cornerRadius:8.0];
            [self setBGToView:self.flashButton color:[UIColor colorWithWhite:0.0 alpha:0.15] cornerRadius:8.0];
            [self setBGToView:self.helpButton color:[UIColor colorWithWhite:0.0 alpha:0.15] cornerRadius:8.0];
            [self setBGToView:self.ftbCrushBtn color:[UIColor colorWithWhite:0.0 alpha:0.15] cornerRadius:8.0];
            [self setBGToView:self.blurCrushBtn color:[UIColor colorWithWhite:0.0 alpha:0.15] cornerRadius:8.0];
            [self setBGToView:self.pxCrushBtn color:[UIColor colorWithWhite:0.0 alpha:0.15] cornerRadius:8.0];
            [self setBGToView:self.dotsCrushBtn color:[UIColor colorWithWhite:0.0 alpha:0.15] cornerRadius:8.0];
            [self setBGToView:self.filterInfoLabel color:[UIColor colorWithWhite:0.0 alpha:0.15] cornerRadius:8.0];
            [self setupPaths];
            [self setupCircuit];
        }
        else {
            [self showPermHint];
        }
    }];
    
    UISwipeGestureRecognizer *swipeLeftGR = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(onEffectSwipeLeft:)];
    swipeLeftGR.direction=UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:swipeLeftGR];
    
    UISwipeGestureRecognizer *swipeRightGR = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(onEffectSwipeRight:)];
    swipeRightGR.direction=UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRightGR];
    
    self.recInfoLabelTimer = [NSTimer scheduledTimerWithTimeInterval:0.033333 target:self selector:@selector(onRecInfoLabelTimer:) userInfo:nil repeats:YES];
    self.recInfoStartTime = -1;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.permHintIsActive) {
        self.permHintIsActive = NO;
        [self loadAll];
    }
}

- (void)hideAllControls {
    self.recButton.hidden = YES;
    self.flashButton.hidden = YES;
    self.helpButton.hidden = YES;
    self.ftbCrushBtn.hidden = YES;
    self.blurCrushBtn.hidden = YES;
    self.pxCrushBtn.hidden = YES;
    self.dotsCrushBtn.hidden = YES;
    self.recInfoLabel.hidden = YES;
}

- (void)showStartControls {
    self.recButton.hidden = NO;
    self.flashButton.hidden = NO;
    self.helpButton.hidden = NO;
    self.ftbCrushBtn.hidden = NO;
    self.blurCrushBtn.hidden = NO;
    self.pxCrushBtn.hidden = NO;
    self.dotsCrushBtn.hidden = NO;
}

- (void)requestPermissionsWithCallback:(dispatch_block_t)cb {
    dispatch_block_t cb2 = ^() {
        dispatch_async(dispatch_get_main_queue(), ^{
            cb();
        });
    };
    
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted1) {
        self.cameraPermissionGranted = granted1;
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted2) {
            self.micPermissionGranted = granted2;
            PHAuthorizationStatus photoStatus = [PHPhotoLibrary authorizationStatus];
            self.photoPermissionGranted = (photoStatus == PHAuthorizationStatusAuthorized);
            if (self.photoPermissionGranted) {
                cb2();
                return;
            }
            
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus photoStatus2) {
                self.photoPermissionGranted = (photoStatus2 == PHAuthorizationStatusAuthorized);
                cb2();
                return;
            }];
        }];
    }];
}

- (void)showPermHint {
    UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"qevcam1024.png"]];
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    
    iv.contentMode = UIViewContentModeScaleToFill;
    
    [self.view addSubview:iv];
    [self.view.centerXAnchor constraintEqualToAnchor:iv.centerXAnchor].active = YES;
    [self.view.centerYAnchor constraintEqualToAnchor:iv.centerYAnchor].active = YES;
    [iv.widthAnchor constraintEqualToConstant:128.0].active = YES;
    [iv.heightAnchor constraintEqualToConstant:128.0].active = YES;
    
    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.numberOfLines = 2;
    [lbl setText:@"Go to Settings->QEV Cam\nand allow access to Microphone, Camera and Photo Album"];
    [lbl setFont:[UIFont systemFontOfSize:16.0]];
    [lbl setTextColor:[UIColor lightTextColor]];
    [self.view addSubview:lbl];
    [lbl.topAnchor constraintEqualToAnchor:iv.bottomAnchor constant:-8.0].active = YES;
    [lbl.centerXAnchor constraintEqualToAnchor:iv.centerXAnchor constant:0.0].active = YES;
    self.permHintIsActive = YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscapeRight;
}

- (void)setupPaths {
    NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.mov"];
    unlink([pathToMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
    self.tmpVidURL = [NSURL fileURLWithPath:pathToMovie];
}

- (void)setupCircuit {
    self.videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1920x1080 cameraPosition:AVCaptureDevicePositionBack];
    self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeRight;
    self.videoCamera.horizontallyMirrorFrontFacingCamera = NO;
    self.videoCamera.horizontallyMirrorRearFacingCamera = NO;

    [self setupFilterChain];
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
    
    [self recreateMovieWriter];
    [self.videoCamera startCameraCapture];
}

- (void)setupFilterChain {
    if (self.retroFilters.count) {
        [self.videoCamera removeAllTargets];
        [self.retroFilters enumerateObjectsUsingBlock:^(GPUImageOutput<GPUImageInput> *f, NSUInteger idx, BOOL * _Nonnull stop) {
            [f removeAllTargets];
        }];
        [self.colorFilters enumerateObjectsUsingBlock:^(GPUImageOutput<GPUImageInput> *f, NSUInteger idx, BOOL * _Nonnull stop) {
            [f removeAllTargets];
        }];
        [self.crushFilters enumerateObjectsUsingBlock:^(GPUImageOutput<GPUImageInput> *f, NSUInteger idx, BOOL * _Nonnull stop) {
            [f removeAllTargets];
        }];
    }
    else {
        self.retroFilters = [NSMutableArray arrayWithCapacity:12];
    
        {
            GPUImageOutput<GPUImageInput> *puyoF = [[GPUImageCustomLUTFilter alloc] initWithLUTName:@"puyo"];
            puyoF.qevName = @"Mojo";
            [self.retroFilters addObject:puyoF];
        }
    
        {
            GPUImageOutput<GPUImageInput> *birdF = [[GPUImageCustomLUTFilter alloc] initWithLUTName:@"bird"];
            birdF.qevName = @"Bird";
            [self.retroFilters addObject:birdF];
        }
        
        {
            GPUImageOutput<GPUImageInput> *brikF = [[GPUImageCustomLUTFilter alloc] initWithLUTName:@"brick"];
            brikF.qevName = @"Brick";
            [self.retroFilters addObject:brikF];
        }
        
        {
            GPUImageOutput<GPUImageInput> *etikateF = [[GPUImageCustomLUTFilter alloc] initWithLUTName:@"miss_etikate"];
            etikateF.qevName = @"Funky times";
            [self.retroFilters addObject:etikateF];
        }
        
//        {
//            GPUImageOutput<GPUImageInput> *elegF = [[GPUImageSoftEleganceFilter alloc] init];
//            elegF.qevName = @"Eleg";
//            [self.retroFilters addObject:elegF];
//        }
        
        {
            GPUImageSepiaFilter *sepiaF = [[GPUImageSepiaFilter alloc] init];
            sepiaF.intensity = 1.0;
            sepiaF.qevName = @"Sepia";
            [self.retroFilters addObject:sepiaF];
        }
        
        {
            GPUImageSaturationFilter *satF = [[GPUImageSaturationFilter alloc] init];
            satF.saturation = 0.0;
            satF.qevName = @"Valve TV";
            [self.retroFilters addObject:satF];
        }
        
        {
            GPUImageColorInvertFilter *invF = [[GPUImageColorInvertFilter alloc] init];
            invF.qevName = @"Inversion";
            [self.retroFilters addObject:invF];
        }
        
        {
            GPUImageFalseColorFilter *fcF = [[GPUImageFalseColorFilter alloc] init];
            fcF.qevName = @"Alien";
            [self.retroFilters addObject:fcF];
        }
        
        {
            GPUImageLowPassFilter *lpF = [[GPUImageLowPassFilter alloc] init];
            lpF.qevName = @"Dizziness";
            lpF.filterStrength = 0.55;
            [self.retroFilters addObject:lpF];
        }
        
        {
            GPUImageMonochromeFilter *monoF = [[GPUImageMonochromeFilter alloc] init];
            monoF.intensity = 1.0;
            monoF.color = (GPUVector4){0.0, 1.0, 0.0, 1.0};
            monoF.qevName = @"70's display";
            [self.retroFilters addObject:monoF];
        }
        
        self.colorFilters = [NSMutableArray arrayWithCapacity:4];
        
        {
            GPUImageExposureFilter *f = [[GPUImageExposureFilter alloc] init];
            [self.colorFilters addObject:f];
        }
        
        {
            GPUImageHSBFilter *f = [[GPUImageHSBFilter alloc] init];
            [self.colorFilters addObject:f];
        }
        
        self.crushFilters = [NSMutableArray arrayWithCapacity:4];
        
        {
            GPUImagePolkaDotFilter *f = [[GPUImagePolkaDotFilter alloc] init];
            f.qevName = @"dots";
            f.fractionalWidthOfAPixel = 0.0;
            [self.crushFilters addObject:f];
        }
        
        {
            GPUImageBrightnessFilter *f = [[GPUImageBrightnessFilter alloc] init];
            f.qevName = @"ftb";
            f.brightness = 0.0;
            [self.crushFilters addObject:f];
        }
        
        {
            GPUImagePixellateFilter *f = [[GPUImagePixellateFilter alloc] init];
            f.qevName = @"px";
            f.fractionalWidthOfAPixel = 0.0;
            [self.crushFilters addObject:f];
        }
        
        {
            
            GPUImageiOSBlurFilter *f = [[GPUImageiOSBlurFilter alloc] init];
            f.qevName = @"blur";
            f.saturation = 1.0;
            f.blurRadiusInPixels = 0.0;
            [self.crushFilters addObject:f];
        }
    }
    
    if (self.currentRetroFilterIndex >= 0) {
        [self.videoCamera addTarget:self.retroFilters[self.currentRetroFilterIndex]];
        [self.retroFilters[self.currentRetroFilterIndex] addTarget:self.colorFilters.firstObject];
    }
    else {
        [self.videoCamera addTarget:self.colorFilters.firstObject];
    }
    
    [self.colorFilters[0] addTarget:self.colorFilters[1]];
    
    GPUImageView *camPreview = (GPUImageView *)self.view;
    camPreview.fillMode = kGPUImageFillModePreserveAspectRatioAndFill; //kGPUImageFillModeStretch
    
    if (self.currentCrushFilterIndex >= 0) {
        [self.colorFilters.lastObject addTarget:self.crushFilters[self.currentCrushFilterIndex]];
        [self.crushFilters[self.currentCrushFilterIndex] addTarget:camPreview];
        if (self.movieWriter) {
            [self.crushFilters[self.currentCrushFilterIndex] addTarget:self.movieWriter];
        }
    }
    else {
        [self.colorFilters.lastObject addTarget:camPreview];
        if (self.movieWriter) {
            [self.colorFilters.lastObject addTarget:self.movieWriter];
        }
    }
}

- (void)updateAfterRetroFilterChange {
    [self.videoCamera removeAllTargets];
    [self.retroFilters enumerateObjectsUsingBlock:^(GPUImageOutput<GPUImageInput> *f, NSUInteger idx, BOOL * _Nonnull stop) {
        [f removeAllTargets];
    }];
    
    if (self.currentRetroFilterIndex >= 0) {
        [self.videoCamera addTarget:self.retroFilters[self.currentRetroFilterIndex]];
        [self.retroFilters[self.currentRetroFilterIndex] addTarget:self.colorFilters.firstObject];
        self.filterInfoLabel.text = [NSString stringWithFormat:@"<< %@ >>", self.retroFilters[self.currentRetroFilterIndex].qevName];
    }
    else {
        [self.videoCamera addTarget:self.colorFilters.firstObject];
        self.filterInfoLabel.text = @"<< No filter >>";
    }
}

- (void)updateAfterCrushFilterIndexChange {
    [self.colorFilters.lastObject removeAllTargets];
    [self.crushFilters enumerateObjectsUsingBlock:^(GPUImageOutput<GPUImageInput> *f, NSUInteger idx, BOOL * _Nonnull stop) {
        [f removeAllTargets];
    }];
    
    GPUImageView *camPreview = (GPUImageView *)self.view;
    camPreview.fillMode = kGPUImageFillModePreserveAspectRatioAndFill; //kGPUImageFillModeStretch
    
    if (self.currentCrushFilterIndex >= 0) {
        [self.colorFilters.lastObject addTarget:self.crushFilters[self.currentCrushFilterIndex]];
        [self.crushFilters[self.currentCrushFilterIndex] addTarget:camPreview];
        if (self.movieWriter) {
            [self.crushFilters[self.currentCrushFilterIndex] addTarget:self.movieWriter];
        }
    }
    else {
        [self.colorFilters.lastObject addTarget:camPreview];
        if (self.movieWriter) {
            [self.colorFilters.lastObject addTarget:self.movieWriter];
        }
    }
}

- (void)recreateMovieWriter {
    if (self.movieWriter) {
        if (self.currentCrushFilterIndex >= 0) {
            [self.crushFilters[self.currentCrushFilterIndex] removeTarget:self.movieWriter];
        }
        else {
            [self.colorFilters.lastObject removeTarget:self.movieWriter];
        }
        
        self.videoCamera.audioEncodingTarget = nil;
        self.movieWriter = nil;
        [self setupPaths];
    }
    
    self.movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:self.tmpVidURL size:CGSizeMake(1920.0, 1080.0)];
    self.movieWriter.encodingLiveVideo = YES;
    if (self.currentCrushFilterIndex >= 0) {
        [self.crushFilters[self.currentCrushFilterIndex] addTarget:self.movieWriter];
    }
    else {
        [self.colorFilters.lastObject addTarget:self.movieWriter];
    }
    
    self.videoCamera.audioEncodingTarget = self.movieWriter;
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return NO; // Support all orientations.
}

- (IBAction)onRecButton:(id)sender {
    if (self.helpView) {
        [self hideHelp];
        return;
    }
    
    if (!self.isRecording) {
        NSLog(@"Start recording");
        self.recInfoStartTime = CACurrentMediaTime();
        [self.movieWriter startRecording];
        
        self.isRecording = YES;
        [self.recButton setTitle:@"■" forState:UIControlStateNormal];
        self.recInfoLabel.hidden = NO;
    }
    else {
        [self.movieWriter finishRecording];
        [self.videoCamera stopCameraCapture];
        NSLog(@"Movie completed");
        self.recInfoStartTime = -1;
        
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
                     self.isFlashOn = NO;
                     [self onFlashStateUpdated];
                     self.recInfoLabel.hidden = YES;
                     [self.recButton setTitle:@"●" forState:UIControlStateNormal];
                     [self recreateMovieWriter];
                     [self.videoCamera startCameraCapture];
                 });
             }];
        }
    }
}

- (IBAction)onFlashButton:(id)sender {
    if (self.helpView) {
        [self hideHelp];
        return;
    }
    
    if (!self.videoCamera.hasFlash) {
        return;
    }
    
    self.isFlashOn = !self.isFlashOn;
    
    [self.videoCamera.inputCamera lockForConfiguration:nil];
    [self.videoCamera.inputCamera setTorchMode:self.isFlashOn ? AVCaptureTorchModeOn : AVCaptureTorchModeOff];
    [self.videoCamera.inputCamera unlockForConfiguration];
    
    [self onFlashStateUpdated];
}

- (void)onFlashStateUpdated {
    if (self.isFlashOn) {
        [self.flashButton setImage:[UIImage imageNamed:@"torch_icon"] forState:UIControlStateNormal];
    }
    else {
        [self.flashButton setImage:[UIImage imageNamed:@"torch_icon_w"] forState:UIControlStateNormal];
    }
}

- (void)setHaloToButton:(UIButton *)btn color:(UIColor *)clr radius:(CGFloat)radius offset:(CGSize)offset {
    btn.titleLabel.layer.shadowOffset = offset;
    btn.titleLabel.layer.shadowColor = clr.CGColor;
    btn.titleLabel.layer.shadowRadius = radius;
    btn.titleLabel.layer.shadowOpacity = 1.0;
    btn.titleLabel.layer.masksToBounds = NO;
}

- (void)setBGToView:(UIView *)view color:(UIColor *)clr cornerRadius:(CGFloat)radius {
    view.layer.cornerRadius = radius;
    view.layer.backgroundColor = clr.CGColor;
}

- (void)dealloc {
    self.recButton = nil;
    self.flashButton = nil;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (IBAction)onHelpButton:(id)sender {
    if (self.isRecording) {
        return;
    }
    
    if (self.helpView) {
        [self hideHelp];
        return;
    }
    else {
        [self showHelp];
    }
}

- (void)showHelp {
    UITextView *tv = [UITextView new];
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    tv.scrollEnabled = YES;
    tv.userInteractionEnabled = YES;
    tv.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.20];
    tv.textColor = [UIColor whiteColor];
    tv.font = [UIFont systemFontOfSize:15.0];
    tv.textContainer.lineFragmentPadding = 16.0;
    tv.alwaysBounceHorizontal = NO;
    tv.showsHorizontalScrollIndicator = NO;
    tv.layer.cornerRadius = 8.0;
    tv.editable = NO;
    tv.text = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"help" ofType:@"txt"]
                                        encoding:NSUTF8StringEncoding
                                           error:NULL];
    tv.alpha = 0.0;
    [self.view addSubview:tv];
    
    [self.view.centerXAnchor constraintEqualToAnchor:tv.centerXAnchor].active = YES;
    [self.view.centerYAnchor constraintEqualToAnchor:tv.centerYAnchor].active = YES;
    [tv.widthAnchor constraintEqualToConstant:400.0].active = YES;
    [tv.heightAnchor constraintEqualToConstant:288.0].active = YES;
    
    tv.delegate = self;
    
    [tv addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideHelp)]];
    
    self.helpView = tv;
    
    CGFloat bsw = [[UIScreen mainScreen] bounds].size.width;
    BOOL hideCrushAndTopLabel = bsw < 668;
    
    [UIView animateWithDuration:0.25 animations:^{
        tv.alpha = 1.0;
        if (hideCrushAndTopLabel) {
            self.blurCrushBtn.alpha = 0.0;
            self.filterInfoLabel.alpha = 0.0;
        }
    }];
}

- (void)hideHelp {
    CGFloat bsw = [[UIScreen mainScreen] bounds].size.width;
    BOOL revealCrushAndTopLabel = bsw < 668;
    
    [UIView animateWithDuration:0.25 animations:^
    {
        self.helpView.alpha = 0.0;
        if (revealCrushAndTopLabel) {
            self.blurCrushBtn.alpha = 1.0;
            self.filterInfoLabel.alpha = 1.0;
        }
    }
                     completion:^(BOOL finished)
    {
        self.helpView.delegate = nil;
        [self.helpView removeFromSuperview];
        self.helpView = nil;
    }];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    _tsHelpViewWasScrolled = CACurrentMediaTime();
}

//override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//    if let _ = event?.touches(for: renderView)?.first {
//        picout.onlyCaptureNextFrame = true
//
//        picout.imageAvailableCallback = {image in
//            PHPhotoLibrary.shared().performChanges({
//                _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
//            }) { (_, _) in
//                //UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
//            }
//        }
//    }
//}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.helpView != nil) {
        if (CACurrentMediaTime() - _tsHelpViewWasScrolled > 0.5) {
            [self hideHelp];
        }
    }
}

- (void)onEffectSwipeLeft:(UISwipeGestureRecognizer*)gestureRecognizer {
    if (self.retroFilters.count == 0 || self.helpView != nil) {
        return;
    }
    
    if (self.currentRetroFilterIndex == 0) {
        self.currentRetroFilterIndex = -1;
    }
    else if (self.currentRetroFilterIndex == -1) {
        self.currentRetroFilterIndex = self.retroFilters.count - 1;
    }
    else {
        self.currentRetroFilterIndex--;
    }
    
    [self updateAfterRetroFilterChange];
}

- (void)onEffectSwipeRight:(UISwipeGestureRecognizer*)gestureRecognizer {
    if (self.retroFilters.count == 0 || self.helpView != nil) {
        return;
    }
    
    if (self.currentRetroFilterIndex == (self.retroFilters.count - 1)) {
        self.currentRetroFilterIndex = -1;
    }
    else if (self.currentRetroFilterIndex == -1) {
        self.currentRetroFilterIndex = 0;
    }
    else {
        self.currentRetroFilterIndex++;
    }
    
    [self updateAfterRetroFilterChange];
}

- (void)onRecInfoLabelTimer:(id)sender {
    _timerTicks++;
    
    if (_currentCrushFilterIndex >= 0 && _activeCrushFilter != nil) {
        CGFloat vFrom = _crushFilterLowValue;
        CGFloat vTo = _crushFilterHighValue;
        if (!_crushFilterRampingUp) {
            vFrom = _crushFilterHighValue;
            vTo = _crushFilterLowValue;
        }
        
        CGFloat vCurrent = 0.0;
        BOOL linearRampUp = _crushFilterTau > 1.0;
        
        switch (_currentCrushFilterIndex) {
            case 0: vCurrent = ((GPUImagePolkaDotFilter *)(self.activeCrushFilter)).fractionalWidthOfAPixel; break;
            case 1: vCurrent = ((GPUImageBrightnessFilter *)(self.activeCrushFilter)).brightness; break;
            case 2: vCurrent = ((GPUImagePixellateFilter *)(self.activeCrushFilter)).fractionalWidthOfAPixel; break;
            case 3: vCurrent = ((GPUImageiOSBlurFilter *)(self.activeCrushFilter)).blurRadiusInPixels; break;
        }
        
        vCurrent -= vFrom;
        vCurrent /= (vTo - vFrom);
        if (linearRampUp) {
            vCurrent += _crushFilterTau * 0.01;
        }
        else {
            vCurrent = _crushFilterTau + (1.0 - _crushFilterTau) * vCurrent;
        }
        
        if (vCurrent > 1.0) vCurrent = 1.0;
        else if (vCurrent < 0.0) vCurrent = 0.0;
        
        BOOL shouldStop = _crushFilterRampingUp == NO && fabs(vCurrent - 1.0) < 0.01;
        
        vCurrent *= (vTo - vFrom);
        vCurrent += vFrom;
        
        switch (_currentCrushFilterIndex) {
            case 0: ((GPUImagePolkaDotFilter *)(self.activeCrushFilter)).fractionalWidthOfAPixel = vCurrent; break;
            case 1: ((GPUImageBrightnessFilter *)(self.activeCrushFilter)).brightness = vCurrent; break;
            case 2: ((GPUImagePixellateFilter *)(self.activeCrushFilter)).fractionalWidthOfAPixel = vCurrent; break;
            case 3: ((GPUImageiOSBlurFilter *)(self.activeCrushFilter)).blurRadiusInPixels = vCurrent; break;
        }
        
        if (shouldStop) {
            self.currentCrushFilterIndex = -1;
            self.activeCrushFilter = nil;
            [self updateAfterCrushFilterIndexChange];
        }
    }
    
    if ((_timerTicks % 15) == 0 && self.recInfoStartTime > 0) {
        NSUInteger elapsedSeconds = (int)(CACurrentMediaTime() - self.recInfoStartTime);
        NSUInteger h = elapsedSeconds / 3600;
        NSUInteger m = (elapsedSeconds / 60) % 60;
        NSUInteger s = elapsedSeconds % 60;
        NSString *formattedTime = [NSString stringWithFormat:@"● %02u:%02u:%02u", h, m, s];
        self.recInfoLabel.text = formattedTime;
    }
}

- (IBAction)onDotsCrushBtnDown:(id)sender {
    if (self.helpView) {
        [self hideHelp];
        return;
    }
    
    if (self.currentCrushFilterIndex >= 0) {
        self.crushFilterRampingUp = YES;
        return;
    }
    
    self.currentCrushFilterIndex = 0;
    self.activeCrushFilter = self.crushFilters[self.currentCrushFilterIndex];
    self.crushFilterRampingUp = YES;
    self.crushFilterLowValue = 0.0;
    self.crushFilterHighValue = 0.05;
    self.crushFilterTau = 5.0;
    ((GPUImagePolkaDotFilter *)(self.activeCrushFilter)).fractionalWidthOfAPixel = self.crushFilterLowValue;
    [self updateAfterCrushFilterIndexChange];
}

- (IBAction)onDotsCrushBtnUp:(id)sender {
    self.crushFilterRampingUp = NO;
}

- (IBAction)onFtbCrushBtnDown:(id)sender {
    if (self.helpView) {
        [self hideHelp];
        return;
    }
    
    if (self.currentCrushFilterIndex >= 0) {
        self.crushFilterRampingUp = YES;
        return;
    }
    
    self.currentCrushFilterIndex = 1;
    self.activeCrushFilter = self.crushFilters[self.currentCrushFilterIndex];
    self.crushFilterRampingUp = YES;
    self.crushFilterLowValue = 0.0;
    self.crushFilterHighValue = -1.0;
    self.crushFilterTau = 12.0;
    ((GPUImageBrightnessFilter *)(self.activeCrushFilter)).brightness = self.crushFilterLowValue;
    [self updateAfterCrushFilterIndexChange];
}

- (IBAction)onFtbCrushBtnUp:(id)sender {
    self.crushFilterRampingUp = NO;
}

- (IBAction)onPxCrushBtnDown:(id)sender {
    if (self.helpView) {
        [self hideHelp];
        return;
    }
    
    if (self.currentCrushFilterIndex >= 0) {
        self.crushFilterRampingUp = YES;
        return;
    }
    
    self.currentCrushFilterIndex = 2;
    self.activeCrushFilter = self.crushFilters[self.currentCrushFilterIndex];
    self.crushFilterRampingUp = YES;
    self.crushFilterLowValue = 0.0;
    self.crushFilterHighValue = 0.07;
    self.crushFilterTau = 7.0;
    ((GPUImagePixellateFilter *)(self.activeCrushFilter)).fractionalWidthOfAPixel = self.crushFilterLowValue;
    [self updateAfterCrushFilterIndexChange];
}

- (IBAction)onPxCrushBtnUp:(id)sender {
    self.crushFilterRampingUp = NO;
}

- (IBAction)onBlurCrushBtnDown:(id)sender {
    if (self.helpView) {
        [self hideHelp];
        return;
    }
    
    if (self.currentCrushFilterIndex >= 0) {
        self.crushFilterRampingUp = YES;
        return;
    }
    
    self.currentCrushFilterIndex = 3;
    self.activeCrushFilter = self.crushFilters[self.currentCrushFilterIndex];
    self.crushFilterRampingUp = YES;
    self.crushFilterLowValue = 0.0;
    self.crushFilterHighValue = 16.0;
    self.crushFilterTau = 8.0;
    ((GPUImageiOSBlurFilter *)(self.activeCrushFilter)).blurRadiusInPixels = self.crushFilterLowValue;
    [self updateAfterCrushFilterIndexChange];
}

- (IBAction)onBlurCrushBtnUp:(id)sender {
    self.crushFilterRampingUp = NO;
}

@end
