//
//  HSUShadowsocksProxy.h
//  Test
//
//  Created by Jason Hsu on 13-9-7.
//  Copyright (c) 2013年 Jason Hsu. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol GCDAsyncSocketDelegate;
@interface HSUShadowsocksProxy : NSObject <GCDAsyncSocketDelegate>

- (BOOL)start; // auto restart
- (void)stop;

@end
