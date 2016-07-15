/**
 * Based on ZXingWidgetController.
 * 
 * Copyright 2009 Jeff Verkoeyen
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "ScanViewController.h"
#import "ScanOverlayView.h"
#import "AuthenticationChallenge.h"
#import "EnrollmentChallenge.h"
#import "AuthenticationIdentityViewController.h"
#import "AuthenticationConfirmViewController.h"
#import "AuthenticationFallbackViewController.h"
#import "EnrollmentConfirmViewController.h"
#import "IdentityListViewController.h"
#import "ErrorViewController.h"
#import "MBProgressHUD.h"
#import "ServiceContainer.h"

@interface ScanViewController () <AVAudioPlayerDelegate, AVCaptureMetadataOutputObjectsDelegate, UIAlertViewDelegate>

#if HAS_AVFF
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
#endif

@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, assign, getter=isDecoding) BOOL decoding;
@property (nonatomic, strong) UIBarButtonItem *identitiesButtonItem;

@property (nonatomic, strong) IBOutlet UILabel *instructionLabel;

@property (nonatomic, strong) IBOutlet UIView *previewView;
@property (nonatomic, strong) IBOutlet ScanOverlayView *overlayView;
@property (nonatomic, strong) IBOutlet UIView *instructionsView;

@end

@implementation ScanViewController

- (instancetype)init {
    self = [super initWithNibName:@"ScanView" bundle:nil];
    if (self) {     
        self.decoding = NO;
        
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStyleBordered target:nil action:nil];
        
		NSString *filePath = [[NSBundle mainBundle] pathForResource:@"cowbell" ofType:@"wav"];
		NSURL *fileURL = [NSURL fileURLWithPath:filePath isDirectory:NO];
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];
        
		self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:nil];
		[self.audioPlayer prepareToPlay];  
        self.audioPlayer.delegate = self;
        
        self.identitiesButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"identities-icon"] style:UIBarButtonItemStyleBordered target:self action:@selector(listIdentities)];
        self.navigationItem.rightBarButtonItem = self.identitiesButtonItem;
        
    }
    
    return self;
}

- (void)setMixableAudioShouldDuckActive:(BOOL)active {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryAmbient withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
    [session setActive:active error:nil];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [self setMixableAudioShouldDuckActive:NO];
}

- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    // Implementing this delegate method also automatically stops the ducking
}
- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player {
    // Implementing this delegate method also automatically resumes the ducking
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.overlayView.points = nil;    
    
    self.instructionsView.alpha = 0.0;    
    
    if (ServiceContainer.sharedInstance.identityService.identityCount > 0) {
        self.navigationItem.rightBarButtonItem = self.identitiesButtonItem;
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
    
    [self.navigationController setToolbarHidden:YES animated:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.instructionLabel.text = NSLocalizedString(@"msg_default_status", @"QR Code scan instruction");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.decoding = YES;
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.5];
    self.instructionsView.alpha = 0.7;
    [UIView commitAnimations];
    
    [self startCameraIfAllowed];
}

- (void)startCameraIfAllowed {

    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusNotDetermined:
            [self promptForCameraAccess];
            break;
            
        case AVAuthorizationStatusAuthorized:
            [self initCapture];
            break;
            
        default:
            [self promptForCameraSettings];
            break;
    }
}

- (void)promptForCameraAccess {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self startCameraIfAllowed];
        });
    }];
}

- (void)promptForCameraSettings {
    UIAlertView *settingsPrompt = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"camera_prompt_title", @"Camera access prompt title") message:NSLocalizedString(@"camera_prompt_message", @"Camera access prompt message") delegate:self cancelButtonTitle:nil otherButtonTitles: NSLocalizedString(@"settings_app_name", @"Name of the settings app"), nil];
    [settingsPrompt show];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.navigationController setToolbarHidden:NO animated:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    self.instructionsView.alpha = 0.0;      
    
    [self stopCapture];
}

#pragma mark -
#pragma mark AlertView delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
}

#pragma mark -
#pragma mark Decoder delegates

- (void)processMetadataObject:(AVMetadataMachineReadableCodeObject *)metadataObject {
    
    #ifdef HAS_AVFF
    [self.captureSession stopRunning];    
    #endif
    
    NSMutableArray *points = [NSMutableArray array];
    for (NSDictionary *corner in metadataObject.corners)  {
        CGPoint point;
        CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)corner, &point);
        [points addObject:[NSValue valueWithCGPoint:point]];
    }
    
    self.overlayView.points = points;
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationBeginsFromCurrentState:YES];    
    [UIView setAnimationDuration:0.3];
    self.instructionsView.alpha = 0.0;
    [UIView commitAnimations];
    
    // now, in a selector, call the delegate to give this overlay time to show the points
    [self performSelector:@selector(processChallenge:) withObject:metadataObject.stringValue afterDelay:1.0];
    [self setMixableAudioShouldDuckActive:YES];
	[self.audioPlayer play];
}

#pragma mark - 
#pragma mark AVFoundation

- (void)initCapture {
    #if HAS_AVFF
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
    if ([self.captureSession canAddInput:captureInput]) {
        [self.captureSession addInput:captureInput];
    }
    
    AVCaptureMetadataOutput *captureOutput = [[AVCaptureMetadataOutput alloc] init];
    if ([self.captureSession canAddOutput:captureOutput]) {
        [self.captureSession addOutput:captureOutput];
    }
    
    [captureOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    captureOutput.metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
    
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    self.previewLayer.frame = self.view.bounds;
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.previewView.layer addSublayer:self.previewLayer];
    
    [self.captureSession startRunning];
    #endif
}

#if HAS_AVFF
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    if ([metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject *metadataObject = [metadataObjects objectAtIndex:0];
        AVMetadataMachineReadableCodeObject *transformedMetadataObject = (AVMetadataMachineReadableCodeObject *)[self.previewLayer transformedMetadataObjectForMetadataObject:metadataObject];
        [self processMetadataObject:transformedMetadataObject];
    }
}
#endif

- (void)stopCapture {
    self.decoding = NO;
    
    #if HAS_AVFF
    [self.captureSession stopRunning];
    
    if ([self.captureSession.inputs count]) {
        AVCaptureInput* input = [self.captureSession.inputs objectAtIndex:0];
        [self.captureSession removeInput:input];
    }
    
    if ([self.captureSession.outputs count]) {
        AVCaptureVideoDataOutput* output = (AVCaptureVideoDataOutput *)[self.captureSession.outputs objectAtIndex:0];
        [self.captureSession removeOutput:output];
    }

    [self.previewLayer removeFromSuperlayer];
    self.previewLayer = nil;
    self.captureSession = nil;
    #endif
}


- (void)pushViewControllerForChallenge:(NSObject *)challenge Type:(TIQRChallengeType) type {
    UIViewController *viewController = nil;
    
    switch (type) {
        case TIQRChallengeTypeAuthentication: {
            AuthenticationChallenge *authenticationChallenge = (AuthenticationChallenge *)challenge;
            if (authenticationChallenge.identity == nil) {
                AuthenticationIdentityViewController *identityViewController = [[AuthenticationIdentityViewController alloc] initWithAuthenticationChallenge:authenticationChallenge];
                viewController = identityViewController;
            } else {
                AuthenticationConfirmViewController *confirmViewController = [[AuthenticationConfirmViewController alloc] initWithAuthenticationChallenge:authenticationChallenge];
                viewController = confirmViewController;
            }
        } break;
            
        case TIQRChallengeTypeEnrollment: {
            EnrollmentConfirmViewController *confirmViewController = [[EnrollmentConfirmViewController alloc] initWithEnrollmentChallenge:(EnrollmentChallenge *)challenge];
            viewController = confirmViewController;
        }
            
        default:
            break;
    }
    
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)processChallenge:(NSString *)scanResult {
    [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
    
    [ServiceContainer.sharedInstance.challengeService startChallengeFromScanResult:scanResult completionHandler:^(TIQRChallengeType type, NSObject *challengeObject, NSError *error) {
        
        [MBProgressHUD hideHUDForView:self.navigationController.view animated:YES];
        
        if (type != TIQRChallengeTypeInvalid) {
            [self pushViewControllerForChallenge:challengeObject Type:type];
        } else {
            ErrorViewController *viewController = [[ErrorViewController alloc] initWithErrorTitle:error.localizedDescription errorMessage:error.localizedFailureReason];
            [self.navigationController pushViewController:viewController animated:YES];
        }
        
    }];
}

- (void)listIdentities {
    IdentityListViewController *viewController = [[IdentityListViewController alloc] init];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)dealloc {
    [self stopCapture];
}

@end