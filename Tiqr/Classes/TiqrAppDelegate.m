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

#import "TiqrAppDelegate.h"
#import "AuthenticationChallenge.h"
#import "EnrollmentChallenge.h"
#import "AuthenticationIdentityViewController.h"
#import "AuthenticationConfirmViewController.h"
#import "EnrollmentConfirmViewController.h"
#import "ScanViewController.h"
#import "NotificationRegistration.h"
#import "Reachability.h"
#import "ScanViewController.h"
#import "StartViewController.h"
#import "ErrorViewController.h"
#import "ServiceContainer.h"

@interface TiqrAppDelegate ()

- (BOOL)handleAuthenticationChallenge:(NSString *)rawChallenge;
- (BOOL)handleEnrollmentChallenge:(NSString *)rawChallenge;
@property (nonatomic, readonly, copy) NSURL *applicationDocumentsDirectory;

@end

@implementation TiqrAppDelegate

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
	BOOL showInstructions = 
        [defaults objectForKey:@"show_instructions_preference"] == nil || 
        [defaults boolForKey:@"show_instructions_preference"];		
    
    BOOL allIdentitiesBlocked = ServiceContainer.sharedInstance.identityService.allIdentitiesBlocked;
    
	if (!allIdentitiesBlocked && !showInstructions) {
		ScanViewController *scanViewController = [[ScanViewController alloc] init];
        [self.navigationController pushViewController:scanViewController animated:NO];
    }

    [self.window setRootViewController:self.navigationController];
    [self.window makeKeyAndVisible];

	NSDictionary *info = [launchOptions valueForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
	if (info != nil) {
		return [self handleAuthenticationChallenge:[info valueForKey:@"challenge"]];
	}
    
    #if !TARGET_IPHONE_SIMULATOR
	NSString *url = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SANotificationRegistrationURL"];
	if (url != nil && [url length] > 0) {
        //-- Set Notification
        if ([application respondsToSelector:@selector(isRegisteredForRemoteNotifications)]) {
            // iOS 8 Notifications
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeSound categories:nil];
            [application registerUserNotificationSettings:settings];
        } else {
            // iOS < 8 Notifications
            [application registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeSound];
        }
	}
    #endif
	
    return YES;
}

- (void)popToStartViewControllerAnimated:(BOOL)animated {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    BOOL showInstructions = [defaults objectForKey:@"show_instructions_preference"] == nil || [defaults boolForKey:@"show_instructions_preference"];
    BOOL allIdentitiesBlocked = ServiceContainer.sharedInstance.identityService.allIdentitiesBlocked;
    
    if (allIdentitiesBlocked || showInstructions) {
        [self.navigationController popToRootViewControllerAnimated:animated];
    } else {
        UIViewController *scanViewController = self.navigationController.viewControllers[1];
        [self.navigationController popToViewController:scanViewController animated:animated];
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [ServiceContainer.sharedInstance.identityService save];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	[self.navigationController popToRootViewControllerAnimated:NO];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [ServiceContainer.sharedInstance.identityService save];
}

#pragma mark -
#pragma mark Authentication / enrollment challenge

- (BOOL)handleAuthenticationChallenge:(NSString *)rawChallenge {
    UIViewController *firstViewController = self.navigationController.viewControllers[[self.navigationController.viewControllers count] > 1 ? 1 : 0];
    [self.navigationController popToViewController:firstViewController animated:NO];
	
	AuthenticationChallenge *challenge = [[AuthenticationChallenge alloc] initWithRawChallenge:rawChallenge];
	if (!challenge.isValid) {
        NSError *error = challenge.error;
        NSString *title = NSLocalizedString(@"login_title", @"Login navigation title");        
        ErrorViewController *viewController = [[ErrorViewController alloc] initWithTitle:title errorTitle:[error localizedDescription] errorMessage:[error localizedFailureReason]];
        [self.navigationController pushViewController:viewController animated:NO];
		return NO;
	}
	
	UIViewController *viewController = nil;
	if (challenge.identity != nil) {
		viewController = [[AuthenticationConfirmViewController alloc] initWithAuthenticationChallenge:challenge];
	} else {
		viewController = [[AuthenticationIdentityViewController alloc] initWithAuthenticationChallenge:challenge];
	}	
	
	[self.navigationController pushViewController:viewController animated:NO];
	
    return YES;		
}

- (BOOL)handleEnrollmentChallenge:(NSString *)rawChallenge {
    UIViewController *firstViewController = self.navigationController.viewControllers[[self.navigationController.viewControllers count] > 1 ? 1 : 0];
    [self.navigationController popToViewController:firstViewController animated:NO];
    
	EnrollmentChallenge *challenge = [[EnrollmentChallenge alloc] initWithRawChallenge:rawChallenge];
	if (!challenge.isValid) {
        NSError *error = challenge.error;
        NSString *title = NSLocalizedString(@"enrollment_confirmation_header_title", @"Account activation title");        
        ErrorViewController *viewController = [[ErrorViewController alloc] initWithTitle:title errorTitle:[error localizedDescription] errorMessage:[error localizedFailureReason]];
        [self.navigationController pushViewController:viewController animated:NO];
		return NO;
	}
	
	UIViewController *viewController = [[EnrollmentConfirmViewController alloc] initWithEnrollmentChallenge:challenge];
	[self.navigationController pushViewController:viewController animated:NO];
	
    return YES;	
}

#pragma mark -
#pragma mark Handle open URL

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    NSString *authenticationScheme = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TIQRAuthenticationURLScheme"]; 
    NSString *enrollmentScheme = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TIQREnrollmentURLScheme"]; 
    
	if ([url.scheme isEqualToString:authenticationScheme]) {
		return [self handleAuthenticationChallenge:[url description]];
	} else if ([url.scheme isEqualToString:enrollmentScheme]) {
		return [self handleEnrollmentChallenge:[url description]];
	} else {
		return NO;
	}
}

#pragma mark -
#pragma mark Remote notifications

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
                [application registerForRemoteNotifications];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
	[[NotificationRegistration sharedInstance] sendRequestWithDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
	NSLog(@"Remote notification registration error: %@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)info {
	[self handleAuthenticationChallenge:[info valueForKey:@"challenge"]];
} 

#pragma mark - 
#pragma mark Connection handling
- (BOOL)hasConnection {   
    return (![Reachability reachabilityForInternetConnection].currentReachabilityStatus == NotReachable);
}

#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
}


@end
