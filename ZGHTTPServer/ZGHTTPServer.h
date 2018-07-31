//
//  ZGHTTPServer.h
//  SampleHttpService
//
//  Created by Zeng Gen on 08/06/2017.
//  Copyright © 2017 Zeng Gen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZGHTTPConfig.h"

@interface ZGHTTPServer : NSObject
@property (nonatomic, readonly) ZGHTTPConfig *config;

+ (instancetype)initWithConfig:(void(^)(ZGHTTPConfig *config)) configBlock;
- (instancetype)initWithConfig:(void(^)(ZGHTTPConfig *config)) configBlock;

- (NSError *)start;
- (void)stop;
- (uint16_t)port;
- (void)setPort:(uint16_t) port;
- (NSString *)IP;
- (NSString *)urlString;
@end

