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

#import "AuthenticationConfirmViewController.h"
#import "AuthenticationPINViewController.h"
#import "AuthenticationSummaryViewController.h"
#import "AuthenticationFallbackViewController.h"
#import "ServiceContainer.h"
#import "OCRAWrapper.h"
#import "OCRAWrapper_v1.h"
#import "ErrorViewController.h"
#import "OCRAProtocol.h"
#import "MBProgressHUD.h"

@interface AuthenticationConfirmViewController ()

@property (nonatomic, strong) AuthenticationChallenge *challenge;
@property (nonatomic, strong) IBOutlet UILabel *loginConfirmLabel;
@property (nonatomic, strong) IBOutlet UILabel *loggedInAsLabel;
@property (nonatomic, strong) IBOutlet UILabel *toLabel;
@property (nonatomic, strong) IBOutlet UIButton *okButton;
@property (nonatomic, strong) IBOutlet UILabel *accountLabel;
@property (nonatomic, strong) IBOutlet UILabel *accountIDLabel;
@property (nonatomic, strong) IBOutlet UILabel *identityDisplayNameLabel;
@property (nonatomic, strong) IBOutlet UILabel *identityIdentifierLabel;
@property (nonatomic, strong) IBOutlet UILabel *serviceProviderDisplayNameLabel;
@property (nonatomic, strong) IBOutlet UILabel *serviceProviderIdentifierLabel;
@property (nonatomic, copy) NSString *response;
@property (strong, nonatomic) IBOutlet UIView *nonTouchIDViewsContainer;

@end

@implementation AuthenticationConfirmViewController

- (instancetype)init {
    self = [super initWithNibName:@"AuthenticationConfirmView" bundle:nil];
	if (self != nil) {
		self.challenge = ServiceContainer.sharedInstance.challengeService.currentAuthenticationChallenge;
	}
	
	return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
    self.loginConfirmLabel.text = NSLocalizedString(@"confirm_authentication", @"Are you sure you want to login?");
    self.loggedInAsLabel.text = NSLocalizedString(@"you_will_be_logged_in_as", @"You will be logged in as:");
    self.toLabel.text = NSLocalizedString(@"to_service_provider", @"to:");
    self.accountLabel.text = NSLocalizedString(@"full_name", @"Account");
    self.accountIDLabel.text = NSLocalizedString(@"id", @"Tiqr account ID");
    [self.okButton setTitle:NSLocalizedString(@"ok_button", @"OK") forState:UIControlStateNormal];
    self.okButton.layer.cornerRadius = 5;
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStyleBordered target:nil action:nil];


	self.identityDisplayNameLabel.text = self.challenge.identity.displayName;
    self.identityIdentifierLabel.text = self.challenge.identity.identifier;
	self.serviceProviderDisplayNameLabel.text = self.challenge.serviceProviderDisplayName;
	self.serviceProviderIdentifierLabel.text = self.challenge.serviceProviderIdentifier;
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.challenge.identity.touchID.boolValue) {
        [self authenticateWithTouchId];
    }
}

- (void)authenticateWithTouchId {
    self.nonTouchIDViewsContainer.hidden = YES;
    self.loginConfirmLabel.text = @"TouchID gebruiken om in te loggen";
    
    SecretService *secretService = ServiceContainer.sharedInstance.secretService;
    ChallengeService *challengeService = ServiceContainer.sharedInstance.challengeService;
    
    NSMutableString *touchIDPrompt = [NSLocalizedString(@"you_will_be_logged_in_as", @"You will be logged in as:") mutableCopy];
    [touchIDPrompt appendString:@" "];
    [touchIDPrompt appendString:self.challenge.identity.displayName];
    [touchIDPrompt appendString:@"\n"];
    [touchIDPrompt appendString:NSLocalizedString(@"to_service_provider", @"to:")];
    [touchIDPrompt appendString:@" "];
    [touchIDPrompt appendString:self.challenge.serviceProviderDisplayName];
    
    [secretService secretForIdentity:self.challenge.identity touchIDPrompt:touchIDPrompt withSuccessHandler:^(NSData *secret) {
        
        [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
        [challengeService completeAuthenticationChallengeWithSecret:secret completionHandler:^(BOOL succes, NSString *response, NSError *error) {
        
            [MBProgressHUD hideHUDForView:self.navigationController.view animated:YES];
            
            if (succes) {
                AuthenticationSummaryViewController *viewController = [[AuthenticationSummaryViewController alloc] init];
                [self.navigationController pushViewController:viewController animated:YES];
            } else  {
                switch ([error code]) {
                    case TIQRACRConnectionError: {
                        AuthenticationFallbackViewController *viewController = [[AuthenticationFallbackViewController alloc] initWithResponse:response];
                        [self.navigationController pushViewController:viewController animated:YES];
                        break;
                    }
                        
                    case TIQRACRAccountBlockedError: {
                        self.challenge.identity.blocked = @YES;
                        [ServiceContainer.sharedInstance.identityService saveIdentities];
                        
                        [self presentErrorViewControllerWithError:error];
                        break;
                    }
                    case TIQRACRInvalidResponseError: {
                        NSNumber *attemptsLeft = [error userInfo][TIQRACRAttemptsLeftErrorKey];
                        if (attemptsLeft != nil && [attemptsLeft intValue] == 0) {
                            [ServiceContainer.sharedInstance.identityService blockAllIdentities];
                            [ServiceContainer.sharedInstance.identityService saveIdentities];
                        }
                        
                        [self presentErrorViewControllerWithError:error];
                        break;
                    }
                        
                    default: {
                        [self presentErrorViewControllerWithError:error];
                        break;
                    }
                }
            }
        }];
    } failureHandler:^(BOOL cancelled) {
        [self.navigationController popViewControllerAnimated:YES];
    }];
}

- (void)presentErrorViewControllerWithError:(NSError *)error {
    UIViewController *viewController = [[ErrorViewController alloc] initWithErrorTitle:[error localizedDescription] errorMessage:[error localizedFailureReason]];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (IBAction)ok {
    AuthenticationPINViewController *viewController = [[AuthenticationPINViewController alloc] init];
    [self.navigationController pushViewController:viewController animated:YES];
}

@end