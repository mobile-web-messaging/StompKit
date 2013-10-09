StompKit
========

STOMP Objective-C Client for iOS

StompKit is a rewrite of [objc-stomp](https://github.com/juretta/objc-stomp) to create a modern event-driven Objective-C library using ARC, Grand Central Dispatch and blocks.

This library uses the Grand Central Dispatch version of [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket).

# Installation

Add GCDAsynSocket.{h,m} and StompKit.{h,m} to your project.

# Usage

Import the `StompKit.h` header file

```objc
#import "StompKit.h"
```

Send a message:

```objc
// create the client
STOMPClient *client = [[STOMPClient alloc] initWithHost:@"localhost"
                                                   port:61613];
// connect to the broker
[client connectWithLogin:@"mylogin"
                passcode:@"mypassword"
              completion:^(STOMPFrame *_) {
                    // callback when the client is connected successfully

                    // send a message
                    [client sendTo:@"/queue/myqueue" body:@"Hello, iOS!"];
                    // and disconnect
                    [client disconnect];
                }];
```

Subscribe to receive message:

```objc
// create the client
STOMPClient *client = [[STOMPClient alloc] initWithHost:@"localhost"
                                                   port:61613];
// connect to the broker
[client connectWithLogin:@"mylogin"
                passcode:@"mypassword"
              completion:^(STOMPFrame *_) {
                // callback when the client is connected successfully

                // subscribe to the destination
                [client subscribeTo:@"/queue/myqueue"
                            headers:@{@"selector": @"color = 'red'"}
                            handler:^(STOMPMessage *message) {
                                NSLog(@"got message %@", message.body);
                            }];
               }];
```


# Missing features:

* protocol negotiation
* heart-beating

# Authors

* [Jeff Mesnil](http://jmesnil.net/)

