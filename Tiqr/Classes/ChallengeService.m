/*
 * Copyright (c) 2015-2016 SURFnet bv
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

#import "ChallengeService.h"
#import "EnrollmentChallenge.h"
#import "EnrollmentConfirmationRequest.h"
#import "AuthenticationChallenge.h"
#import "AuthenticationConfirmationRequest.h"
#import "ServiceContainer.h"
#import "OCRAWrapper.h"
#import "OCRAWrapper_v1.h"
#import "OCRAProtocol.h"


@interface ChallengeService ()

@property (nonatomic, strong) SecretService *secretService;
@property (nonatomic, strong) IdentityService *identityService;

@end


@implementation ChallengeService

- (instancetype)initWithSecretService:(SecretService *)secretService identityService:(IdentityService *)identityService {
    
    if (self = [super init]) {
        self.secretService = secretService;
        self.identityService = identityService;
    }
    
    return self;
}

- (void)startChallengeFromScanResult:(NSString *)scanResult completionHandler:(void (^)(TIQRChallengeType, NSObject *, NSError *))completionHandler {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSString *authenticationScheme = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TIQRAuthenticationURLScheme"];
        NSString *enrollmentScheme = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TIQREnrollmentURLScheme"];
        
        TIQRChallengeType type = TIQRChallengeTypeInvalid;
        NSObject *challengeObject  = nil;
        
        NSURL *url = [NSURL URLWithString:scanResult];
        NSError *error = nil;
        if (url != nil && [url.scheme isEqualToString:authenticationScheme]) {
            AuthenticationChallenge *challenge = [AuthenticationChallenge challengeWithChallengeString:scanResult error:&error];
            
            if (!error) {
                type = TIQRChallengeTypeAuthentication;
                challengeObject = challenge;
            }
        } else if (url != nil && [url.scheme isEqualToString:enrollmentScheme]) {
            EnrollmentChallenge *challenge = [EnrollmentChallenge challengeWithChallengeString:scanResult allowFiles:NO error:&error];
            
            if (!error) {
                type = TIQRChallengeTypeEnrollment;
                challengeObject = challenge;
            }
        } else {
            NSString *errorTitle = NSLocalizedString(@"error_auth_invalid_qr_code", @"Invalid QR tag title");
            NSString *errorMessage = NSLocalizedString(@"error_auth_invalid_challenge_message", @"Unable to interpret the scanned QR tag. Please try again. If the problem persists, please contact the website adminstrator");
            NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
            
            error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRACInvalidQRTagError userInfo:details];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(type, challengeObject, error);
        });
    });
}

- (void)completeEnrollmentChallenge:(EnrollmentChallenge *)challenge usingTouchID:(BOOL)touchID withPIN:(NSString *)PINOrNil completionHandler:(void (^)(BOOL, NSError *))completionHandler {

    challenge.identitySecret = [self.secretService generateSecret];
    
    if (!touchID) {
        challenge.identityPIN = PINOrNil;
    }
    
    IdentityProvider *identityProvider = challenge.identityProvider;
    if (identityProvider == nil) {
        identityProvider = [self.identityService createIdentityProvider];
        identityProvider.identifier = challenge.identityProviderIdentifier;
        identityProvider.displayName = challenge.identityProviderDisplayName;
        identityProvider.authenticationUrl = challenge.identityProviderAuthenticationUrl;
        identityProvider.infoUrl = challenge.identityProviderInfoUrl;
        identityProvider.ocraSuite = challenge.identityProviderOcraSuite;
        identityProvider.logo = challenge.identityProviderLogo;
    }
    
    Identity *identity = challenge.identity;
    if (identity == nil) {
        identity = [self.identityService createIdentity];
        identity.identifier = challenge.identityIdentifier;
        identity.sortIndex = [NSNumber numberWithInteger:self.identityService.maxSortIndex + 1];
        identity.identityProvider = identityProvider;
        identity.salt = [self.secretService generateSecret];
    }
    
    identity.displayName = challenge.identityDisplayName;
    
    if (![self.identityService saveIdentities]) {
        [self.identityService rollbackIdentities];
        
        NSString *errorTitle = NSLocalizedString(@"error_enroll_failed_to_store_identity_title", @"Account cannot be saved title");
        NSString *errorMessage = NSLocalizedString(@"error_enroll_failed_to_store_identity", @"Account cannot be saved message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        
        NSError *error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRECUnknownError userInfo:details];
        completionHandler(false, error);
        challenge = nil;
        return;
    }
    
    challenge.identity = identity;
    challenge.identityProvider = identityProvider;
    
    void (^sendConfirmationBlock)(void) = ^{
        EnrollmentConfirmationRequest *request = [[EnrollmentConfirmationRequest alloc] initWithEnrollmentChallenge:challenge];
        [request sendWithCompletionHandler:^(BOOL success, NSError *error) {
            if (success) {
                challenge.identity.blocked = @NO;
                [ServiceContainer.sharedInstance.identityService saveIdentities];
                completionHandler(true, nil);
            } else {
                if (![challenge.identity.blocked boolValue]) {
                    [self.identityService deleteIdentity:challenge.identity];
                    [self.identityService saveIdentities];
                }
                
                [self.secretService deleteSecretForIdentityIdentifier:challenge.identityIdentifier
                                                   providerIdentifier:challenge.identityProviderIdentifier];
                completionHandler(false, error);
            }
        }];
    };
    
    if (touchID) {
        [self.secretService setSecret:challenge.identitySecret usingTouchIDforIdentity:challenge.identity withCompletionHandler:^(BOOL success) {
            if (!success) {
                NSString *errorTitle = NSLocalizedString(@"error_enroll_failed_to_store_identity_title", @"Account cannot be saved title");
                NSString *errorMessage = NSLocalizedString(@"error_enroll_failed_to_generate_secret", @"Failed to generate identity secret. Please contact support.");
                NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
                
                NSError *error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRECUnknownError userInfo:details];
                completionHandler(false, error);
                return;
            }
            
            challenge.identity.usesOldBiometricFlow = @YES;
            
            sendConfirmationBlock();
        }];
    } else {
        [self.secretService setSecret:challenge.identitySecret
                          forIdentity:challenge.identity
                              withPIN:challenge.identityPIN];
        
        sendConfirmationBlock();
    }
    
}

- (void)completeAuthenticationChallenge:(AuthenticationChallenge *)challenge withSecret:(NSData *)secret completionHandler:(void (^)(BOOL succes, NSString *response, NSError *error))completionHandler {
    
    NSObject<OCRAProtocol> *ocra;
    if (challenge.protocolVersion && [challenge.protocolVersion intValue] >= 2) {
        ocra = [[OCRAWrapper alloc] init];
    } else {
        ocra = [[OCRAWrapper_v1 alloc] init];
    }
    
    NSError *error = nil;
    NSString *response = [ocra generateOCRA:challenge.identityProvider.ocraSuite secret:secret challenge:challenge.challenge sessionKey:challenge.sessionKey error:&error];
    if (response == nil) {
        completionHandler(false, nil, error);
        return;
    }
    
    AuthenticationConfirmationRequest *request = [[AuthenticationConfirmationRequest alloc] initWithAuthenticationChallenge:challenge response:response];
    [request sendWithCompletionHandler:^(BOOL success, NSError *error) {
        completionHandler(success, response, error);
    }];
}

@end
