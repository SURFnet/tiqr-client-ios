//
//  IdentityService.h
//  Tiqr
//
//  Created by Thom Hoekstra on 16-11-15.
//  Copyright © 2015 Egeniq. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Identity.h"
#import "IdentityProvider.h"

@interface IdentityService : NSObject

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
 * Upgrades the identity to use salt and initialization vector.
 *
 * NOTE: should be called with valid PIN only!
 */
- (BOOL)upgradeIdentity:(Identity *)identity withPIN:(NSString *)PIN;

/**
 * Saves the internal managed object context
 */
- (BOOL)save;

/**
 * Performs a rollback on the internal managed object context
 */
- (void)rollback;


@end
