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

#import "IdentityEditViewController.h"
#import "Identity.h"
#import "IdentityProvider.h"
#import "SecretStore.h"

@interface IdentityEditViewController ()

@property (nonatomic, strong) Identity *identity;
@property (nonatomic, strong) IBOutlet UIButton *deleteButton;
@property (nonatomic, strong) IBOutlet UIImageView *identityProviderLogoImageView;
@property (nonatomic, strong) IBOutlet UILabel *identityProviderIdentifierLabel;
@property (nonatomic, strong) IBOutlet UILabel *identityProviderDisplayNameLabel;
@property (nonatomic, strong) IBOutlet UILabel *blockedWarningLabel;
@property (nonatomic, strong) UITableView *tableView;

@end

@implementation IdentityEditViewController

- (instancetype)initWithIdentity:(Identity *)identity {
    self = [super initWithNibName:@"IdentityEditView" bundle:nil];
    if (self != nil) {
        self.identity = identity;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.deleteButton setTitle:NSLocalizedString(@"delete_button", @"Delete") forState:UIControlStateNormal];
    self.deleteButton.layer.cornerRadius = 5;
    
    self.blockedWarningLabel.text = NSLocalizedString(@"identity_blocked_message", @"Warning this account is blocked and needs to be reactivated.");
    
    self.identityProviderLogoImageView.image = [UIImage imageWithData:self.identity.identityProvider.logo];
    self.identityProviderIdentifierLabel.text = self.identity.identityProvider.identifier;
    self.identityProviderDisplayNameLabel.text = self.identity.identityProvider.displayName;    
    
    if ([self.identity.blocked boolValue]) {
        self.blockedWarningLabel.hidden = NO;
    }
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
	
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.detailTextLabel.minimumScaleFactor = 0.75;
        cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
    }

    cell.accessoryType = UITableViewCellAccessoryNone;
    
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
    cell.detailTextLabel.textColor = [UIColor blackColor];
    
    if (indexPath.row == 0) {
        cell.textLabel.text = NSLocalizedString(@"full_name", @"Username label");
        cell.detailTextLabel.text = self.identity.displayName;
    } else if (indexPath.row == 1) {
        cell.textLabel.text = NSLocalizedString(@"id", @"User ID label");
        cell.detailTextLabel.text = self.identity.identifier;
    } else if (indexPath.row == 2) {
        cell.textLabel.text = NSLocalizedString(@"information", @"Info label");
        cell.detailTextLabel.text = self.identity.identityProvider.infoUrl;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 2) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.identity.identityProvider.infoUrl]];
    }
}

- (IBAction)deleteIdentity {
    NSString *title = NSLocalizedString(@"confirm_delete_title", @"Sure?");
    NSString *message = NSLocalizedString(@"confirm_delete", @"Are you sure you want to delete this identity?");
    NSString *yesTitle = NSLocalizedString(@"yes_button", @"Yes button title");
    NSString *noTitle = NSLocalizedString(@"no_button", @"No button title");
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:nil otherButtonTitles:yesTitle, noTitle, nil];
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        [self performDeleteIdentity];
    }
}

- (void)performDeleteIdentity{
    NSManagedObjectContext *context = self.identity.managedObjectContext;
    
    IdentityProvider *identityProvider = self.identity.identityProvider;
    
    SecretStore *store = nil;       
    if (identityProvider != nil) {
        store = [SecretStore secretStoreForIdentity:self.identity.identifier identityProvider:identityProvider.identifier];		
		
        [identityProvider removeIdentitiesObject:self.identity];
        [context deleteObject:self.identity];
        if ([identityProvider.identities count] == 0) {
            [context deleteObject:identityProvider];
        }
    } else {
        [context deleteObject:self.identity];            
    }
    
    NSError *error = nil;
    if ([context save:&error]) {
        if (store != nil) {
            [store deleteFromKeychain];
        }
        
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        NSLog(@"Unexpected error: %@", error);
		NSString *title = NSLocalizedString(@"error", "Alert title for error");		
		NSString *message = NSLocalizedString(@"error_auth_unknown_error", "Unexpected error message");		        
		NSString *okTitle = NSLocalizedString(@"ok_button", "OK button title");		
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:okTitle otherButtonTitles:nil];
		[alertView show];
    }
}

- (void)resetOutlets {
    self.identityProviderLogoImageView = nil;
    self.identityProviderIdentifierLabel = nil;    
    self.identityProviderDisplayNameLabel = nil;
    self.blockedWarningLabel = nil;
    self.tableView = nil;
    self.deleteButton = nil;
}

- (void)viewDidUnload {
    [self resetOutlets];
    [super viewDidUnload];
}

- (void)dealloc {
    [self resetOutlets];
}

@end