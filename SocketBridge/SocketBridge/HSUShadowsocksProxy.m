//
//  HSUShadowsocksProxy.m
//  Test
//
//  Created by Jason Hsu on 13-9-7.
//  Copyright (c) 2013年 Jason Hsu. All rights reserved.
//

#import "HSUShadowsocksProxy.h"
#import "GCDAsyncSocket.h"
#include "encrypt.h"

@interface HSUShadowsocksPipeline : NSObject
{
 @public
    struct encryption_ctx encryptionContext;
}

@property (nonatomic, strong) GCDAsyncSocket *localSocket;
@property (nonatomic, strong) GCDAsyncSocket *remoteSocket;

@end

@implementation HSUShadowsocksPipeline
@end


@implementation HSUShadowsocksProxy
{
    dispatch_queue_t _socketQueue;
    GCDAsyncSocket *_serverSocket;
    NSMutableArray *_pipelines;
}

- (HSUShadowsocksPipeline *)pipelineOfLocalSocket:(GCDAsyncSocket *)localSocket
{
    __block HSUShadowsocksPipeline *ret;
    [_pipelines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        HSUShadowsocksPipeline *pipeline = obj;
        if (pipeline.localSocket == localSocket) {
            ret = pipeline;
        }
    }];
    return ret;
}

- (HSUShadowsocksPipeline *)pipelineOfRemoteSocket:(GCDAsyncSocket *)remoteSocket
{
    __block HSUShadowsocksPipeline *ret;
    [_pipelines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        HSUShadowsocksPipeline *pipeline = obj;
        if (pipeline.remoteSocket == remoteSocket) {
            ret = pipeline;
        }
    }];
    return ret;
}

- (void)dealloc
{
    _serverSocket = nil;
    _pipelines = nil;
}

- (id)init
{
    self = [super init];
    if (self) {
        config_encryption("thanksgiving", "table");
    }
    return self;
}

- (BOOL)start
{
    [self stop];
    _socketQueue = dispatch_queue_create("me.tuoxie.shadowsocks", NULL);
    _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_socketQueue];
    NSError *error;
    [_serverSocket acceptOnPort:11010 error:&error];
    if (error) {
        NSLog(@"bind failed, %@", error);
        return NO;
    }
    _pipelines = [[NSMutableArray alloc] init];
    return YES;
}

- (void)stop
{
    [_serverSocket disconnect];
    @synchronized(_pipelines) {
        [_pipelines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            HSUShadowsocksPipeline *pipeline = obj;
            [pipeline.localSocket disconnect];
            [pipeline.remoteSocket disconnect];
        }];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    NSLog(@"new request");
    HSUShadowsocksPipeline *pipeline = [[HSUShadowsocksPipeline alloc] init];
    pipeline.localSocket = newSocket;
    
    GCDAsyncSocket *remoteSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_socketQueue];
    [remoteSocket connectToHost:@"106.187.45.148" onPort:22 error:nil];
    pipeline.remoteSocket = remoteSocket;
    
    // encrypt code
    init_encryption(&(pipeline->encryptionContext));
    
    @synchronized(_pipelines) {
        [_pipelines addObject:pipeline];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    GCDAsyncSocket *localSocket;
    @synchronized(_pipelines) {
        localSocket = [self pipelineOfRemoteSocket:sock].localSocket;
    }
    [localSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    HSUShadowsocksPipeline *pipeline;
    int len = data.length;
    
    @synchronized(_pipelines) {
        pipeline = [self pipelineOfRemoteSocket:sock];
    }
    if (pipeline) { // read from remote
        NSLog(@"remote data length: %d", data.length);
        // encrypt code
        decrypt_buf(&(pipeline->encryptionContext), (char *)data.bytes, &len);
        [pipeline.localSocket writeData:data withTimeout:-1 tag:0];
        return;
    }
    
    @synchronized(_pipelines) {
        pipeline = [self pipelineOfLocalSocket:sock];
    }
    if (pipeline) { // read from local
        NSLog(@"local data length: %d", data.length);
        // encrypt code
        encrypt_buf(&(pipeline->encryptionContext), (char *)data.bytes, &len);
        [pipeline.remoteSocket writeData:data withTimeout:-1 tag:0];
        return;
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    [sock readDataWithTimeout:-1 tag:0];
    
    GCDAsyncSocket *localSocket;
    GCDAsyncSocket *remoteSocket;
    @synchronized(_pipelines) {
        localSocket = [self pipelineOfRemoteSocket:sock].localSocket;
        remoteSocket = [self pipelineOfLocalSocket:sock].remoteSocket;
    }
    if (localSocket) { // read from remote
        [localSocket readDataWithTimeout:-1 tag:0];
    } else if (remoteSocket) { // read from local
        [remoteSocket readDataWithTimeout:-1 tag:0];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    HSUShadowsocksPipeline *pipeline;
    
    @synchronized(_pipelines) {
        pipeline = [self pipelineOfRemoteSocket:sock];
    }
    if (pipeline) { // disconnect remote
        NSLog(@"remote disconnect");
        if (pipeline.localSocket.isDisconnected) {
            [_pipelines removeObject:pipeline];
            // encrypt code
            cleanup_encryption(&(pipeline->encryptionContext));
        } else {
            [pipeline.localSocket disconnectAfterReadingAndWriting];
        }
        return;
    }
    
    @synchronized(_pipelines) {
        pipeline = [self pipelineOfLocalSocket:sock];
    }
    if (pipeline) { // disconnect local
        NSLog(@"local disconnect");
        if (pipeline.remoteSocket.isDisconnected) {
            [_pipelines removeObject:pipeline];
            // encrypt code
            cleanup_encryption(&(pipeline->encryptionContext));
        } else {
            [pipeline.remoteSocket disconnectAfterReadingAndWriting];
        }
        return;
    }
}

@end
