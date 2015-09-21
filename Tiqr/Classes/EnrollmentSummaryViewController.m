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

#import "EnrollmentSummaryViewController.h"
#import "EnrollmentSummaryViewController-Protected.h"
#import "TiqrAppDelegate.h"

@interface EnrollmentSummaryViewController ()

@property (nonatomic, strong) EnrollmentChallenge *challenge;
@property (nonatomic, strong) IBOutlet UILabel *accountActivatedLabel;
@property (nonatomic, strong) IBOutlet UILabel *accountReadyLabel;
@property (nonatomic, strong) IBOutlet UILabel *fullNameLabel;
@property (nonatomic, strong) IBOutlet UILabel *accountIDLabel;
@property (nonatomic, strong) IBOutlet UILabel *accountDetailsLabel;
@property (nonatomic, strong) IBOutlet UILabel *enrolledLabel;
@property (nonatomic, strong) IBOutlet UILabel *enrollmentDomainLabel;

@end

@implementation EnrollmentSummaryViewController

- (instancetype)initWithEnrollmentChallenge:(EnrollmentChallenge *)challenge {
    self = [super initWithNibName:@"EnrollmentSummaryView" bundle:nil];
	if (self != nil) {
		self.challenge = challenge;
	}
	
	return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.accountReadyLabel.text = NSLocalizedString(@"account_ready", @"Your account is ready to be used.");
    self.accountActivatedLabel.text = NSLocalizedString(@"account_activated", @"Your account is activated!");
    self.fullNameLabel.text = NSLocalizedString(@"full_name", @"Full name");
    self.accountIDLabel.text = NSLocalizedString(@"id", @"Tiqr account ID");
    self.accountDetailsLabel.text = NSLocalizedString(@"account_details_title", "Account details");
    
    self.enrolledLabel.text = NSLocalizedString(@"enrolled_following_domain", @"You are enrolled for the following domain:");
    
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    self.navigationItem.leftBarButtonItem = backButton;
    
    self.identityDisplayNameLabel.text = self.challenge.identityDisplayName;
    self.identityIdentifierLabel.text = self.challenge.identityIdentifier;
    self.enrollmentDomainLabel.text = [[NSURL URLWithString:self.challenge.enrollmentUrl] host];
    
    if (self.challenge.returnUrl != nil) {
        [self.returnButton setTitle:NSLocalizedString(@"return_button", @"Return to button title") forState:UIControlStateNormal];
        self.returnButton.hidden = NO;
    }
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
}

- (void)done {
    [(TiqrAppDelegate *)[UIApplication sharedApplication].delegate popToStartViewControllerAnimated:YES];    
}

- (void)returnToCaller {
    [(TiqrAppDelegate *)[UIApplication sharedApplication].delegate popToStartViewControllerAnimated:NO];    
    NSString *returnURL = [NSString stringWithFormat:@"%@?successful=1", self.challenge.returnUrl];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:returnURL]];
}

- (void)resetOutlets {
	self.identityDisplayNameLabel = nil;
	self.identityIdentifierLabel = nil;
    self.returnButton = nil;
    self.accountReadyLabel = nil;
    self.accountActivatedLabel = nil;
    self.fullNameLabel = nil;
    self.accountIDLabel = nil;
    self.accountDetailsLabel = nil;
    self.enrolledLabel = nil;
    self.enrollmentDomainLabel = nil;
}

- (void)viewDidUnload {
    [self resetOutlets];
    [super viewDidUnload];
}

- (void)dealloc {
    [self resetOutlets];
    
    
}

@end