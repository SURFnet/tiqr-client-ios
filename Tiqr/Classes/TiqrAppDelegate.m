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
        [self startChallenge:[info valueForKey:@"challenge"]];
        return YES;
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
    [ServiceContainer.sharedInstance.identityService saveIdentities];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	[self.navigationController popToRootViewControllerAnimated:NO];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [ServiceContainer.sharedInstance.identityService saveIdentities];
}

#pragma mark -
#pragma mark Authentication / enrollment challenge

- (void)startChallenge: (NSString *)rawChallenge  {
    UIViewController *firstViewController = self.navigationController.viewControllers[[self.navigationController.viewControllers count] > 1 ? 1 : 0];
    [self.navigationController popToViewController:firstViewController animated:NO];
    
    ChallengeService *challengeService = ServiceContainer.sharedInstance.challengeService;
    
    [challengeService startChallengeFromScanResult:rawChallenge completionHandler:^(TIQRChallengeType type, NSError *error) {
        if (!error) {
            switch (type) {
                case TIQRChallengeTypeAuthentication: {
                    UIViewController *viewController = nil;
                    
                    if (challengeService.currentAuthenticationChallenge.identity != nil) {
                        viewController = [[AuthenticationConfirmViewController alloc] initWithAuthenticationChallenge:challengeService.currentAuthenticationChallenge];
                    } else {
                        viewController = [[AuthenticationIdentityViewController alloc] initWithAuthenticationChallenge:challengeService.currentAuthenticationChallenge];
                    }
                    
                    [self.navigationController pushViewController:viewController animated:NO];
                } break;
                    
                case TIQRChallengeTypeEnrollment: {
                    EnrollmentConfirmViewController *enrollmentConfirmViewController = [[EnrollmentConfirmViewController alloc] initWithEnrollmentChallenge:challengeService.currentEnrollmentChallenge];
                    [self.navigationController pushViewController:enrollmentConfirmViewController animated:NO];
                } break;
                    
                default: break;
            }
        } else {
            ErrorViewController *errorViewController = [[ErrorViewController alloc] initWithErrorTitle:[error localizedDescription] errorMessage:[error localizedFailureReason]];
            [self.navigationController pushViewController:errorViewController animated:NO];
        }
    }];

}

#pragma mark -
#pragma mark Handle open URL

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options {
    [self startChallenge:[url description]];

    return YES;
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
	[self startChallenge:[info valueForKey:@"challenge"]];
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
