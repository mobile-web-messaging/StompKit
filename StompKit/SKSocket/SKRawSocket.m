//
//  SKRawSocket.m
//  StompKit
//
//  Created by Travis Bowers on 4/2/15.
//  Copyright (c) 2015 Jeff Mesnil. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SKRawSocket.h"
#import "GCDAsyncSocket.h"

@interface SKRawSocket()
@property (nonatomic, weak) id <SKSocketDelegate> delegate;
@property (nonatomic, retain) GCDAsyncSocket *socket;
@end

@implementation SKRawSocket

// synthesize properties
@synthesize delegate;
@synthesize socket;

- (id)initWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)dq {
    if((self = [super init])) {
        if (aDelegate != nil) {
            self.delegate = aDelegate;
            
            // initialize our socket
            self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dq];
        }
    }
    
    return self;
}

- (BOOL)connectToHost:(NSString*)host onPort:(uint16_t)port error:(NSError **)errPtr {
    return [socket connectToHost:host onPort:port error:errPtr];
}

- (BOOL)isDisconnected {
    return [socket isDisconnected];
}

- (void)writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag {
    [socket writeData:data withTimeout:timeout tag:tag];
}

- (void)readDataToData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag {
    [socket readDataToData:data withTimeout:timeout tag:tag];

}

- (void)disconnectAfterReadingAndWriting {
    [socket disconnectAfterReadingAndWriting];
}

#pragma mark -
#pragma mark GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if (self.delegate != nil) {
        [delegate socket:(SKSocket*)self didReadData:data withTag:tag];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    if (self.delegate != nil) {
        [delegate socket:(SKSocket*)self didReadPartialDataOfLength:partialLength tag:tag];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    if (self.delegate != nil) {
        [delegate socket:(SKSocket*)self didConnectToHost:host port:port];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (self.delegate != nil) {
        [delegate socketDidDisconnect:(SKSocket*)self withError:err];
    }
}

@end
