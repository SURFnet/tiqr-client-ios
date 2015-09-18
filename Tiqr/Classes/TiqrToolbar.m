//
//  TiqrToolbar.m
//  Tiqr
//
//  Created by Thom Hoekstra on 18-09-15.
//  Copyright (c) 2015 Egeniq. All rights reserved.
//

#import "TiqrToolbar.h"

@implementation TiqrToolbar

- (void)awakeFromNib {
    UIButton *surfnetButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [surfnetButton setImage:[UIImage imageNamed:@"surfnet-logo"] forState:UIControlStateNormal];
    [surfnetButton addTarget:self action:@selector(surfnet) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:surfnetButton];
    
    surfnetButton.frame = CGRectMake(self.frame.size.width - 109, 6, 109, 32);
}

- (void)surfnet {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.surfnet.nl/en/"]];
}

@end
