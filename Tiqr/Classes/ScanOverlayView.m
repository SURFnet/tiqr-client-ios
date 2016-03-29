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

/**
 * Based on ZXingWidgetController.
 *
 * Copyright 2009 Jeff Verkoeyen
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "ScanOverlayView.h"

#define kPadding 10

@interface ScanOverlayView ()

@property (nonatomic, assign) CGRect cropRect;

@end

@implementation ScanOverlayView

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat rectSize = self.frame.size.width - kPadding * 2;
    self.cropRect = CGRectMake(kPadding, (self.frame.size.height - rectSize) / 2, rectSize, rectSize);
}

- (void)drawRect:(CGRect)rect inContext:(CGContextRef)context {
	CGContextBeginPath(context);
	CGContextMoveToPoint(context, rect.origin.x, rect.origin.y);
	CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y);
	CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y + rect.size.height);
	CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y + rect.size.height);
	CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y);
	CGContextStrokePath(context);
}

- (void)drawRect:(CGRect)rect {
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	CGFloat white[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
	CGContextSetStrokeColor(context, white);
	CGContextSetFillColor(context, white);
	[self drawRect:self.cropRect inContext:context];
	
	if (self.points != nil) {
		CGFloat green[4] = { 0.0f, 1.0f, 0.0f, 1.0f };
		CGContextSetStrokeColor(context, green);
		CGContextSetFillColor(context, green);
		CGRect smallSquare = CGRectMake(0, 0, 10, 10);
		for (NSValue *value in self.points) {
			CGPoint point = [value CGPointValue];
			smallSquare.origin = CGPointMake(point.x - smallSquare.size.width / 2,
                                             point.y - smallSquare.size.height / 2);
			[self drawRect:smallSquare inContext:context];
		}
	}
}

- (void)setPoints:(NSArray *)points {
    _points = points;
    [self setNeedsDisplay];
}

- (void)addPoint:(CGPoint)point {
    NSMutableArray *points = [NSMutableArray arrayWithArray:(self.points == nil ? @[] : self.points)];
    
    if ([points count] > 3) {
        [points removeObjectAtIndex:0];
    }
    
    [points addObject:[NSValue valueWithCGPoint:point]];
    self.points = [points copy];
    
    [self setNeedsDisplay];
}

@end