//
//  ZGHTTPResponseHandeler.m
//  SampleHttpService
//
//  Created by Zeng Gen on 08/06/2017.
//  Copyright © 2017 Zeng Gen. All rights reserved.
//

#import "ZGHTTPResponseHandeler.h"

@interface ZGHTTPHTMLDirectory : NSObject
@property (nonatomic, readonly) NSData *htmlData;
- (instancetype)initWithResources:(NSArray<ZGHTTPResourceInfo *> *)infos
                            dirName:(NSString *)name;
@end

@implementation ZGHTTPHTMLDirectory

+ (instancetype)initWithResources:(NSArray<ZGHTTPResourceInfo *> *)infos
                         dirName:(NSString *)name{
    return [[self alloc] initWithResources:infos dirName:name];
}
- (instancetype)initWithResources:(NSArray<ZGHTTPResourceInfo *> *)infos
                         dirName:(NSString *)name{
    if(self = [self init]){
        NSMutableString *htmlStr = @"<html>".mutableCopy;
        NSString *style = [NSString stringWithContentsOfFile:
                           [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"headstyle"]
                                                    encoding:NSUTF8StringEncoding
                                                    error:nil];
        [htmlStr appendFormat:@"<head>"
                                "<title>%@</title>"
                                "<style>th {text-align: left;}</style>"
                                "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />"
                                 "%@"
                                "</head>",name, style];
        [htmlStr appendFormat:@"<body>"
                                "<h1>当前路径：%@</h1>",name];
        
        [htmlStr appendString:@"<table cellpadding=\"0\">"
                                 "<tr>"
                                     "<th>文件名</th>"
                                     "<th>修改日期</th>"
                                     "<th>文件大小</th>"
                                 "</tr>"];
        [htmlStr appendString:@"<tr>"
                                 "<td><a href=\"./..\">上一级</a></td>"
                                 "<td>&nbsp;-</td>"
                                 "<td>&nbsp;&nbsp;-</td>"
                             "</tr>"];
        [infos enumerateObjectsUsingBlock:^(ZGHTTPResourceInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *url = obj.relativeUrl, *size = obj.size;
            if(obj.isDirectory){
                url = [obj.relativeUrl stringByAppendingString:@"/"];
                size = @"[DIR]";
            }
            [htmlStr appendFormat:@"<tr>"
             "<td><a href=\"%@\">%@</a></td>"
             "<td>&nbsp;09-Jun-2017 12:37</td>"
             "<td>&nbsp;&nbsp;%@</td>"
             "</tr>",url, obj.name, size];

        }];
        
        
        [htmlStr appendString:@"</table>"
                             "</pre>"
                         "</body>"
                     "</html>"];
            
        _htmlData = [htmlStr dataUsingEncoding:NSUTF8StringEncoding];
    }
    return self;
}

@end


@interface ZGHTTPResponseHandeler ()
@property(nonatomic, weak) id<ZGHTTPResponseDelegate> delegate;
@property(nonatomic, copy) NSString *rootDir;
@property(nonatomic, copy) NSString *filePath;
@property(nonatomic, copy) NSString *queryStr;
@property(nonatomic, strong) NSData *data;
@property(nonatomic, assign) BOOL delegateEnabled;
@property(nonatomic, strong) NSFileHandle *fileOutput;
@end

@implementation ZGHTTPResponseHandeler

NSUInteger const kZGHTTPDataReadMax = 256 * 1024;


+ (instancetype)initWithError:(NSError *)error requestHead:(ZGHTTPRequestHead *)head{
    return [[self alloc] initWithError:error requestHead:head];
}
+ (instancetype)initWithRequestHead:(ZGHTTPRequestHead *)head
                          delegate:(id<ZGHTTPResponseDelegate>) delegate
                           rootDir:(NSString *)dir{
    return [[self alloc] initWithRequestHead:head delegate:delegate rootDir:dir];
}

- (instancetype)initWithError:(NSError *)error requestHead:(ZGHTTPRequestHead *)head{
    if(self = [self init]){
        _requestHead = head;
        _error = error;
        _responseHead = [ZGHTTPResponseHead initWithError:error requestHead:head];
    }
    return self;
}

