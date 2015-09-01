StompKit
========

[![Build Status](https://travis-ci.org/mobile-web-messaging/StompKit.png?branch=master)](https://travis-ci.org/mobile-web-messaging/StompKit)

STOMP Objective-C Client for iOS

StompKit is a rewrite of [objc-stomp](https://github.com/juretta/objc-stomp) to create a modern event-driven Objective-C library using ARC, Grand Central Dispatch and blocks.

This library uses the Grand Central Dispatch version of [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket).

# Installation

## Using CocoaPods

StompKit is available on [CocoaPods](http://cocoapods.org/?q=StompKit).


On your ```Podfile``` add this project:

```
...
pod 'StompKit', :git => 'https://github.com/mobile-web-messaging/StompKit.git'
...
```

For the first time, run ```pod install```, if you are updating the project invoke ```pod update```.

# Usage

Import the `StompKit.h` header file

```objc
#import <StompKit.h>
```

Send a message:

```objc
// create the client
STOMPClient *client = [[STOMPClient alloc] initWithHost:@"localhost"
                                                   port:61613];
// connect to the broker
[client connectWithLogin:@"mylogin"
                passcode:@"mypassword"
       completionHandler:^(STOMPFrame *_, NSError *error) {
            if (error) {
                NSLog(@"%@", error);
                return;
            }

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
       completionHandler:^(STOMPFrame *_, NSError *error) {
            if (error) {
                NSLog(@"%@", error);
                return;
            }

            // subscribe to the destination
            [client subscribeTo:@"/queue/myqueue"
                        headers:@{@"selector": @"color = 'red'"}
                 messageHandler:^(STOMPMessage *message) {
                    // callback when the client receive a message
                    // for the /queue/myqueue destination

                    NSLog(@"got message %@", message.body); // => "Hello, iOS"
                }];
            }];
```

# Authors

* [Jeff Mesnil](http://jmesnil.net/)

