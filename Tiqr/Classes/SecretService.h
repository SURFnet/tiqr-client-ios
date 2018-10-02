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

typedef NS_ENUM(NSInteger, SecretServiceBiometricType) {
    SecretServiceBiometricTypeNone,
    SecretServiceBiometricTypeTouchID,
    SecretServiceBiometricTypeFaceID
};

@class Identity;

@interface SecretService : NSObject

/** 
 * Indicates if biometrics are available (Touch or ID face ID)
 *
 * It's possible to disable biometric ID by defining DISABLE_BIOMETRIC_SUPPORT
 */
@property (nonatomic, assign, readonly) BOOL biometricIDAvailable;

/**
 * Indicates which type of biometrics is available to Tiqr (Touch ID or Face ID)

 * It's possible to disable biometric ID by defining DISABLE_BIOMETRIC_SUPPORT
 */
@property (nonatomic, assign, readonly) SecretServiceBiometricType biometricType;

/**
 * Generate a new random secret.
 *
 * @return new random secret data
 */
- (NSData *)generateSecret;

/**
 * Deletes the secret for the supplied identity from the Keychain.
 *
 * @param identityIdentifier identity identifier
 * @param providerIdentifier provider identifier
 *
 * @return whether deleting the secret was successful or not
 */
- (BOOL)deleteSecretForIdentityIdentifier:(NSString *)identityIdentifier providerIdentifier:(NSString *)providerIdentifier;

/**
 * Sets the secret, encrypted with the given PIN.
 *
 * @param secret secret
 * @param identity  identity
 * @param PIN    PIN
 * @param salt   salt
 * @param initializationVector  initializationVector
 *
 * @return whether setting the secret was successful or not
 */
- (BOOL)setSecret:(NSData *)secret forIdentity:(Identity *)identity withPIN:(NSString *)PIN salt:(NSData *)salt initializationVector:(NSData *)initializationVector;

/**
 * Sets the secret, encrypted with the given PIN.
 *
 * Uses the salt and initializationVector from the supplied Identity
 *
 * @param secret    secret
 * @param identity  identity
 * @param PIN       PIN
 *
 * @return whether setting the secret was successful or not
 */
- (BOOL)setSecret:(NSData *)secret forIdentity:(Identity *)identity withPIN:(NSString *)PIN;

/**
 * Attempts to store the secret on the Secure Enclave of the device using TouchID
 *
 * @param secret    secret
 * @param identity  identity
 * @param completionHandler    The block to be executed when the operation is completed
 *
 */
- (void)setSecret:(NSData *)secret usingTouchIDforIdentity:(Identity *)identity withCompletionHandler:(void (^)(BOOL success))completionHandler;

/**
 * Returns the decrypted secret, decrypted with the given PIN.
 *
 * There is no way in telling if the PIN was correct or not.
 *
 * @param PIN   PIN
 * @param salt  salt
 * @param initializationVector  initializationVector
 *
 * @return decrypted secret
 */
- (NSData *)secretForIdentity:(Identity *)identity withPIN:(NSString *)PIN salt:(NSData *)salt initializationVector:(NSData *)initializationVector;

/**
 * Returns the decrypted secret, decrypted with the given PIN.
 *
 * Uses the salt and initializationVector from the supplied Identity
 *
 * @param PIN       PIN
 * @param identity  identity
 *
 * @return decrypted secret
 */
- (NSData *)secretForIdentity:(Identity *)identity withPIN:(NSString *)PIN;

/**
 * Attempts to use TouchID to fetch the secret for an identity
 *
 * Uses the salt and initializationVector from the supplied Identity
 *
 * @param identity             identity
 * @param completionHandler    The block to be executed when the operation is completed
 *
 */
- (void)secretForIdentity:(Identity *)identity touchIDPrompt:(NSString *)prompt withSuccessHandler:(void (^)(NSData *secret))successHandler failureHandler:(void (^)(BOOL cancelled))failureHandler;

@end
