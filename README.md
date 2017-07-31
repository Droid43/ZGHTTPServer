# ZGHTTPServer

使用Objective-C实现的iOS HTTP 服务器

**注意**：TCP通信基于CocoaAsyncSocket实现

### 效果图

![](http://onj3jyfip.bkt.clouddn.com/blog/zghttpserver/img/httpserver.gif)



## 使用示例

```objective-c
    self.httpServer = [[ZGHTTPServer alloc] initWithConfig:^(ZGHTTPConfig *config) {
        config.port = 12345;
        config.rootDirectory = NSHomeDirectory();
    }];
    NSError *error = [self.httpServer start];
```