- (instancetype)initWithRequestHead:(ZGHTTPRequestHead *)head
                          delegate:(id<ZGHTTPResponseDelegate>) delegate
                           rootDir:(NSString *)dir{
    _requestHead = head;
    _responseHead = [ZGHTTPResponseHead initWithRequestHead:head];
    _rootDir = [dir copy];
    _delegate = delegate;
    if(_delegateEnabled && [_delegate respondsToSelector:@selector(startLoadResource:)]) [_delegate startLoadResource:_requestHead];
    if([self delegateCheck]){
        [self loadData];
        if(![self redirectUrl]) [self loadBodyData];
    }else{
        _responseHead.stateCode = 404;
        _responseHead.stateDesc =  [@"服务器非法操作❌" stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    return self;
}

- (void)loadData{
    NSRange range = [_requestHead.path rangeOfString:@"?"];
    if(range.location == NSNotFound){
        self.filePath = [_rootDir stringByAppendingString:_requestHead.path];
    }else{
        self.filePath = [_rootDir stringByAppendingString:[_requestHead.path substringToIndex:range.location]];
        self.queryStr = [_requestHead.path substringFromIndex:range.location + range.length];
    }
    NSString *redirectUrl = [self redirectUrl];
    if(redirectUrl){
        [_responseHead setHeadValue:redirectUrl WithField:@"Location"];
        _responseHead.stateCode = 303;
        return;
    }
}

- (void)loadBodyData{
    BOOL isResourceExist = YES;
    if(_delegateEnabled){
        isResourceExist = [_delegate respondsToSelector:@selector(isResourceExist:)] && ![_delegate isResourceExist:_requestHead];
    }else{
        isResourceExist = [[NSFileManager defaultManager] fileExistsAtPath:_filePath];
    }
    if(!isResourceExist){
        _responseHead.stateCode = 404;
        _responseHead.stateDesc =  [@"访问资源不存在❌" stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        return;
    }
    if([self isDir]) [self loadDir];
    else [self loadFileData];
    if([self bodyEnd]) return;
}

- (void)loadFileData{
    if(_delegateEnabled && [_delegate respondsToSelector:@selector(resourceLength:)]) _bodyDataLength = [_delegate resourceLength:_requestHead];
    else{
        BOOL isDir;
        BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:_filePath isDirectory:&isDir];
        if(!isDir && isExist){
            self.fileOutput = [NSFileHandle fileHandleForReadingAtPath:_filePath];
            _bodyDataLength = [_fileOutput seekToEndOfFile];
        }
    }
}

- (void)loadDir{
    NSMutableArray *array = @[].mutableCopy;
    for (NSString *path in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_filePath error:nil]) {
        ZGHTTPResourceInfo *info = [ZGHTTPResourceInfo new];
        NSError *error;
        NSDictionary<NSFileAttributeKey, id> *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[_filePath stringByAppendingPathComponent:path] error:&error];
        info.isDirectory = [fileAttributes.fileType isEqualToString:NSFileTypeDirectory];
        u_int64_t length = fileAttributes.fileSize;
        if(length < 1024){
            info.size = [NSString stringWithFormat:@"%llu",length];
        }else if(length < 1024*1024){
            info.size = [NSString stringWithFormat:@"%lluK",length/1024];
        }else if(length < 1024*1024*1024){
            info.size = [NSString stringWithFormat:@"%lluM",length/(1024*1024)];
        }else{
            info.size = [NSString stringWithFormat:@"%lluG",length/(1024*1024/1024)];
        }
        
        info.name = [path lastPathComponent];
        info.modifyTime = [fileAttributes objectForKey:NSFileModificationDate];
        info.relativeUrl = [path stringByReplacingOccurrencesOfString:_rootDir withString:@""];
        [array addObject:info];
    }
    _data = [ZGHTTPHTMLDirectory initWithResources:array dirName:_requestHead.path].htmlData;
    _bodyDataLength = _data.length;
    _bodyDataOffset = 0;
    [_responseHead setHeadValue:@"close" WithField:@"Connection"];
    [_responseHead setHeadValue:@"text/html; charset=utf-8" WithField:@"Content-Type"];
}

- (BOOL)delegateCheck{
    if([_delegate respondsToSelector:@selector(shouldUsedDelegate:)]) self.delegateEnabled = [_delegate shouldUsedDelegate:_requestHead];
    BOOL resourcePathD = [_delegate respondsToSelector:@selector(resourceRelativePath:)];
    BOOL isDirD = [_delegate respondsToSelector:@selector(isDirectory:)];
    BOOL isExistD = [_delegate respondsToSelector:@selector(isResourceExist:)];
    BOOL dirItemInfoD = [_delegate respondsToSelector:@selector(dirItemInfoList:)];
    BOOL resourceLengthD = [_delegate respondsToSelector:@selector(resourceLength:)];
    BOOL readResourceD = [_delegate respondsToSelector:@selector(readResource:atOffset:length:head:)];
    
    BOOL delegateLegal = (resourcePathD || isDirD || isExistD || dirItemInfoD || resourceLengthD || readResourceD)
        == (resourcePathD && isDirD && isExistD && dirItemInfoD && resourceLengthD && readResourceD);
    
    if(!_delegateEnabled) return YES;
    if(delegateLegal) return YES;
    return NO;
}

