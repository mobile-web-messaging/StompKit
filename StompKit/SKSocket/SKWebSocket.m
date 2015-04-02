//
//  SKWebSocket.m
//  StompKit
//
//  Created by Travis Bowers on 4/2/15.
//  Copyright (c) 2015 Jeff Mesnil. All rights reserved.
//

#import "SKWebSocket.h"
#import "GCDAsyncSocket.h"
#import "SRWebSocket.h"

NSString *const SKWebSocketErrorDomain = @"SKWebSocketErrorDomain";

@interface SKWebSocket() <SRWebSocketDelegate>
@property (nonatomic, weak) id <SKSocketDelegate> delegate;
@property (nonatomic, retain) SRWebSocket *socket;
@property (nonatomic, assign) BOOL connected;
@end

@implementation SKWebSocket

// synthesize properties
@synthesize delegate;
@synthesize socket;

- (id)initWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)dq {
    if((self = [super init])) {
        if (aDelegate != nil) {
            self.delegate = aDelegate;
            self.connected = NO;
        }
    }
    
    return self;
}

- (BOOL)connectToHost:(NSString*)host onPort:(uint16_t)port error:(NSError **)errPtr {
    self.socket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:host]];
    self.socket.delegate = self;
    [self.socket open];
    return YES;
}

- (BOOL)isDisconnected {
    return !self.connected;
}

- (void)writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout {
    [socket send:data];
}

- (void)readDataToData:(NSData *)data withTimeout:(NSTimeInterval)timeout {
    // not supported
    //[socket readDataToData:data withTimeout:timeout tag:tag];
}

- (void)disconnectAfterReadingAndWriting {
    // not supported
    //[socket disconnectAfterReadingAndWriting];
}

#pragma mark -
#pragma mark SRWebSocketDelegate
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    [delegate socket:(SKSocket*)self didReadData:message];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    self.connected = YES;
    [delegate socket:(SKSocket*)self didConnectToHost:self.socket.url.absoluteString port:80];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    self.connected = NO;
    [delegate socketDidDisconnect:(SKSocket*)self withError:error];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    self.connected = NO;
    
    NSError *error = nil;
    
    if (wasClean == NO) {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Socket did close",
                                   NSLocalizedFailureReasonErrorKey: reason
                                   };
        error = [NSError errorWithDomain:SKWebSocketErrorDomain code:-57 userInfo:userInfo];
    }
    
    [delegate socketDidDisconnect:(SKSocket*)self withError:error];
}

@end
