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

@property (nonatomic, strong) AuthenticationChallenge *currentAuthenticationChallenge;
@property (nonatomic, strong) EnrollmentChallenge *currentEnrollmentChallenge;
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

- (void)startChallengeFromScanResult:(NSString *)scanResult completionHandler:(void (^)(TIQRChallengeType, NSError *))completionHandler {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSString *authenticationScheme = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TIQRAuthenticationURLScheme"];
        NSString *enrollmentScheme = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TIQREnrollmentURLScheme"];
        
        TIQRChallengeType type = TIQRChallengeTypeInvalid;
        
        NSURL *url = [NSURL URLWithString:scanResult];
        NSError *error = nil;
        if (url != nil && [url.scheme isEqualToString:authenticationScheme]) {
            type = TIQRChallengeTypeAuthentication;
            AuthenticationChallenge *challenge = [AuthenticationChallenge challengeWithChallengeString:scanResult error:&error];
            
            if (!error) {
                self.currentAuthenticationChallenge = challenge;
            }
        } else if (url != nil && [url.scheme isEqualToString:enrollmentScheme]) {
            type = TIQRChallengeTypeEnrollment;
            EnrollmentChallenge *challenge = [EnrollmentChallenge challengeWithChallengeString:scanResult allowFiles:NO error:&error];
            
            if (!error) {
                self.currentEnrollmentChallenge = challenge;
            }
        } else {
            NSString *errorTitle = NSLocalizedString(@"error_auth_invalid_qr_code", @"Invalid QR tag title");
            NSString *errorMessage = NSLocalizedString(@"error_auth_invalid_challenge_message", @"Unable to interpret the scanned QR tag. Please try again. If the problem persists, please contact the website adminstrator");
            NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
            
            error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRACInvalidQRTagError userInfo:details];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(type, error);
        });
    });
}

- (void)completeEnrollmentChallengeWithPIN:(NSString *)PIN completionHandler:(void (^)(BOOL success, NSError *error))completionHandler {
    
}

- (void)completeEnrollmentChallengeUsingTouchIDWithCompletionHandler:(void (^)(BOOL success, NSError *error))completionHandler {
    
}

