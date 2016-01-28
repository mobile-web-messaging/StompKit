//
//  SKSocket.h
//  StompKit
//
//  Created by Travis Bowers on 4/2/15.
//  Copyright (c) 2015 Jeff Mesnil. All rights reserved.
//

#ifndef StompKit_SKSocket_h
#define StompKit_SKSocket_h

#import "SKSocketUtility.h"

// forward declare
@class SKSocket;

// SKSocket delegate interface
@protocol SKSocketDelegate <NSObject>
@optional
- (void)socket:(SKSocket *)sock didReadDataWithData:(NSData *)data;
- (void)socket:(SKSocket *)sock didReadDataWithString:(NSString *)data;
- (void)socket:(SKSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength;
- (void)socket:(SKSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port;
- (void)socketDidDisconnect:(SKSocket *)sock withError:(NSError *)err;
@end



// SKSocket abstract interface
@protocol SKSocket <NSObject>
- (id)initWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)dq;
- (BOOL)connectToHost:(NSString*)host onPort:(uint16_t)port error:(NSError **)errPtr;
- (BOOL)isDisconnected;
- (void)writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout;
- (void)readDataToData:(NSData *)data withTimeout:(NSTimeInterval)timeout;
- (void)disconnectAfterReadingAndWriting;

@end

#endif
