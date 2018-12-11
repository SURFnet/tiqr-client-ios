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

#import <Foundation/Foundation.h>

@class AuthenticationChallenge;
@class EnrollmentChallenge;
@class SecretService;
@class IdentityService;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TIQRChallengeType) {
    TIQRChallengeTypeEnrollment,
    TIQRChallengeTypeAuthentication,
    TIQRChallengeTypeInvalid
};


@interface ChallengeService : NSObject

- (instancetype)initWithSecretService:(SecretService *)secretService identityService:(IdentityService *)identityService;


/**
 * Attempts to parse the supplied scanResult and sets currentAuthenticationChallenge or currentEnrollmentChallenge accordingly
 *
 * @param completionHandler     The block that will be called when this method finishes
 */
- (void)startChallengeFromScanResult:(NSString *)scanResult completionHandler:(void (^)(TIQRChallengeType type, NSObject *challengeObject, NSError *error))completionHanlder;

/**
 * Attempts to complete the current enrollment challenge with the supplied data
 *
 * @param challenge             The enrollment challenge
 * @param biometricID           Indicates whether the secret for the identity should be stored using BiometricID
 * @param PIN                   the PIN that is to be used
 * @param completionHandler     The block that will be called when this method finishes
 *
 * @return list of identities
 */
- (void)completeEnrollmentChallenge:(EnrollmentChallenge *)challenge usingBiometricID:(BOOL)biometricID withPIN:(NSString *)PIN completionHandler:(void (^)(BOOL succes, NSError *error))completionHandler;


/**
 * Attempts to complete the current authentication challenge with the supplied data
 *
 * @param challenge             The authentication challenge
 * @param secret                The secret belonging to the identity for the current authentication challenge
 * @param completionHandler     The block that will be called when this method finishes
 *
 * @return list of identities
 */
- (void)completeAuthenticationChallenge:(AuthenticationChallenge *)challenge withSecret:(NSData *)secret completionHandler:(void (^)(BOOL succes, NSString *response, NSError *error))completionHandler;

@end

NS_ASSUME_NONNULL_END
