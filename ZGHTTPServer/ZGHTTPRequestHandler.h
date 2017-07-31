//
//  ZGHTTPRequestHandler.h
//  SampleHttpService
//
//  Created by Zeng Gen on 08/06/2017.
//  Copyright © 2017 Zeng Gen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZGHTTPConfig.h"

@interface ZGHTTPRequestHandler : NSObject
@property(nonatomic, readonly) ZGHTTPRequestHead *requestHead;
@property(nonatomic, readonly) u_int64_t bodyDataLength;
@property(nonatomic, readonly) u_int64_t bodyDataOffset;


+ (instancetype)initWithHeadData:(NSData *)data
                       delegate:(id<ZGHTTPRequestDelegate>) delegate
                        rootDir:(NSString *)dir;
- (instancetype)initWithHeadData:(NSData *)data
                       delegate:(id<ZGHTTPRequestDelegate>) delegate
                        rootDir:(NSString *)dir;
//- (NSError *)refuseError;
- (NSError *)invalidError;
- (BOOL)isRequestFinish;
- (void)writeBodyData:(NSData *)data;
- (void)writeBodyDataError:(NSError *)error;
@end


@interface ZGHTTPRequestHead (ZGHTTPPrivateAPI)
+ (instancetype)initWithData:(NSData *) data;
- (instancetype)initWithData:(NSData *) data;
- (void)setMethod:(NSString *)method;
- (void)setPath:(NSString *)path;
- (void)setProtocol:(NSString *)protocol;
- (void)setVersion:(NSString *)version;
- (void)setHost:(NSString *)host;
- (void)setHeadDic:(NSDictionary *)headDic;
@end