- (void)completeEnrollmentChallengeUsingTouchID:(BOOL)touchID withPIN:(NSString *)PINOrNil completionHandler:(void (^)(BOOL, NSError *))completionHandler {

    self.currentEnrollmentChallenge.identitySecret = [self.secretService generateSecret];
    
    if (!touchID) {
        self.currentEnrollmentChallenge.identityPIN = PINOrNil;
    }
    
    IdentityProvider *identityProvider = self.currentEnrollmentChallenge.identityProvider;
    if (identityProvider == nil) {
        identityProvider = [self.identityService createIdentityProvider];
        identityProvider.identifier = self.currentEnrollmentChallenge.identityProviderIdentifier;
        identityProvider.displayName = self.currentEnrollmentChallenge.identityProviderDisplayName;
        identityProvider.authenticationUrl = self.currentEnrollmentChallenge.identityProviderAuthenticationUrl;
        identityProvider.infoUrl = self.currentEnrollmentChallenge.identityProviderInfoUrl;
        identityProvider.ocraSuite = self.currentEnrollmentChallenge.identityProviderOcraSuite;
        identityProvider.logo = self.currentEnrollmentChallenge.identityProviderLogo;
    }
    
    Identity *identity = self.currentEnrollmentChallenge.identity;
    if (identity == nil) {
        identity = [self.identityService createIdentity];
        identity.identifier = self.currentEnrollmentChallenge.identityIdentifier;
        identity.sortIndex = [NSNumber numberWithInteger:self.identityService.maxSortIndex + 1];
        identity.identityProvider = identityProvider;
        identity.salt = [self.secretService generateSecret];
    }
    
    identity.displayName = self.currentEnrollmentChallenge.identityDisplayName;
    
    if (![self.identityService saveIdentities]) {
        [self.identityService rollbackIdentities];
        
        NSString *errorTitle = NSLocalizedString(@"error_enroll_failed_to_store_identity_title", @"Account cannot be saved title");
        NSString *errorMessage = NSLocalizedString(@"error_enroll_failed_to_store_identity", @"Account cannot be saved message");
        NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
        
        NSError *error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRECUnknownError userInfo:details];
        completionHandler(false, error);
        self.currentEnrollmentChallenge = nil;
        return;
    }
    
    self.currentEnrollmentChallenge.identity = identity;
    self.currentEnrollmentChallenge.identityProvider = identityProvider;
    
    void (^sendConfirmationBlock)() = ^{
        EnrollmentConfirmationRequest *request = [[EnrollmentConfirmationRequest alloc] initWithEnrollmentChallenge:self.currentEnrollmentChallenge];
        [request sendWithCompletionHandler:^(BOOL success, NSError *error) {
            if (success) {
                self.currentEnrollmentChallenge.identity.blocked = @NO;
                [ServiceContainer.sharedInstance.identityService saveIdentities];
                completionHandler(true, nil);
                self.currentEnrollmentChallenge = nil;
            } else {
                if (![self.currentEnrollmentChallenge.identity.blocked boolValue]) {
                    [self.identityService deleteIdentity:self.currentEnrollmentChallenge.identity];
                    [self.identityService saveIdentities];
                }
                
                [self.secretService deleteSecretForIdentityIdentifier:self.currentEnrollmentChallenge.identityIdentifier
                                                   providerIdentifier:self.currentEnrollmentChallenge.identityProviderIdentifier];
                completionHandler(false, error);
                self.currentEnrollmentChallenge = nil;
            }
        }];
    };
    
    if (touchID) {
        [self.secretService setSecret:self.currentEnrollmentChallenge.identitySecret usingTouchIDforIdentity:self.currentEnrollmentChallenge.identity withCompletionHandler:^(BOOL success) {
            if (!success) {
                NSString *errorTitle = NSLocalizedString(@"error_enroll_failed_to_store_identity_title", @"Account cannot be saved title");
                NSString *errorMessage = NSLocalizedString(@"error_enroll_failed_to_generate_secret", @"Failed to generate identity secret. Please contact support.");
                NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
                
                NSError *error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRECUnknownError userInfo:details];
                completionHandler(false, error);
                self.currentEnrollmentChallenge = nil;
                return;
            }
            
            self.currentEnrollmentChallenge.identity.touchID = @YES;
            
            sendConfirmationBlock();
        }];
    } else {
        [self.secretService setSecret:self.currentEnrollmentChallenge.identitySecret
                          forIdentity:self.currentEnrollmentChallenge.identity
                              withPIN:self.currentEnrollmentChallenge.identityPIN];
        
        sendConfirmationBlock();
    }
    
}

- (void)completeAuthenticationChallengeWithSecret:(NSData *)secret completionHandler:(void (^)(BOOL succes, NSString *response, NSError *error))completionHandler {
    
    NSObject<OCRAProtocol> *ocra;
    if (self.currentAuthenticationChallenge.protocolVersion && [self.currentAuthenticationChallenge.protocolVersion intValue] >= 2) {
        ocra = [[OCRAWrapper alloc] init];
    } else {
        ocra = [[OCRAWrapper_v1 alloc] init];
    }
    
    NSError *error = nil;
    NSString *response = [ocra generateOCRA:self.currentAuthenticationChallenge.identityProvider.ocraSuite secret:secret challenge:self.currentAuthenticationChallenge.challenge sessionKey:self.currentAuthenticationChallenge.sessionKey error:&error];
    if (response == nil) {
        completionHandler(false, nil, error);
        self.currentAuthenticationChallenge = nil;
        return;
    }
    
    AuthenticationConfirmationRequest *request = [[AuthenticationConfirmationRequest alloc] initWithAuthenticationChallenge:self.currentAuthenticationChallenge response:response];
    [request sendWithCompletionHandler:^(BOOL success, NSError *error) {
        completionHandler(success, response, error);
        self.currentAuthenticationChallenge = nil;
    }];
}

@end
