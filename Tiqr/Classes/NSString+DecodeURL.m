//
//  NSString+DecodeURL.m
//  Tiqr
//
//  Created by Thom Hoekstra on 16-11-15.
//  Copyright © 2015 Egeniq. All rights reserved.
//

#import "NSString+DecodeURL.h"

@implementation NSString (DecodeURL)

- (NSString *)decodedURL {
    
    NSString *decodedURL = [self copy];
    decodedURL = [self stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    decodedURL = [self stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return decodedURL;
}

@end
