//
//  ChallengeService.m
//  Tiqr
//
//  Created by Thom Hoekstra on 23-11-15.
//  Copyright © 2015 Egeniq. All rights reserved.
//

#import "ChallengeService.h"
#import "EnrollmentChallenge.h"
#import "AuthenticationChallenge.h"


@interface ChallengeService ()

@property (nonatomic, strong) AuthenticationChallenge *currentAuthenticationChallenge;
@property (nonatomic, strong) EnrollmentChallenge *currentEnrollmentChallenge;

@end


@implementation ChallengeService

- (void)startChallengeFromScanResult:(NSString *)scanResult completionHandler:(void (^)(TIQRChallengeType, NSError *))completionHandler {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSString *authenticationScheme = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TIQRAuthenticationURLScheme"];
        NSString *enrollmentScheme = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TIQREnrollmentURLScheme"];
        
        TIQRChallengeType type = TIQRChallengeTypeInvalid;
        
        NSURL *url = [NSURL URLWithString:scanResult];
        NSError *error = nil;
        if (url != nil && [url.scheme isEqualToString:authenticationScheme]) {
            type = TIQRChallengeTypeAuthentication;
            AuthenticationChallenge *challenge = [AuthenticationChallenge challengeWithChallengeString:scanResult error:&error];
            
            if (!error) {
                self.currentAuthenticationChallenge = challenge;
            }
        } else if (url != nil && [url.scheme isEqualToString:enrollmentScheme]) {
            type = TIQRChallengeTypeEnrollment;
            EnrollmentChallenge *challenge = [EnrollmentChallenge challengeWithChallengeString:scanResult allowFiles:NO error:&error];
            
            if (!error) {
                self.currentEnrollmentChallenge = challenge;
            }
        } else {
            NSString *errorTitle = NSLocalizedString(@"error_auth_invalid_qr_code", @"Invalid QR tag title");
            NSString *errorMessage = NSLocalizedString(@"error_auth_invalid_challenge_message", @"Unable to interpret the scanned QR tag. Please try again. If the problem persists, please contact the website adminstrator");
            NSDictionary *details = @{NSLocalizedDescriptionKey: errorTitle, NSLocalizedFailureReasonErrorKey: errorMessage};
            
            error = [NSError errorWithDomain:TIQRECErrorDomain code:TIQRACInvalidQRTagError userInfo:details];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(type, error);
        });
    });
}

@end
