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

#import "EnrollmentPINViewController.h"
#import "EnrollmentPINVerificationViewController.h"
#import "ServiceContainer.h"

@interface EnrollmentPINViewController ()

@property (nonatomic, strong) EnrollmentChallenge *challenge;

@end

@implementation EnrollmentPINViewController

- (instancetype)initWithEnrollmentChallenge:(EnrollmentChallenge *)challenge {
    self = [super init];
    if (self != nil) {
        self.challenge = challenge;
        self.delegate = self;
    }
	
	return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    self.subtitle = NSLocalizedString(@"enrollment_pin_intro", @"Enrollment PIN title");
    self.pinDescription = NSLocalizedString(@"enrollment_pin_message", @"You need a PIN code for this account. If you don't yet have a PIN code for tiqr please choose one.");
    self.pinNotes = NSLocalizedString(@"remember_pincode_notice", @"Remember your PIN, it cannot be changed!");
}

- (void)PINViewController:(PINViewController *)pinViewController didFinishWithPIN:(NSString *)PIN {
    EnrollmentPINVerificationViewController *viewController = [[EnrollmentPINVerificationViewController alloc] initWithEnrollmentChallenge:self.challenge PIN:PIN];
    [self.navigationController pushViewController:viewController animated:YES];
}


@end
