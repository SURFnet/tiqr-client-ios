/*
 * Copyright (c) 2010-2011 SURFnet bv
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of SURFnet bv nor the names of its contributors 
 *    may be used to endorse or promote products derived from this 
 *    software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 * GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "EnrollmentConfirmViewController.h"
#import "EnrollmentPINViewController.h"
#import "ServiceContainer.h"
#import "MBProgressHUD.h"
#import "ErrorViewController.h"
#import "EnrollmentSummaryViewController.h"

@interface EnrollmentConfirmViewController ()

@property (nonatomic, strong) EnrollmentChallenge *challenge;
@property (nonatomic, strong) IBOutlet UILabel *confirmAccountLabel;
@property (nonatomic, strong) IBOutlet UILabel *activateAccountLabel;
@property (nonatomic, strong) IBOutlet UILabel *enrollDomainLabel;
@property (nonatomic, strong) IBOutlet UIButton *pinButton;
@property (nonatomic, strong) IBOutlet UIButton *touchIDButton;
@property (nonatomic, strong) IBOutlet UILabel *fullNameLabel;
@property (nonatomic, strong) IBOutlet UILabel *accountIDLabel;
@property (nonatomic, strong) IBOutlet UILabel *accountDetailsLabel;

@property (nonatomic, strong) IBOutlet UILabel *identityDisplayNameLabel;
@property (nonatomic, strong) IBOutlet UILabel *identityIdentifierLabel;
@property (nonatomic, strong) IBOutlet UILabel *enrollmentURLDomainLabel;

@end

@implementation EnrollmentConfirmViewController

- (instancetype)initWithEnrollmentChallenge:(EnrollmentChallenge *)challenge {
    self = [super initWithNibName:@"EnrollmentConfirmView" bundle:nil];
	if (self != nil) {
		self.challenge = challenge;
	}
	
	return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.confirmAccountLabel.text = NSLocalizedString(@"confirm_account_activation", @"Confirm account activation");
    self.activateAccountLabel.text = NSLocalizedString(@"activate_following_account", @"Do you want to activate the following account");
    self.enrollDomainLabel.text = NSLocalizedString(@"enroll_following_domain", @"You will enroll to the following domain");
    self.fullNameLabel.text = NSLocalizedString(@"full_name", @"Full name");
    self.accountIDLabel.text = NSLocalizedString(@"id", @"Tiqr account ID");
    self.accountDetailsLabel.text = NSLocalizedString(@"account_details_title", "Account details");
    
    [self.pinButton setTitle:@"PIN" forState:UIControlStateNormal];
    self.pinButton.layer.cornerRadius = 5;
    
    [self.touchIDButton setTitle:@"TouchID" forState:UIControlStateNormal];
    self.touchIDButton.layer.cornerRadius = 5;
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStyleBordered target:nil action:nil];

    self.identityDisplayNameLabel.text = self.challenge.identityDisplayName;
    self.identityIdentifierLabel.text = self.challenge.identityIdentifier;
    self.enrollmentURLDomainLabel.text = [[NSURL URLWithString:self.challenge.enrollmentUrl] host];
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    CGRect touchIDFrame = self.touchIDButton.frame;
    CGRect PINFrame = self.pinButton.frame;
    
    if (ServiceContainer.sharedInstance.secretService.touchIDIsAvailable) {
        
        CGFloat availableWidth = self.view.frame.size.width - 45.0f;
        
        touchIDFrame.size.width = PINFrame.size.width = availableWidth / 2.0f;
        touchIDFrame.origin.x = 15.0f;
        PINFrame.origin.x = (self.view.frame.size.width + 15.0f) / 2.0f;
    } else {
        self.touchIDButton.hidden = YES;
        
        PINFrame.size.width = 200.0f;
        PINFrame.origin.x = (self.view.frame.size.width - 200.0f) / 2.0f;
    }
}



- (IBAction)usePIN {
    EnrollmentPINViewController *viewController = [[EnrollmentPINViewController alloc] initWithEnrollmentChallenge:self.challenge];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (IBAction)useTouchID {
    self.challenge.identitySecret = [ServiceContainer.sharedInstance.secretService generateSecret];
    SecretService *secretService = ServiceContainer.sharedInstance.secretService;
    
    if (![self storeProviderAndIdentity]) {
        NSString *errorTitle = NSLocalizedString(@"error_enroll_failed_to_store_identity_title", @"Account cannot be saved title");
        NSString *errorMessage = NSLocalizedString(@"error_enroll_failed_to_store_identity", @"Account cannot be saved message");
        UIViewController *viewController = [[ErrorViewController alloc] initWithErrorTitle:errorTitle errorMessage:errorMessage];
        [self.navigationController pushViewController:viewController animated:YES];
        return;
    }
    
    [secretService setSecret:self.challenge.identitySecret usingTouchIDforIdentity:self.challenge.identity withCompletionHandler:^(BOOL success) {
        if (success) {
            [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
            EnrollmentConfirmationRequest *request = [[EnrollmentConfirmationRequest alloc] initWithEnrollmentChallenge:self.challenge];
            request.delegate = self;
            [request send];

            self.challenge.identity.touchID = @YES;
        } else {
            NSString *errorTitle = NSLocalizedString(@"error_enroll_failed_to_store_identity_title", @"Account cannot be saved title");
            NSString *errorMessage = NSLocalizedString(@"error_enroll_failed_to_generate_secret", @"Failed to generate identity secret. Please contact support.");
            UIViewController *viewController = [[ErrorViewController alloc] initWithErrorTitle:errorTitle errorMessage:errorMessage];
            [self.navigationController pushViewController:viewController animated:YES];
        }
    }];
}

- (void)enrollmentConfirmationRequestDidFinish:(EnrollmentConfirmationRequest *)request {
    [MBProgressHUD hideHUDForView:self.navigationController.view animated:YES];
    
    self.challenge.identity.blocked = @NO;
    [ServiceContainer.sharedInstance.identityService saveIdentities];
    
    EnrollmentSummaryViewController *viewController = [[EnrollmentSummaryViewController alloc] initWithEnrollmentChallenge:self.challenge];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)enrollmentConfirmationRequest:(EnrollmentConfirmationRequest *)request didFailWithError:(NSError *)error {
    [MBProgressHUD hideHUDForView:self.navigationController.view animated:YES];
    [self deleteIdentity];
    [self deleteSecret];
    
    UIViewController *viewController = [[ErrorViewController alloc] initWithErrorTitle:[error localizedDescription] errorMessage:[error localizedFailureReason]];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (BOOL)storeProviderAndIdentity {
    IdentityService *identityService = ServiceContainer.sharedInstance.identityService;
    SecretService *secretService = ServiceContainer.sharedInstance.secretService;
    
    IdentityProvider *identityProvider = self.challenge.identityProvider;
    if (identityProvider == nil) {
        identityProvider = [identityService createIdentityProvider];
        identityProvider.identifier = self.challenge.identityProviderIdentifier;
        identityProvider.displayName = self.challenge.identityProviderDisplayName;
        identityProvider.authenticationUrl = self.challenge.identityProviderAuthenticationUrl;
        identityProvider.infoUrl = self.challenge.identityProviderInfoUrl;
        identityProvider.ocraSuite = self.challenge.identityProviderOcraSuite;
        identityProvider.logo = self.challenge.identityProviderLogo;
    }
    
    Identity *identity = self.challenge.identity;
    if (identity == nil) {
        identity = [identityService createIdentity];
        identity.identifier = self.challenge.identityIdentifier;
        identity.sortIndex = [NSNumber numberWithInteger:identityService.maxSortIndex + 1];
        identity.identityProvider = identityProvider;
        identity.salt = [secretService generateSecret];
    }
    
    identity.displayName = self.challenge.identityDisplayName;
    
    if ([identityService saveIdentities]) {
        self.challenge.identity = identity;
        self.challenge.identityProvider = identityProvider;
        return YES;
    } else {
        [identityService rollbackIdentities];
        return NO;			
    }
}

- (void)deleteIdentity {
    if (![self.challenge.identity.blocked boolValue]) {
        [ServiceContainer.sharedInstance.identityService deleteIdentity:self.challenge.identity];
        [ServiceContainer.sharedInstance.identityService saveIdentities];
    }
}

- (BOOL)storeSecret {
    return [ServiceContainer.sharedInstance.secretService setSecret:self.challenge.identitySecret
                                                        forIdentity:self.challenge.identity
                                                            withPIN:self.challenge.identityPIN];
}

- (void)deleteSecret {
    [ServiceContainer.sharedInstance.secretService deleteSecretForIdentityIdentifier:self.challenge.identityIdentifier
                                                                  providerIdentifier:self.challenge.identityProviderIdentifier];
}

- (IBAction)cancel {
    [self.navigationController popViewControllerAnimated:YES];
}

@end