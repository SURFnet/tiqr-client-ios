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

#import "IdentityService.h"
#import "IdentityProvider.h"
#import "SecretService.h"

#import "Identity.h"
#import "IdentityProvider.h"


@interface IdentityService ()

@property (nonatomic, strong, readwrite) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong, readwrite) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong, readwrite) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, weak) SecretService *secretService;

@end


@implementation IdentityService

- (instancetype)initWithSecretService:(SecretService *)secretService {
    if (self = [super init]) {
        self.secretService = secretService;
    }
    
    return self;
}

- (Identity *)createIdentity {
    return [NSEntityDescription insertNewObjectForEntityForName:@"Identity" inManagedObjectContext:self.managedObjectContext];
}

- (IdentityProvider *)createIdentityProvider {
    return [NSEntityDescription insertNewObjectForEntityForName:@"IdentityProvider" inManagedObjectContext:self.managedObjectContext];
}

- (void)deleteIdentity:(Identity *)identity {
    [self deleteObject:identity];
}

- (void)deleteIdentityProvider:(IdentityProvider *)identityProvider {
    [self deleteObject:identityProvider];
}

- (void)deleteObject:(NSManagedObject *)object {
    [self.managedObjectContext deleteObject:object];
}

- (NSFetchedResultsController *)createFetchedResultsControllerForIdentities {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Identity" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:20];
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"sortIndex" ascending:YES];
    NSArray *sortDescriptors = @[sortDescriptor];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    return fetchedResultsController;
}

- (IdentityProvider *)findIdentityProviderWithIdentifier:(NSString *)identifier  {
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"IdentityProvider" inManagedObjectContext:self.managedObjectContext];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier = %@", identifier];
    [request setPredicate:predicate];
    
    NSError *error = nil;
    NSArray *result = [self.managedObjectContext executeFetchRequest:request error:&error];
    
    IdentityProvider *identityProvider = nil;
    if (result != nil && [result count] == 1) {
        identityProvider = result[0];
    }
    
    return identityProvider;
}

- (NSUInteger)identityCount {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Identity" inManagedObjectContext:self.managedObjectContext];
    [request setEntity:entity];
    
    NSError *error = nil;
    NSUInteger count = [self.managedObjectContext countForFetchRequest:request error:&error];
    
    
    return error == nil ? count : 0;
}

- (NSUInteger)maxSortIndex {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Identity" inManagedObjectContext:self.managedObjectContext];
    [request setEntity:entity];
    
    NSExpression *keyPathExpression = [NSExpression expressionForKeyPath:@"sortIndex"];
    NSExpression *maxExpression = [NSExpression expressionForFunction:@"max:" arguments:@[keyPathExpression]];
    
    NSExpressionDescription *expressionDescription = [[NSExpressionDescription alloc] init];
    [expressionDescription setName:@"maxSortIndex"];
    [expressionDescription setExpression:maxExpression];
    [expressionDescription setExpressionResultType:NSInteger16AttributeType];
    
    [request setResultType:NSDictionaryResultType];
    [request setPropertiesToFetch:@[expressionDescription]];
    
    NSError *error = nil;
    NSArray *objects = [self.managedObjectContext executeFetchRequest:request error:&error];
    NSUInteger result = 0;
    if (objects != nil && [objects count] > 0) {
        result = [[objects[0] valueForKey:@"maxSortIndex"] intValue];
    }
    
    
    return result;
}

- (BOOL)allIdentitiesBlocked {
    if (self.identityCount == 0) {
        return NO;
    }
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Identity" inManagedObjectContext:self.managedObjectContext];
    [request setEntity:entity];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"blocked = %@", @NO];
    [request setPredicate:predicate];
    
    NSError *error = nil;
    NSUInteger count = [self.managedObjectContext countForFetchRequest:request error:&error];
    
    return error == nil && count == 0;
}

- (Identity *)findIdentityWithIdentifier:(NSString *)identifier forIdentityProvider:(IdentityProvider *)identityProvider {
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Identity" inManagedObjectContext:self.managedObjectContext];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier = %@ AND identityProvider = %@", identifier, identityProvider];
    [request setPredicate:predicate];
    
    NSError *error = nil;
    NSArray *result = [self.managedObjectContext executeFetchRequest:request error:&error];
    
    Identity *identity = nil;
    if (result != nil && [result count] == 1) {
        identity = result[0];
    }
    
    return identity;
}

- (NSArray *)findIdentitiesForIdentityProvider:(IdentityProvider *)identityProvider  {
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Identity" inManagedObjectContext:self.managedObjectContext];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identityProvider = %@", identityProvider];
    [request setPredicate:predicate];
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"sortIndex" ascending:YES];
    [request setSortDescriptors:@[sortDescriptor]];
    
    NSError *error = nil;
    NSArray *result = [self.managedObjectContext executeFetchRequest:request error:&error];
    
    return result;
}

- (void)blockAllIdentities  {
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Identity" inManagedObjectContext:self.managedObjectContext];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    NSError *error = nil;
    NSArray *identities = [self.managedObjectContext executeFetchRequest:request error:&error];
    
    if (error == noErr && identities != nil) {
        for (Identity *identity in identities) {
            identity.blocked = @YES;
        }
    }
}

- (BOOL)upgradeIdentity:(Identity *)identity withPIN:(NSString *)PIN {
    if ([identity.version integerValue] < 2) {
        
        NSData *secret = [self.secretService secretForIdentity:identity withPIN:PIN salt:nil initializationVector:nil];
        if (!secret) {
            return NO;
        }
        
        NSData *salt = [self.secretService generateSecret];
        NSData *initializationVector = [self.secretService generateSecret];
        
        if ([self.secretService setSecret:secret forIdentity:identity withPIN:PIN salt:salt initializationVector:initializationVector]) {
            identity.salt = salt;
            identity.initializationVector = initializationVector;
            identity.version = @2;
            return YES;
        }
    }
    return NO;
}



#pragma mark -
#pragma mark Core Data stack

- (BOOL)save {
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            return NO;
        }
    }
    
    return YES;
}

- (void)rollback {
    [self.managedObjectContext rollback];
}

- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    
    NSString *modelPath = [[NSBundle mainBundle] pathForResource:@"Tiqr" ofType:@"momd"];
    if (modelPath == nil) {
        modelPath = [[NSBundle mainBundle] pathForResource:@"Tiqr" ofType:@"mom"];
    }
    
    NSURL *modelURL = [NSURL fileURLWithPath:modelPath];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *applicationDocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    
    NSURL *storeURL = [applicationDocumentsDirectory URLByAppendingPathComponent:@"Tiqr.sqlite"];
    
    NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                              NSInferMappingModelAutomaticallyOption: @YES};
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}

@end
