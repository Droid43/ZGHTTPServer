//
//  ZGHTTPConfig.m
//  SampleHttpService
//
//  Created by Zeng Gen on 08/06/2017.
//  Copyright © 2017 Zeng Gen. All rights reserved.
//

#import "ZGHTTPConfig.h"

@implementation ZGHTTPRequestHead
- (void)setMethod:(NSString *)method{
    _method = [method copy];
}
- (void)setPath:(NSString *)path{
    _path = [path copy];
}
- (void)setProtocol:(NSString *)protocol{
    _protocol = [protocol copy];
}
- (void)setVersion:(NSString *)version{
    _version = [version copy];
}
- (void)setHost:(NSString *)host{
    _host = [host copy];
}
- (void)setHeadDic:(NSDictionary *)headDic{
    _headDic = [headDic copy];
}
@end
@implementation ZGHTTPResponseHead

- (void)setProtocol:(NSString *)protocol{
    _protocol = [protocol copy];
}
- (void)setVersion:(NSString *)version{
    _version = [version copy];
}
- (void)setStateCode:(NSInteger)stateCode{
    _stateCode = stateCode;
}
- (void)setStateDesc:(NSString *)stateDesc{
    _stateDesc = [stateDesc copy];
}
- (void)setHeadDic:(NSDictionary *)headDic{
    _headDic = [headDic copy];
}
@end
@implementation ZGHTTPResourceInfo
@end

@interface ZGHTTPConfig ()
@property (nonatomic, strong) dispatch_queue_t taskQueue;
@end


@implementation ZGHTTPConfig
@end


