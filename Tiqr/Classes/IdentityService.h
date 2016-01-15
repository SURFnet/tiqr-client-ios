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

@class SecretService;
@class Identity;
@class IdentityProvider;
@class NSFetchedResultsController;

@interface IdentityService : NSObject

- (instancetype)initWithSecretService:(SecretService *)secretService;

/**
 * Insert a new Identity object into the internal managed object context
 *
 * @return the created Identity object
 */
- (Identity *)createIdentity;

/**
 * Insert a new IdentityProvider object into the internal managed object context
 *
 * @return the created IdentityProvider object
 */
- (IdentityProvider *)createIdentityProvider;

/**
 * Deletes the given Identy from the internal managed object context
 *
 * @param identity   identity
 */
- (void)deleteIdentity:(Identity *)identity;

/**
 * Deletes the given IdentyProvider from the internal managed object context
 *
 * @param identityProvider   identity provider
 */
- (void)deleteIdentityProvider:(IdentityProvider *)identityProvider;

- (NSFetchedResultsController *)createFetchedResultsControllerForIdentities;

/**
 * Tries to find the identity provider with the given identifier.
 *
 * @param identifier identity provider identifier
 *
 * @return the identity provider (or nil)
 */
- (IdentityProvider *)findIdentityProviderWithIdentifier:(NSString *)identifier;

/**
 * Returns the number of identities
 *
 * @return number of identities
 */
- (NSUInteger)identityCount;

/**
 * Returns the maximum identity sort index
 *
 * @return maximum sort index
 */
- (NSUInteger)maxSortIndex;

/**
 * Returns whether all identities are currently blocked or not.
 *
 * @return all identities blocked?
 */
- (BOOL)allIdentitiesBlocked;

/**
 * Searches for an identity with the given identifier for the given identity provider.
 *
 * @param identifier         identity identifier
 * @param identityProvider   identity provider
 *
 * @return identity
 */
- (Identity *)findIdentityWithIdentifier:(NSString *)identifier forIdentityProvider:(IdentityProvider *)identityProvider;

/**
 * Returns all the identities for the given provider.
 *
 * @param identityProvider identity provider
 *
 * @return list of identities
 */
- (NSArray *)findIdentitiesForIdentityProvider:(IdentityProvider *)identityProvider;

/**
 * Blocks all identities.
 *
 * NOTE: this method does not call save
 */
- (void)blockAllIdentities;


/**
 * Upgrades the identity to use salt and a initialization vector. If TouchID is available this will setup TouchID for this identity
 *
 * @param PIN The PIN for this identity or nil
 *
 */
- (void)upgradeIdentity:(Identity *)identity withPIN:(NSString *)PIN;

/**
 * Upgrades the identity to use TouchID
 *
 * @param PIN The current PIN for this identity
 *
 */
- (void)upgradeIdentityToTouchID:(Identity *)identity withPIN:(NSString *)PIN;

/**
 * Saves the internal managed object context
 */
- (BOOL)saveIdentities;

/**
 * Performs a rollback on the internal managed object context
 */
- (void)rollbackIdentities;


@end
