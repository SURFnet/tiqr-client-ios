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

#import "Challenge-Protected.h"
#import "AuthenticationChallenge.h"
#import "IdentityProvider+Utils.h"
#import "Identity+Utils.h"

NSString *const TIQRACErrorDomain = @"org.tiqr.ac";

@interface AuthenticationChallenge ()

@property (nonatomic, strong) IdentityProvider *identityProvider;
@property (nonatomic, strong) NSArray *identities;
@property (nonatomic, copy) NSString *serviceProviderIdentifier;
@property (nonatomic, copy) NSString *serviceProviderDisplayName;
@property (nonatomic, copy) NSString *sessionKey;
@property (nonatomic, copy) NSString *challenge;
@property (nonatomic, copy) NSString *returnUrl;
@property (nonatomic, copy) NSString *protocolVersion;

@end

@implementation AuthenticationChallenge

- (void)parseRawChallenge {
    NSString *scheme = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TIQRAuthenticationURLScheme"]; 
    
	NSURL *url = [NSURL URLWithString:self.rawChallenge];
        
	if (url == nil || ![url.scheme isEqualToString:scheme] || [url.pathComponents count] < 3) {
        NSString *errorTitle = NSLocalizedString(@"error_auth_invalid_qr_code", @"Invalid QR tag title");
        NSString *errorMessage = NSLocalizedString(@"error_auth_invalid_challenge_message", @"Invalid QR tag message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        self.error = [NSError errorWithDomain:TIQRACErrorDomain code:TIQRACInvalidQRTagError userInfo:details];        
		return;
	}

	IdentityProvider *identityProvider = [IdentityProvider findIdentityProviderWithIdentifier:url.host inManagedObjectContext:self.managedObjectContext];
	if (identityProvider == nil) {
        NSString *errorTitle = NSLocalizedString(@"error_auth_unknown_identity", @"No account title");
        NSString *errorMessage = NSLocalizedString(@"error_auth_no_identities_for_identity_provider", @"No account message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        self.error = [NSError errorWithDomain:TIQRACErrorDomain code:TIQRACUnknownIdentityProviderError userInfo:details];        
		return;
	}
	
	if (url.user != nil) {
		Identity *identity = [Identity findIdentityWithIdentifier:url.user forIdentityProvider:identityProvider inManagedObjectContext:self.managedObjectContext];
		if (identity == nil) {
            NSString *errorTitle = NSLocalizedString(@"error_auth_invalid_account", @"Unknown account title");
            NSString *errorMessage = NSLocalizedString(@"error_auth_invalid_account_message", @"Unknown account message");
            NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
            self.error = [NSError errorWithDomain:TIQRACErrorDomain code:TIQRACUnknownIdentityError userInfo:details];        
            return;
		}
		
		self.identities = @[identity];
		self.identity = identity;
	} else {
		NSArray *identities = [Identity findIdentitiesForIdentityProvider:identityProvider inManagedObjectContext:self.managedObjectContext];
		if (identities == nil || [identities count] == 0) {
            NSString *errorTitle = NSLocalizedString(@"error_auth_invalid_account", @"No account title");
            NSString *errorMessage = NSLocalizedString(@"error_auth_invalid_account_message", @"No account message");
            NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
            self.error = [NSError errorWithDomain:TIQRACErrorDomain code:TIQRACZeroIdentitiesForIdentityProviderError userInfo:details];        
            return;
		}
		
		self.identities = identities;
		self.identity = [identities count] == 1 ? identities[0] : nil;
	}
	
    if (self.identity != nil && [self.identity.blocked boolValue]) {
        NSString *errorTitle = NSLocalizedString(@"error_auth_account_blocked_title", @"Account blocked title");
        NSString *errorMessage = NSLocalizedString(@"error_auth_account_blocked_message", @"Account blocked message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        self.error = [NSError errorWithDomain:TIQRACErrorDomain code:TIQRACIdentityBlockedError userInfo:details];        
    }
    
	self.identityProvider = identityProvider;
    self.sessionKey = url.pathComponents[1];
    self.challenge = url.pathComponents[2];
    if ([url.pathComponents count] > 3) {
        self.serviceProviderDisplayName = url.pathComponents[3];
    } else {
        self.serviceProviderDisplayName = NSLocalizedString(@"error_auth_unknown_identity_provider", @"Unknown");
    }
    self.serviceProviderIdentifier = @"";
    
    if ([url.pathComponents count] > 4) {
        self.protocolVersion = url.pathComponents[4];
    } else {
        self.protocolVersion = @"1";
    }

    NSString *regex = @"^http(s)?://.*";
    NSPredicate *protocolPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    
    if (url.query != nil && [url.query length] > 0 && [protocolPredicate evaluateWithObject:[self decodeURL:url.query]] == YES) {
        self.returnUrl = [self decodeURL:url.query];
    } else {
        self.returnUrl = nil;
    }
}


@end