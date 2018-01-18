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

#import <Security/Security.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonKeyDerivation.h>
#import <LocalAuthentication/LocalAuthentication.h>

#import "SecretService.h"
#import "Identity.h"
#import "IdentityProvider.h"

#define kChosenCipherKeySize kCCKeySizeAES256


@implementation SecretService

- (SecretServiceBiometricType)biometricType {
    if (!NSClassFromString(@"LAContext")) {
        return SecretServiceBiometricTypeNone;
    }

#ifdef DISABLE_BIOMETRIC_SUPPORT
    return SecretServiceBiometricTypeNone;
#endif

    LAContext *context = [[LAContext alloc] init];
    NSError *error = nil;

    BOOL enabled = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error] &&
                   [context respondsToSelector:@selector(evaluateAccessControl:operation:localizedReason:reply:)];

    if (!enabled) {
        return SecretServiceBiometricTypeNone;
    }

    if (@available(iOS 11, *)) {
        switch (context.biometryType) {
            case LABiometryTypeTouchID:
                return SecretServiceBiometricTypeTouchID;
                break;
            case LABiometryTypeFaceID:
                return SecretServiceBiometricTypeFaceID;
            default:
                return SecretServiceBiometricTypeNone;
        }
    }

    return SecretServiceBiometricTypeTouchID;
}

- (BOOL)biometricIDAvailable {
    switch (self.biometricType) {
        case SecretServiceBiometricTypeTouchID:
        case SecretServiceBiometricTypeFaceID:
            return YES;
        case SecretServiceBiometricTypeNone:
            return NO;
    }
}

- (NSData *)loadSecretForIdentity:(Identity *)identity {
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
    query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    query[(__bridge id)kSecAttrService] = identity.identityProvider.identifier;
    query[(__bridge id)kSecAttrAccount] = identity.identifier;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    query[(__bridge id)kSecReturnData] = (id)kCFBooleanTrue;
    query[(__bridge id)kSecReturnAttributes] = (id)kCFBooleanTrue;
    
    CFDictionaryRef result;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result) == noErr) {
        return (NSData *)((__bridge NSDictionary*)result)[(__bridge id)kSecValueData];
    } else {
        return nil;
    }
}

- (BOOL)storeSecret:(NSData *)secret forIdentity:(Identity *)identity {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    data[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    data[(__bridge id)kSecAttrService] = identity.identityProvider.identifier;
    data[(__bridge id)kSecAttrAccount] = identity.identifier;
    data[(__bridge id)kSecValueData] = secret;
    data[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlocked;
    
    CFDictionaryRef result;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)data, (CFTypeRef *)&result);
    return status == noErr;
}

- (BOOL)updateSecret:(NSData *)secret forIdentity:(Identity *)identity  {
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
    query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    query[(__bridge id)kSecAttrService] = identity.identityProvider.identifier;
    query[(__bridge id)kSecAttrAccount] = identity.identifier;
    
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    data[(__bridge id)kSecValueData] = secret;
    
    return SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)data) == noErr;
}

- (BOOL)updateOrStoreSecret:(NSData *)secret forIdentity:(Identity *)identity {
    if ([self loadSecretForIdentity:identity] == nil) {
        return [self storeSecret:secret forIdentity:identity];
    } else {
        return [self updateSecret:secret forIdentity:identity];
    }
}

- (BOOL)deleteSecretForIdentityIdentifier:(NSString *)identityIdentifier providerIdentifier:(NSString *)providerIdentifier; {
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
    query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    query[(__bridge id)kSecAttrService] = providerIdentifier;
    query[(__bridge id)kSecAttrAccount] = identityIdentifier;
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    return status == noErr;
}

- (NSData *)generateSecret {
    uint8_t *bytes = malloc(kChosenCipherKeySize * sizeof(uint8_t));
    memset((void *)bytes, 0x0, kChosenCipherKeySize);
    OSStatus sanityCheck = SecRandomCopyBytes(kSecRandomDefault, kChosenCipherKeySize, bytes);
    if (sanityCheck == noErr) {
        NSData *secret = [[NSData alloc] initWithBytes:(const void *)bytes length:kChosenCipherKeySize];
        return secret;
    } else {
        return nil;
    }
}

- (NSString *)keyForPIN:(NSString *)PIN salt:(NSData *)salt {
    // For backwards compatability
    if (!salt) {
        return PIN;
    }
    
    NSData *PINData = [PIN dataUsingEncoding:NSUTF8StringEncoding];
    
    // How many rounds to use so that it takes 0.1s ?
    int rounds = 32894; // Calculated using: CCCalibratePBKDF(kCCPBKDF2, PINData.length, saltData.length, kCCPRFHmacAlgSHA256, 32, 100);
    
    // Open CommonKeyDerivation.h for help
    unsigned char key[32];
    int result = CCKeyDerivationPBKDF(kCCPBKDF2, PINData.bytes, PINData.length, salt.bytes, salt.length, kCCPRFHmacAlgSHA256, rounds, key, 32);
    if (result == kCCParamError) {
        NSLog(@"Error %d deriving key", result);
        return nil;
    }
    
    NSMutableString *keyString = [[NSMutableString alloc] init];
    for (int i = 0; i < 32; ++i) {
        [keyString appendFormat:@"%02x", key[i]];
    }
    return keyString;
}

