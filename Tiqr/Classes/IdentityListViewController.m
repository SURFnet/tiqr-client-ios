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

#import "IdentityListViewController.h"
#import "ScanViewController.h"
#import "TiqrAppDelegate.h"
#import "Identity.h"
#import "IdentityProvider.h"
#import "IdentityTableViewCell.h"
#import "IdentityEditViewController.h"
#import "ServiceContainer.h"

@interface IdentityListViewController ()

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, assign) BOOL processingMoveRow;
@property (nonatomic, strong) Identity *selectedIdentity;

@end

@implementation IdentityListViewController

- (instancetype)init {
    self = [super initWithNibName:@"IdentityListView" bundle:nil];
    if (self != nil) {
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (ServiceContainer.sharedInstance.identityService.identityCount == 0) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)done {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:(BOOL)editing animated:(BOOL)animated];
    self.navigationItem.leftBarButtonItem.enabled = !editing;
}

- (void)configureCell:(IdentityTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    Identity *identity = [self.fetchedResultsController objectAtIndexPath:indexPath];
	[cell setIdentity:identity];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 60.0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return NSLocalizedString(@"identity_title", @"Identity select back button title");
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    IdentityTableViewCell *cell = (IdentityTableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[IdentityTableViewCell alloc] initWithReuseIdentifier:CellIdentifier];
    }
    
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Identity *identity = [self.fetchedResultsController objectAtIndexPath:indexPath];
    IdentityEditViewController *viewController = [[IdentityEditViewController alloc] initWithIdentity:identity];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        self.selectedIdentity = [self.fetchedResultsController objectAtIndexPath:indexPath];
        
        NSString *title = NSLocalizedString(@"confirm_delete_title", @"Sure?");
        NSString *message = NSLocalizedString(@"confirm_delete", @"Are you sure you want to delete this identity?");
        NSString *yesTitle = NSLocalizedString(@"yes_button", @"Yes button title");
        NSString *noTitle = NSLocalizedString(@"no_button", @"No button title");
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:nil otherButtonTitles:yesTitle, noTitle, nil];
        [alertView show];
    
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        [self performDeleteIdentity:self.selectedIdentity];
    }
}

- (void)performDeleteIdentity:(Identity *)identity {
    IdentityService *identityService = ServiceContainer.sharedInstance.identityService;
    IdentityProvider *identityProvider = identity.identityProvider;
    
    NSString *identityIdentifier = identity.identifier;
    NSString *providerIdentifier = identityProvider.identifier;
    
    if (identityProvider != nil) {
        
        [identityProvider removeIdentitiesObject:identity];
        [identityService deleteIdentity:identity];
        if ([identityProvider.identities count] == 0) {
            [identityService deleteIdentityProvider:identityProvider];
        }
    } else {
        [identityService deleteIdentity:identity];
    }
    
    if ([identityService saveIdentities]) {
        [ServiceContainer.sharedInstance.secretService deleteSecretForIdentityIdentifier:identityIdentifier
                                                                      providerIdentifier:providerIdentifier];
        
        if (ServiceContainer.sharedInstance.identityService.identityCount == 0) {
            [self.navigationController popViewControllerAnimated:YES];
        }
    } else {
        NSString *title = NSLocalizedString(@"error", "Alert title for error");
        NSString *message = NSLocalizedString(@"error_auth_unknown_error", "Unexpected error message");
        NSString *okTitle = NSLocalizedString(@"ok_button", "OK button title");
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:okTitle otherButtonTitles:nil];
        [alertView show];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
	self.processingMoveRow = YES;
	
	NSMutableArray *fetchedObjects = [NSMutableArray arrayWithArray:[self.fetchedResultsController fetchedObjects]];  	
	id movedObject = fetchedObjects[fromIndexPath.row];
	[fetchedObjects removeObjectAtIndex:fromIndexPath.row];
	[fetchedObjects insertObject:movedObject atIndex:toIndexPath.row];
	
	NSInteger sortIndex = 0;
	for (Identity *identity in fetchedObjects) {
		identity.sortIndex = [NSNumber numberWithInteger:sortIndex];
		sortIndex++;
	}
	
    if (![ServiceContainer.sharedInstance.identityService saveIdentities]) {
        NSString *title = NSLocalizedString(@"error", "Alert title for error");		
        NSString *message = NSLocalizedString(@"error_auth_unknown_error", "Unexpected error message");		        
        NSString *okTitle = NSLocalizedString(@"ok_button", "OK button title");			
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:okTitle otherButtonTitles:nil];
		[alertView show];
    }
	
	self.processingMoveRow = NO;	
}

#pragma mark -
#pragma mark Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    IdentityService *identityService = ServiceContainer.sharedInstance.identityService;
    self.fetchedResultsController = [identityService createFetchedResultsControllerForIdentities];
    self.fetchedResultsController.delegate = self;
    
    
    NSError *error = nil;
    if (![_fetchedResultsController performFetch:&error]) {
        NSLog(@"Unexpected error: %@", error);
        NSString *title = NSLocalizedString(@"error", "Alert title for error");		
        NSString *message = NSLocalizedString(@"error_auth_unknown_error", "Unexpected error message");		        
        NSString *okTitle = NSLocalizedString(@"ok_button", "OK button title");			
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:okTitle otherButtonTitles:nil];
		[alertView show];
    }
    
    return _fetchedResultsController;
}    

#pragma mark -
#pragma mark Fetched results controller delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
	if (self.processingMoveRow) {
		return;
	}
	
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
	if (self.processingMoveRow) {
		return;
	}
	
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:(IdentityTableViewCell *)[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
			[tableView reloadData];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
	if (self.processingMoveRow) {
		return;
	}
	
    [self.tableView endUpdates];
}


@end