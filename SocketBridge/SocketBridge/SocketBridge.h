//
//  SocketBridge.h
//  SocketBridge
//
//  Created by Jason Hsu on 13-9-17.
//  Copyright (c) 2013年 Jason Hsu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

@interface SocketBridge : NSObject <GCDAsyncSocketDelegate>

@property (nonatomic, copy) NSString *remoteHost;
@property (nonatomic, assign) NSUInteger remotePort;
@property (nonatomic, assign) NSUInteger localPort;

- (id)initWithRemoteHost:(NSString *)remoteHost
              remotePort:(NSUInteger)remotePort
               localPort:(NSUInteger)localPort;

- (BOOL)start; // auto stop before start
- (void)stop;

@end
