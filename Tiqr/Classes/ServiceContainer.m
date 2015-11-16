//
//  ServiceContainer.m
//  Tiqr
//
//  Created by Thom Hoekstra on 16-11-15.
//  Copyright © 2015 Egeniq. All rights reserved.
//

#import "ServiceContainer.h"
#import "IdentityService.h"


@interface ServiceContainer ()

@property (nonatomic, strong) IdentityService *identityService;

@end


@implementation ServiceContainer


- (instancetype)init {
    if (self = [super init]) {
        self.identityService = [[IdentityService alloc] init];
    }
    
    return self;
}



+ (instancetype)sharedInstance {
    static id instance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    
    return instance;
}

@end
