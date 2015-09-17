//
//  TiqrNavigationBar.m
//  Tiqr
//
//  Created by Thom Hoekstra on 17-09-15.
//  Copyright (c) 2015 Egeniq. All rights reserved.
//

#import "TiqrNavigationBar.h"

@implementation TiqrNavigationBar

- (void)awakeFromNib {
    UIImageView *tiqrHeaderView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tiqr-header"]];
    [self addSubview:tiqrHeaderView];
    
    tiqrHeaderView.center = self.center;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