- (BOOL)isDir{
    if(_delegateEnabled && [_delegate respondsToSelector:@selector(isDirectory:)]) return [_delegate isDirectory:_requestHead];
    if([[_filePath substringFromIndex:_filePath.length - 1] isEqualToString:@"/"]) return YES;
    return NO;
}

- (NSString *)redirectUrl{
    if(_delegateEnabled&&[_delegate respondsToSelector:@selector(redirect:)]) return [_delegate redirect:_requestHead];
    if(![self isDir] && ![_delegate respondsToSelector:@selector(isDirectory:)]){
        BOOL isDir;
        [[NSFileManager defaultManager] fileExistsAtPath:_filePath isDirectory:&isDir];
        NSString *path =[_requestHead.host stringByAppendingPathComponent:_requestHead.path];
        if(isDir) return [NSString stringWithFormat:@"http://%@/",path];
    }
    return nil;
}

- (BOOL)shouldConnectKeepLive{
    if(_error) return NO;
    if([self bodyEnd]) return NO;
    return [[_requestHead.headDic objectForKey:@"Connection"] isEqualToString:@"keep-alive"];
}
- (BOOL)bodyEnd{
    if(_error) return YES;
    return _bodyDataLength < _bodyDataOffset + 1;
}
- (NSData *) readAllHeadData{
    return [_responseHead dataOfHead];
}
- (NSData *) readBodyData{
    NSData *data;
    if([self isDir]){
        _bodyDataOffset = _data.length;
        data = _data;
    }else{
        NSUInteger length = kZGHTTPDataReadMax;
        if(_bodyDataOffset > _bodyDataLength) return nil;
        if(_bodyDataOffset + kZGHTTPDataReadMax >= _bodyDataLength) length = _bodyDataLength - _bodyDataOffset;
        
        if(_delegateEnabled && [_delegate respondsToSelector:@selector(readResource:atOffset:length:head:)]){
            data = [_delegate readResource:_filePath atOffset:_bodyDataOffset length:length head:_requestHead];
            _bodyDataOffset += length;
            if([self bodyEnd]){
                if([_delegate respondsToSelector:@selector(finishLoadResource:)]) [_delegate finishLoadResource:_requestHead];
            }
        }else{
            [_fileOutput seekToFileOffset:_bodyDataOffset];
            data = [_fileOutput readDataOfLength:length];
            _bodyDataOffset += length;
            if([self bodyEnd]) [_fileOutput closeFile];
        }
    }
    return data;
}
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation ZGHTTPResponseHead(ZGHTTPPrivateAPI)
+ (instancetype)initWithRequestHead:(ZGHTTPRequestHead *)head{
    return [[self alloc] initWithRequestHead:head];
}
+ (instancetype)initWithError:(NSError *)error requestHead:(ZGHTTPRequestHead *)head{
    return [[self alloc] initWithError:error requestHead:head];
}
- (instancetype)initWithError:(NSError *)error requestHead:(ZGHTTPRequestHead *)head{
    if(self = [self initWithRequestHead:head]){
        self.stateCode = error.code;
        self.stateDesc =  [error.domain stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if(error) [self setHeadValue:@"close" WithField:@"Connection"];
    }
    return self;
}

- (instancetype)initWithRequestHead:(ZGHTTPRequestHead *)head{
    if(self = [self init]){
        NSDate *date = [NSDate date];
        NSString *dataStr = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterFullStyle];
        NSDictionary *dic = @{
                              @"Date"   : dataStr,
                              @"Server" : @"ZGHTTPServer"
                              };
        self.headDic = dic;
        self.protocol = head.protocol;
        self.version = head.version;
        self.stateCode = 200;
        self.stateDesc = @"OK";
    }
    return self;
}

- (void)setHeadValue:(NSString *)value WithField:(NSString *)field{
    if(value == nil || field == nil)return;
    NSMutableDictionary *dic = self.headDic.mutableCopy;
    [dic setObject:value forKey:field];
    self.headDic = dic;
}

- (NSData *)dataOfHead{
    NSMutableString *headStr = @"".mutableCopy;
    [headStr appendFormat:@"%@/%@ %zd %@\r\n",self.protocol,self.version, self.stateCode, self.stateDesc];
    [self.headDic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [headStr appendFormat:@"%@:%@\r\n",key,obj];
    }];
    [headStr appendString:@"\r\n"];
    return [headStr dataUsingEncoding:NSUTF8StringEncoding];
}
@end
#pragma clang diagnostic pop
