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
@property (nonatomic, strong) IBOutlet UIButton *okButton;
@property (nonatomic, strong) IBOutlet UILabel *fullNameLabel;
@property (nonatomic, strong) IBOutlet UILabel *accountIDLabel;
@property (nonatomic, strong) IBOutlet UILabel *accountDetailsLabel;

@property (nonatomic, strong) IBOutlet UILabel *identityDisplayNameLabel;
@property (nonatomic, strong) IBOutlet UILabel *identityIdentifierLabel;
@property (nonatomic, strong) IBOutlet UILabel *enrollmentURLDomainLabel;

@end

@implementation EnrollmentConfirmViewController

- (instancetype)init {
    self = [super initWithNibName:@"EnrollmentConfirmView" bundle:nil];
    if (self != nil) {
        self.challenge = ServiceContainer.sharedInstance.challengeService.currentEnrollmentChallenge;
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
    
    [self.okButton setTitle:NSLocalizedString(@"ok_button", @"OK") forState:UIControlStateNormal];
    self.okButton.layer.cornerRadius = 5;
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStyleBordered target:nil action:nil];

    self.identityDisplayNameLabel.text = self.challenge.identityDisplayName;
    self.identityIdentifierLabel.text = self.challenge.identityIdentifier;
    self.enrollmentURLDomainLabel.text = [[NSURL URLWithString:self.challenge.enrollmentUrl] host];
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
}


- (IBAction)ok {
    if (ServiceContainer.sharedInstance.secretService.touchIDIsAvailable) {
        [self useTouchID];
    } else {
        [self usePIN];
    }
}


- (void)usePIN {
    EnrollmentPINViewController *viewController = [[EnrollmentPINViewController alloc] init];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)useTouchID {
    [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
    
    [ServiceContainer.sharedInstance.challengeService
     completeEnrollmentChallengeUsingTouchID:YES withPIN:nil completionHandler:^(BOOL success, NSError *error) {
        
        [MBProgressHUD hideHUDForView:self.navigationController.view animated:YES];
        
        if (success) {
            EnrollmentSummaryViewController *viewController = [[EnrollmentSummaryViewController alloc] init];
            [self.navigationController pushViewController:viewController animated:YES];
        } else {
            UIViewController *viewController = [[ErrorViewController alloc] initWithErrorTitle:[error localizedDescription] errorMessage:[error localizedFailureReason]];
            [self.navigationController pushViewController:viewController animated:YES];
        }
    }];
}

- (IBAction)cancel {
    [self.navigationController popViewControllerAnimated:YES];
}

@end