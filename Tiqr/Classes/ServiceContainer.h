//
//  ServiceContainer.h
//  Tiqr
//
//  Created by Thom Hoekstra on 16-11-15.
//  Copyright © 2015 Egeniq. All rights reserved.
//

#import <Foundation/Foundation.h>



@class IdentityService;



@interface ServiceContainer : NSObject

@property (nonatomic, strong, readonly) IdentityService *identityService;

+ (instancetype)sharedInstance;

@end
