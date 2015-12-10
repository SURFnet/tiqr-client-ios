//
//  ChallengeService.h
//  Tiqr
//
//  Created by Thom Hoekstra on 23-11-15.
//  Copyright © 2015 Egeniq. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AuthenticationChallenge;
@class EnrollmentChallenge;

typedef NS_ENUM(NSInteger, TIQRChallengeType) {
    TIQRChallengeTypeEnrollment,
    TIQRChallengeTypeAuthentication,
    TIQRChallengeTypeInvalid
};


@interface ChallengeService : NSObject

@property (nonatomic, strong, readonly) AuthenticationChallenge *currentAuthenticationChallenge;
@property (nonatomic, strong, readonly) EnrollmentChallenge *currentEnrollmentChallenge;

- (void)startChallengeFromScanResult:(NSString *)scanResult completionHandler:(void (^)(TIQRChallengeType type, NSError *error))completionHanlder;

@end
