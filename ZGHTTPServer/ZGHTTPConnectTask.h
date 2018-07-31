//
//  ZGHTTPConnectTask.h
//  SampleHttpService
//
//  Created by Zeng Gen on 08/06/2017.
//  Copyright © 2017 konka. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZGHTTPRequestHandler.h"
#import "ZGHTTPConfig.h"
#import "GCDAsyncSocket.h"

@class ZGHTTPConnectTask;
typedef void(^ZGHTTPTaskCompleteBlock)(ZGHTTPConnectTask *task);

@interface ZGHTTPConnectTask : NSObject
+(instancetype)initWithConfig:(ZGHTTPConfig *)config
                       socket:(GCDAsyncSocket *)socket
                     complete:(ZGHTTPTaskCompleteBlock) completeBlock;

-(instancetype)initWithConfig:(ZGHTTPConfig *)config
                       socket:(GCDAsyncSocket *)socket
                     complete:(ZGHTTPTaskCompleteBlock) completeBlock;

-(void)execute;
@end

@interface ZGHTTPConfig (ZGHTTPPrivateAPI)
@property (nonatomic, strong) dispatch_queue_t taskQueue;
@end
