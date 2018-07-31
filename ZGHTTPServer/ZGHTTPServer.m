//
//  ZGHTTPServer.m
//  SampleHttpService
//
//  Created by Zeng Gen on 08/06/2017.
//  Copyright © 2017 Zeng Gen. All rights reserved.
//

#import "ZGHTTPServer.h"
#import "ZGHTTPConnectTask.h"
#include <arpa/inet.h>
#include <net/if.h>
#include <ifaddrs.h>

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

- (void)serverSyncOperation:(void(^)(void)) block{
    dispatch_sync(self.serverQueue, block);
}


- (NSError *)start{
    __block NSError *error;
    [self serverSyncOperation:^{
        [self.serverSocket acceptOnPort:self.config.port error:&error];
    }];
    return error;
}

- (void)stop{
    [_taskLock lock];
    [_tasks removeAllObjects];
    [_taskLock unlock];
    [_serverSocket disconnect];
}
- (BOOL)isRunning{
    return _serverSocket.isConnected;
}
- (uint16_t)port{
    return _config.port;
}

- (void)setPort:(uint16_t) port{
    _config.port = port;
    if([self isRunning]) [self start];
}


- (NSString *)IP{
    BOOL success;
    struct ifaddrs * addrs;
    const struct ifaddrs * cursor;
    success = getifaddrs(&addrs) == 0;
    if (success) {
        cursor = addrs;
        while (cursor != NULL) {
            if (cursor->ifa_addr->sa_family == AF_INET && (cursor->ifa_flags & IFF_LOOPBACK) == 0)
            {
                NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
                if ([name isEqualToString:@"en0"]){
                    freeifaddrs(addrs);
                    return [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)cursor->ifa_addr)->sin_addr)];
                }
            }
            cursor = cursor->ifa_next;
        }
        freeifaddrs(addrs);
    }
    return @"127.0.0.1";
}

- (NSString *)urlString{
    return [NSString stringWithFormat:@"http://%@:%d",[self IP], self.port];
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