- (NSData *)encrypt:(NSData *)data key:(NSString *)key initializationVector:(NSData *)initializationVector {
    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    
    // There was an error in the conversion of the input key to a C-string using getCString; the buffer supplied was too small;
    // in iOS6 this resulted in truncation of the string during conversion so in the end it worked; in iOS7 the behaviour of getCString changed, so it now returns an error if the buffer supplied is too small.
    // The net result of this was that the same key was always used for encryption/decryption and the PIN was not used at all.
    
    // Note: there is another error here; the input key is an ASCII string with a hexadecimal representation of the key;
    // That should be converted to a byte array (unsigned char[]) before being used as input to CCCrypt, but the doesn't happen.
    // A separate issue for fixing this is still open because this is more complicated to fix since it requires migration of existing identities
    char keyBuffer[kChosenCipherKeySize * 2 + 1]; // room for terminator (unused)
    bzero(keyBuffer, sizeof(keyBuffer)); // fill with zeros (for padding)
    
    // fetch key data
    [key getCString:keyBuffer maxLength:sizeof(keyBuffer) encoding:NSASCIIStringEncoding];
    
    // iOS getCString truncates keyBuffer to maxLength. and replaces the first character with a 0
    // To ensure upgrading from iOS6 to 7 works. Do the same.
    keyBuffer[0] = 0;
    
    // For block ciphers, the output size will always be less than or
    // equal to the input size plus the size of one block.
    // That's why we need to add the size of one block here.
    size_t bufferSize = [data length] + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    
    // encrypt
    size_t numBytesEncrypted = 0;
    
    // check initialization vector length
    if ([initializationVector length] < kCCBlockSizeAES128) {
        initializationVector = nil;
    }
    
    CCCryptorStatus result = CCCrypt(kCCEncrypt,
                                     kCCAlgorithmAES128,
                                     0,
                                     keyBuffer,
                                     kChosenCipherKeySize,
                                     initializationVector ? [initializationVector bytes] : NULL, // initialization vector (optional)
                                     [data bytes], // input
                                     [data length],
                                     buffer, // output
                                     bufferSize,
                                     &numBytesEncrypted);
    
    if (result == kCCSuccess) {
        // the returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    
    free(buffer);
    return nil;
}

- (NSData *)decrypt:(NSData *)data key:(NSString *)key initializationVector:(NSData *)initializationVector {
    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    // There was an error in the conversion of the input key to a C-string using getCString; the buffer supplied was too small;
    // in iOS6 this resulted in truncation of the string during conversion so in the end it worked; in iOS7 the behaviour of getCString changed, so it now returns an error if the buffer supplied is too small.
    // The net result of this was that the same key was always used for encryption/decryption and the PIN was not used at all.
    
    // Note: there is another error here; the input key is an ASCII string with a hexadecimal representation of the key;
    // That should be converted to a byte array (unsigned char[]) before being used as input to CCCrypt, but the doesn't happen.
    // A separate issue for fixing this is still open because this is more complicated to fix since it requires migration of existing identities
    char keyBuffer[kChosenCipherKeySize * 2 + 1]; // room for terminator (unused)
    bzero(keyBuffer, sizeof(keyBuffer)); // fill with zeros (for padding)
    
    // fetch key data
    [key getCString:keyBuffer maxLength:sizeof(keyBuffer) encoding:NSUTF8StringEncoding];
    
    // iOS getCString truncates keyBuffer to maxLength. and replaces the first character with a 0
    // To ensure upgrading from iOS6 to 7 works. Do the same.
    keyBuffer[0] = 0;
    
    // For block ciphers, the output size will always be less than or
    // equal to the input size plus the size of one block.
    // That's why we need to add the size of one block here.
    size_t bufferSize = [data length] + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    
    // decrypt
    size_t numBytesDecrypted = 0;
    
    // check initialization vector length
    if ([initializationVector length] < kCCBlockSizeAES128) {
        initializationVector = nil;
    }
    
    CCCryptorStatus result = CCCrypt(kCCDecrypt,
                                     kCCAlgorithmAES128,
                                     0,
                                     keyBuffer,
                                     kChosenCipherKeySize,
                                     initializationVector ? [initializationVector bytes] : NULL, // initialization vector (optional)
                                     [data bytes], // input
                                     [data length],
                                     buffer, // output
                                     bufferSize,
                                     &numBytesDecrypted);
    
    if (result == kCCSuccess) {
        // the returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    
    free(buffer);
    return nil;
}

- (BOOL)setSecret:(NSData *)secret forIdentity:(Identity *)identity withPIN:(NSString *)PIN salt:(NSData *)salt initializationVector:(NSData *)initializationVector {
    NSString *key = [self keyForPIN:PIN salt:salt];
    NSData *encryptedSecret = [self encrypt:secret key:key initializationVector:initializationVector];
    
    return [self updateOrStoreSecret:encryptedSecret forIdentity:identity];
}

- (BOOL)setSecret:(NSData *)secret forIdentity:(Identity *)identity withPIN:(NSString *)PIN {
    return [self setSecret:secret forIdentity:identity withPIN:PIN salt:identity.salt initializationVector:identity.initializationVector];
}

- (void)setSecret:(NSData *)secret usingTouchIDforIdentity:(Identity *)identity withCompletionHandler:(void (^)(BOOL success))completionHandler {
    CFErrorRef error = NULL;
    SecAccessControlRef sacObject = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                                    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                                    kSecAccessControlTouchIDAny, &error);
    
    LAContext *context = [[LAContext alloc] init];
    
    [context evaluateAccessControl:sacObject operation:LAAccessControlOperationCreateItem localizedReason:NSLocalizedString(@"touch_id_reason", @"Tiqr wants to save the identity") reply:^(BOOL success, NSError * _Nullable error) {
        
        if (success) {
            
            NSDictionary *data = @{
                                   (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                   (__bridge id)kSecAttrService: identity.identityProvider.identifier,
                                   (__bridge id)kSecAttrAccount: identity.identifier,
                                   (__bridge id)kSecValueData: secret,
                                   (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlocked,
                                   (__bridge id)kSecUseAuthenticationContext: context
                                   };
            
            CFDictionaryRef result;
            OSStatus status = SecItemAdd((__bridge CFDictionaryRef)data, (CFTypeRef *)&result);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(status == noErr);
            });
            
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(false);
            });
        }
        
    }];
}

