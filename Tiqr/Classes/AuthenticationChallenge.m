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

#import "AuthenticationChallenge.h"
#import "NSString+DecodeURL.h"
#import "ServiceContainer.h"

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

+ (BOOL)applyError:(NSError *)error toError:(NSError **)otherError {
    if (otherError != NULL) {
        *otherError = error;
    }
    
    return YES;
}

+ (AuthenticationChallenge *)challengeWithChallengeString:(NSString *)challengeString error:(NSError **)error {
    
    NSString *scheme = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TIQRAuthenticationURLScheme"]; 
    
	NSURL *url = [NSURL URLWithString:challengeString];
    
    AuthenticationChallenge *challenge = [[AuthenticationChallenge alloc] init];
    
    IdentityService *identityService = ServiceContainer.sharedInstance.identityService;
        
	if (url == nil || ![url.scheme isEqualToString:scheme] || [url.pathComponents count] < 3) {
        NSString *errorTitle = NSLocalizedString(@"error_auth_invalid_qr_code", @"Invalid QR tag title");
        NSString *errorMessage = NSLocalizedString(@"error_auth_invalid_challenge_message", @"Invalid QR tag message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        [NSError errorWithDomain:TIQRACErrorDomain code:TIQRACInvalidQRTagError userInfo:details];
        [self applyError:[NSError errorWithDomain:TIQRACErrorDomain code:TIQRACInvalidQRTagError userInfo:details] toError:error];
        return nil;
	}

	IdentityProvider *identityProvider = [identityService findIdentityProviderWithIdentifier:url.host];
	if (identityProvider == nil) {
        NSString *errorTitle = NSLocalizedString(@"error_auth_unknown_identity", @"No account title");
        NSString *errorMessage = NSLocalizedString(@"error_auth_no_identities_for_identity_provider", @"No account message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        [self applyError:[NSError errorWithDomain:TIQRACErrorDomain code:TIQRACUnknownIdentityProviderError userInfo:details] toError:error];
        return nil;
	}
	
	if (url.user != nil) {
		Identity *identity = [identityService findIdentityWithIdentifier:url.user forIdentityProvider:identityProvider];
		if (identity == nil) {
            NSString *errorTitle = NSLocalizedString(@"error_auth_invalid_account", @"Unknown account title");
            NSString *errorMessage = NSLocalizedString(@"error_auth_invalid_account_message", @"Unknown account message");
            NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
            [self applyError:[NSError errorWithDomain:TIQRACErrorDomain code:TIQRACUnknownIdentityError userInfo:details] toError:error];
            return nil;
		}
		
		challenge.identities = @[identity];
		challenge.identity = identity;
	} else {
        NSArray *identities = [identityService findIdentitiesForIdentityProvider:identityProvider];
		if (identities == nil || [identities count] == 0) {
            NSString *errorTitle = NSLocalizedString(@"error_auth_invalid_account", @"No account title");
            NSString *errorMessage = NSLocalizedString(@"error_auth_invalid_account_message", @"No account message");
            NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
            
            [self applyError:[NSError errorWithDomain:TIQRACErrorDomain code:TIQRACZeroIdentitiesForIdentityProviderError userInfo:details] toError:error];
            return nil;
		}
		
		challenge.identities = identities;
		challenge.identity = [identities count] == 1 ? identities[0] : nil;
	}
	
    if (challenge.identity != nil && [challenge.identity.blocked boolValue]) {
        NSString *errorTitle = NSLocalizedString(@"error_auth_account_blocked_title", @"Account blocked title");
        NSString *errorMessage = NSLocalizedString(@"error_auth_account_blocked_message", @"Account blocked message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        
        [self applyError:[NSError errorWithDomain:TIQRACErrorDomain code:TIQRACIdentityBlockedError userInfo:details] toError:error];
        return nil;
    }
    
	challenge.identityProvider = identityProvider;
    challenge.sessionKey = url.pathComponents[1];
    challenge.challenge = url.pathComponents[2];
    if ([url.pathComponents count] > 3) {
        challenge.serviceProviderDisplayName = url.pathComponents[3];
    } else {
        challenge.serviceProviderDisplayName = NSLocalizedString(@"error_auth_unknown_identity_provider", @"Unknown");
    }
    challenge.serviceProviderIdentifier = @"";
    
    if ([url.pathComponents count] > 4) {
        challenge.protocolVersion = url.pathComponents[4];
    } else {
        challenge.protocolVersion = @"1";
    }

    NSString *regex = @"^http(s)?://.*";
    NSPredicate *protocolPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    
    if (url.query != nil && [url.query length] > 0 && [protocolPredicate evaluateWithObject:url.query.decodedURL] == YES) {
        challenge.returnUrl = url.query.decodedURL;
    } else {
        challenge.returnUrl = nil;
    }
    
    return challenge;
}


@end