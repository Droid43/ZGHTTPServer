//
//  ZGHTTPConnectTask.m
//  SampleHttpService
//
//  Created by Zeng Gen on 08/06/2017.
//  Copyright © 2017 Zeng Gen. All rights reserved.
//

#import "ZGHTTPConnectTask.h"
#import "ZGHTTPResponseHandeler.h"
@interface ZGHTTPConnectTask()<GCDAsyncSocketDelegate>
@property (nonatomic, readonly) ZGHTTPConfig *config;
@property (nonatomic, readonly) GCDAsyncSocket *socket;
@property (nonatomic, copy) ZGHTTPTaskCompleteBlock completeBlock;
@property (nonatomic, strong) ZGHTTPRequestHandler *requestHandler;
@property (nonatomic, strong) ZGHTTPResponseHandeler *responseHandeler;
@end
@implementation ZGHTTPConnectTask
NSTimeInterval kZGHTTPConnectTimeout = 20;

long kZGHTTPResquestHeadTag = 100;
long kZGHTTPResquestBodyTag = 101;
long kZGHTTPResponseHeadTag = 102;
long kZGHTTPResPonseBodyTag = 103;


long kZGHTTPResquestErrorTag = 108;

+ (instancetype)initWithConfig:(ZGHTTPConfig *)config
                       socket:(GCDAsyncSocket *)socket
                     complete:(ZGHTTPTaskCompleteBlock) completeBlock{
    return [[self alloc] initWithConfig:config socket:socket complete:completeBlock];
}
- (instancetype)initWithConfig:(ZGHTTPConfig *)config
                       socket:(GCDAsyncSocket *)socket
                     complete:(ZGHTTPTaskCompleteBlock) completeBlock{
    if(self = [self init]){
        _config = config;
        _socket = socket;
        self.completeBlock = completeBlock;
        [_socket setDelegate:self delegateQueue:_config.taskQueue];
    }
    return self;
}


- (void)execute{
    [_socket  readDataToData:[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:kZGHTTPConnectTimeout tag:kZGHTTPResquestHeadTag];
}
- (void)checkRequsetFinish{
    if(![_requestHandler isRequestFinish]){
        [_socket readDataWithTimeout:kZGHTTPConnectTimeout tag:kZGHTTPResquestBodyTag];
    }else{
        self.responseHandeler = [ZGHTTPResponseHandeler initWithRequestHead:_requestHandler.requestHead
                                                                   delegate:_config.responseDelegate
                                                                    rootDir:_config.rootDirectory];
        
        [_socket writeData:[_responseHandeler readAllHeadData] withTimeout:kZGHTTPConnectTimeout tag:kZGHTTPResponseHeadTag];
    }

}


- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    if(tag == kZGHTTPResquestHeadTag){
        self.requestHandler = [ZGHTTPRequestHandler initWithHeadData:data delegate:_config.requestDelegate rootDir:_config.rootDirectory];
        NSError *error = [_requestHandler invalidError];
        if(error){
            self.responseHandeler = [ZGHTTPResponseHandeler initWithError:error requestHead:_requestHandler.requestHead];
            [_socket writeData:[_responseHandeler readAllHeadData] withTimeout:kZGHTTPConnectTimeout tag:kZGHTTPResquestErrorTag];
        }else{
            [self checkRequsetFinish];
        }
    }else if(tag == kZGHTTPResquestBodyTag){
        [_requestHandler writeBodyData:data];
        [self checkRequsetFinish];
    }

}

- (void)checkResponsetFinish{
    if([_responseHandeler bodyEnd]){
        if(![_responseHandeler shouldConnectKeepLive])
            [_socket disconnect];
    }else{
        NSData *data = [_responseHandeler readBodyData];
        [_socket writeData:data withTimeout:kZGHTTPConnectTimeout tag:kZGHTTPResPonseBodyTag];
        if([_responseHandeler bodyEnd])
            [_socket disconnectAfterWriting];
    }
}


- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    if(tag == kZGHTTPResquestErrorTag){
        [_socket disconnectAfterWriting];
    }else if(tag == kZGHTTPResponseHeadTag){
        [self checkResponsetFinish];
    }else if(tag == kZGHTTPResPonseBodyTag){
        [self checkResponsetFinish];
    }
    
}


- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    _responseHandeler = nil;
    _requestHandler = nil;
    if(_completeBlock) _completeBlock(self);

}
@end


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
@implementation ZGHTTPConfig (ZGHTTPPrivateAPI)

@end
#pragma clang diagnostic pop
