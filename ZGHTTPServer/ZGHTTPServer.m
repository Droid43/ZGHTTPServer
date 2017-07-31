//
//  ZGHTTPServer.m
//  SampleHttpService
//
//  Created by Zeng Gen on 08/06/2017.
//  Copyright © 2017 Zeng Gen. All rights reserved.
//

#import "ZGHTTPServer.h"
#import "ZGHTTPConnectTask.h"

@interface ZGHTTPServer ()<GCDAsyncSocketDelegate>
@property (nonatomic, strong) dispatch_queue_t serverQueue;
@property (nonatomic, strong) dispatch_queue_t taskQueue;
@property (nonatomic, strong) GCDAsyncSocket *serverSocket;
@property (nonatomic, strong) NSMutableArray<ZGHTTPConnectTask *> *tasks;
@property (nonatomic, strong) NSRecursiveLock *taskLock;
@end


@implementation ZGHTTPServer

+ (instancetype)initWithConfig:(void (^)(ZGHTTPConfig *))configBlock{
    return [[self alloc] initWithConfig:configBlock];
}

- (instancetype)initWithConfig:(void (^)(ZGHTTPConfig *))configBlock{
    if(self = [self init]){
        _serverQueue = dispatch_queue_create("com.zenggen.ZGHTTPServer.serverQueue", NULL);
        _taskQueue = dispatch_queue_create("com.zenggen.ZGHTTPServer.taskQueue", NULL);
        _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_serverQueue];
        _config = [[ZGHTTPConfig alloc] init];
        if(configBlock) configBlock(_config);
        _config.taskQueue = _taskQueue;
    }
    return self;
}

- (void)serverSyncOperation:(void(^)()) block{
    dispatch_sync(self.serverQueue, block);
}

- (NSError *)start{
    __block NSError *error;
    [self serverSyncOperation:^{
        [_serverSocket acceptOnPort:self.config.port error:&error];
    }];
    return error;
}

- (void)stop{
    [_taskLock lock];
    [_tasks removeAllObjects];
    [_taskLock unlock];
    [self serverSyncOperation:^{
        [_serverSocket disconnect];
    }];
}

- (BOOL)isRunning{
    return _serverSocket.isConnected;
}

- (uint16_t)port{
    return _serverSocket.localPort;
}

- (void)setPort:(uint16_t) port{
    [self serverSyncOperation:^{
        _config.port = port;
    }];
    if([self isRunning]) [self start];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket{
    if(!_taskLock) self.taskLock = [[NSRecursiveLock alloc] init];
    if(!_tasks) self.tasks = @[].mutableCopy;
    __weak typeof(self) weakSelf = self;
    ZGHTTPConnectTask *connectTast = [ZGHTTPConnectTask initWithConfig:_config socket:newSocket complete:^(ZGHTTPConnectTask *task) {
        typeof(self) strongSelf = weakSelf;
        [strongSelf.taskLock lock];
        [strongSelf.tasks removeObject:task];
        [strongSelf.taskLock unlock];
    }];
    [_taskLock lock];
    [_tasks addObject:connectTast];
    [_taskLock unlock];
    [connectTast execute];
}

@end
