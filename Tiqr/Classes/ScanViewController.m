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
#import "ScanViewController-Protected.h"
#import "AuthenticationChallenge.h"
#import "EnrollmentChallenge.h"
#import "AuthenticationIdentityViewController.h"
#import "AuthenticationConfirmViewController.h"
#import "AuthenticationFallbackViewController.h"
#import "EnrollmentConfirmViewController.h"
#import "Identity+Utils.h"
#import "IdentityListViewController.h"
#import "ErrorViewController.h"
#import "MBProgressHUD.h"

@interface ScanViewController () <AVAudioPlayerDelegate, AVCaptureMetadataOutputObjectsDelegate>

#if HAS_AVFF
@property (nonatomic, retain) AVCaptureSession *captureSession;
@property (nonatomic, retain) AVCaptureVideoPreviewLayer *previewLayer;
#endif

@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, assign, getter=isDecoding) BOOL decoding;
@property (nonatomic, strong) UIBarButtonItem *identitiesButtonItem;

@property (nonatomic, strong) IBOutlet UILabel *instructionLabel;

- (void)initCapture;
- (void)stopCapture;
- (void)processChallenge:(NSString *)rawResult;

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
    
    if ([Identity countInManagedObjectContext:self.managedObjectContext] > 0) {
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
    [self initCapture];    
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.5];
    self.instructionsView.alpha = 0.7;
    [UIView commitAnimations];
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
    [self performSelector:@selector(didScanResult:) withObject:metadataObject.stringValue afterDelay:1.0];
    [self setMixableAudioShouldDuckActive:YES];
	[self.audioPlayer play];
}

- (void)didScanResult:(NSString *)result {
    [self processChallenge:result];
}

#pragma mark - 
#pragma mark AVFoundation

- (void)initCapture {
    #if HAS_AVFF
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
    [self.captureSession addInput:captureInput];
    
    AVCaptureMetadataOutput *captureOutput = [[AVCaptureMetadataOutput alloc] init];
    [self.captureSession addOutput:captureOutput];
    
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
    AVCaptureInput* input = [self.captureSession.inputs objectAtIndex:0];
    [self.captureSession removeInput:input];
    AVCaptureVideoDataOutput* output = (AVCaptureVideoDataOutput *)[self.captureSession.outputs objectAtIndex:0];
    [self.captureSession removeOutput:output];
    [self.previewLayer removeFromSuperlayer];
    self.previewLayer = nil;
    self.captureSession = nil;
    #endif
}


- (void)pushViewControllerForChallenge:(Challenge *)challenge {
    UIViewController *viewController = nil;
    if ([challenge isKindOfClass:[AuthenticationChallenge class]]) {
        AuthenticationChallenge *authenticationChallenge = (AuthenticationChallenge *)challenge;
        if (authenticationChallenge.identity == nil) {
            AuthenticationIdentityViewController *identityViewController = [[AuthenticationIdentityViewController alloc] initWithAuthenticationChallenge:authenticationChallenge];    
            identityViewController.managedObjectContext = self.managedObjectContext;
            viewController = identityViewController;
        } else {
            AuthenticationConfirmViewController *confirmViewController = [[AuthenticationConfirmViewController alloc] initWithAuthenticationChallenge:authenticationChallenge];
            confirmViewController.managedObjectContext = self.managedObjectContext;
            viewController = confirmViewController;
        } 
    } else {
        EnrollmentChallenge *enrollmentChallenge = (EnrollmentChallenge *)challenge;
        EnrollmentConfirmViewController *confirmViewController = [[EnrollmentConfirmViewController alloc] initWithEnrollmentChallenge:enrollmentChallenge]; 
        confirmViewController.managedObjectContext = self.managedObjectContext;
        viewController = confirmViewController;
    }
    
    [self.navigationController pushViewController:viewController animated:YES];
    
}

- (void)processChallenge:(NSString *)scanResult {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		dispatch_async(dispatch_get_main_queue(), ^{
			[MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
		});
        
        Challenge *challenge = nil;
        NSString *errorTitle = nil;
        NSString *errorMessage = nil;
        
        NSString *authenticationScheme = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TIQRAuthenticationURLScheme"]; 
        NSString *enrollmentScheme = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TIQREnrollmentURLScheme"]; 
        
        NSURL *url = [NSURL URLWithString:scanResult];
        if (url != nil && [url.scheme isEqualToString:authenticationScheme]) {
            challenge = [[AuthenticationChallenge alloc] initWithRawChallenge:scanResult managedObjectContext:self.managedObjectContext];
            errorTitle = challenge.isValid ? nil : [challenge.error localizedDescription];        
            errorMessage = challenge.isValid ? nil : [challenge.error localizedFailureReason];                
        } else if (url != nil && [url.scheme isEqualToString:enrollmentScheme]) {
            challenge = [[EnrollmentChallenge alloc] initWithRawChallenge:scanResult managedObjectContext:self.managedObjectContext];
            errorTitle = challenge.isValid ? nil : [challenge.error localizedDescription];        
            errorMessage = challenge.isValid ? nil : [challenge.error localizedFailureReason];                
        } else {
            errorTitle = NSLocalizedString(@"error_auth_invalid_qr_code", @"Invalid QR tag title");
            errorMessage = NSLocalizedString(@"error_auth_invalid_challenge_message", @"Unable to interpret the scanned QR tag. Please try again. If the problem persists, please contact the website adminstrator");
        }        
        
		dispatch_async(dispatch_get_main_queue(), ^{
			[MBProgressHUD hideHUDForView:self.navigationController.view animated:YES];
            
            if (challenge != nil && errorTitle == nil) {
                [self pushViewControllerForChallenge:challenge];
            } else {
                ErrorViewController *viewController = [[ErrorViewController alloc] initWithTitle:self.title errorTitle:errorTitle errorMessage:errorMessage];
                [self.navigationController pushViewController:viewController animated:YES];
            }            
		});
	});    
}

- (void)listIdentities {
    IdentityListViewController *viewController = [[IdentityListViewController alloc] init];
    viewController.managedObjectContext = self.managedObjectContext;
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)resetOutlets {
    self.previewView = nil;
    self.instructionsView = nil;
    self.overlayView = nil;
    self.instructionLabel = nil;
}

- (void)viewDidUnload {
    [self resetOutlets];
    [super viewDidUnload];
}

- (void)dealloc {
    [self stopCapture];
    
    #if HAS_AVFF
    self.captureSession = nil;
    self.previewLayer = nil;
    #endif
    
    [self resetOutlets];
    
    
}

@end