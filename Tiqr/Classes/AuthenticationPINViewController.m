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

#import "AuthenticationPINViewController.h"
#import "AuthenticationSummaryViewController.h"
#import "AuthenticationFallbackViewController.h"
#import "OCRAWrapper.h"
#import "OCRAWrapper_v1.h"
#import "MBProgressHUD.h"
#import "ErrorViewController.h"
#import "OCRAProtocol.h"
#import "ServiceContainer.h"

@interface AuthenticationPINViewController ()

@property (nonatomic, strong) AuthenticationChallenge *challenge;
@property (nonatomic, copy) NSString *PIN;

@end

@implementation AuthenticationPINViewController

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        self.challenge = ServiceContainer.sharedInstance.challengeService.currentAuthenticationChallenge;
    }
	
	return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    self.subtitle = NSLocalizedString(@"login_intro", @"Authentication PIN title");
    self.pinDescription = NSLocalizedString(@"enter_four_digit_pin", @"You need to enter your 4-digit PIN to login.");
}

- (void)PINViewController:(PINViewController *)pinViewController didFinishWithPIN:(NSString *)PIN {
    self.PIN = PIN;
    NSData *secret = [ServiceContainer.sharedInstance.secretService secretForIdentity:self.challenge.identity withPIN:PIN];
    
    
    [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
    
    [ServiceContainer.sharedInstance.challengeService completeAuthenticationChallengeWithSecret:secret completionHandler:^(BOOL succes, NSString *response, NSError *error) {
        [MBProgressHUD hideHUDForView:self.navigationController.view animated:YES];
        
        if (succes) {
            [ServiceContainer.sharedInstance.identityService upgradeIdentity:self.challenge.identity withPIN:self.PIN];
            
            self.PIN = nil;
            
            [MBProgressHUD hideHUDForView:self.navigationController.view animated:YES];
            AuthenticationSummaryViewController *viewController = [[AuthenticationSummaryViewController alloc] init];
            [self.navigationController pushViewController:viewController animated:YES];
        } else {
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
                        
                        [self presentErrorViewControllerWithError:error];
                    } else {
                        [self clear];
                        [self showErrorWithTitle:[error localizedDescription] message:[error localizedFailureReason]];
                    }
                    break;
                }
                    
                default: {
                    [self presentErrorViewControllerWithError:error];
                    break;
                }
            }
        }
    }];
}

- (void)presentErrorViewControllerWithError:(NSError *)error {
    UIViewController *viewController = [[ErrorViewController alloc] initWithErrorTitle:[error localizedDescription] errorMessage:[error localizedFailureReason]];
    [self.navigationController pushViewController:viewController animated:YES];
}


@end