- (NSData *)secretForIdentity:(Identity *)identity withKey:(NSString *)key salt:(NSData *)salt initializationVector:(NSData *)initializationVector {
    NSData *storedEncryptedSecret = [self loadSecretForIdentity:identity];
    if (storedEncryptedSecret == nil) {
        return nil;
    }
    
    NSData *result = [self decrypt:storedEncryptedSecret key:key initializationVector:initializationVector];
    return result;
}

- (NSData *)secretForIdentity:(Identity *)identity withPIN:(NSString *)PIN salt:(NSData *)salt initializationVector:(NSData *)initializationVector {
    
    NSString *key = [self keyForPIN:PIN salt:salt];
    return [self secretForIdentity:identity withKey:key salt:salt initializationVector:initializationVector];
}

- (NSData *)secretForIdentity:(Identity *)identity withPIN:(NSString *)PIN {
    return [self secretForIdentity:identity withPIN:PIN salt:identity.salt initializationVector:identity.initializationVector];
}

- (void)secretForIdentity:(Identity *)identity touchIDPrompt:(NSString *)prompt withSuccessHandler:(void (^)(NSData *secret))successHandler failureHandler:(void (^)(BOOL cancelled))failureHandler {
    
    if (!self.biometricIDAvailable || ![identity.touchID boolValue]) {
        failureHandler(false);
        return;
    }
    
    CFErrorRef error = NULL;
    SecAccessControlRef sacObject = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                                    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                                    kSecAccessControlTouchIDAny, &error);
    
    LAContext *context = [[LAContext alloc] init];
    
    [context evaluateAccessControl:sacObject operation:LAAccessControlOperationUseItem localizedReason:prompt reply:^(BOOL success, NSError * _Nullable error) {
        
        if (success) {
            NSDictionary *query = @{
                                    (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                    (__bridge id)kSecAttrService: identity.identityProvider.identifier,
                                    (__bridge id)kSecAttrAccount: identity.identifier,
                                    (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
                                    (__bridge id)kSecReturnData: (id)kCFBooleanTrue,
                                    (__bridge id)kSecReturnAttributes: (id)kCFBooleanTrue,
                                    (__bridge id)kSecUseAuthenticationContext: context
                                    };
            
            CFDictionaryRef result;
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
            if (status == noErr) {
                NSData *secret = (NSData *)((__bridge NSDictionary*)result)[(__bridge id)kSecValueData];
                dispatch_async(dispatch_get_main_queue(), ^{
                    successHandler(secret);
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failureHandler(false);
                });
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                failureHandler(error.code == kLAErrorUserCancel);
            });
        }
    }];
}

@end
