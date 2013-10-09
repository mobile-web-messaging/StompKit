//
//  StompKit.h
//  StompKit
//
//  Created by Jeff Mesnil on 09/10/2013.
//  Copyright (c) 2013 Jeff Mesnil. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

#pragma mark Frame headers

#define kHeaderAcceptVersion @"accept-version"
#define kHeaderAck           @"ack"
#define kHeaderContentLength @"content-length"
#define kHeaderDestination   @"destination"
#define kHeaderID            @"id"
#define kHeaderLogin         @"login"
#define kHeaderMessage       @"message"
#define kHeaderPasscode      @"passcode"
#define kHeaderReceipt       @"receipt"
#define kHeaderReceiptID     @"receipt-id"
#define kHeaderSession       @"session"
#define kHeaderSubscription  @"subscription"
#define kHeaderTransaction   @"transaction"

#pragma mark Ack Header Values

#define kAckAuto             @"auto"
#define kAckClient           @"client"
#define kAckClientIndividual @"client-individual"

@class STOMPFrame;
@class STOMPMessage;

typedef void (^STOMPMessageHandler)(STOMPMessage *message);
typedef void (^STOMPFrameHandler)(STOMPFrame *frame);

#pragma mark STOMP Frame

@interface STOMPFrame : NSObject

@property (nonatomic, copy, readonly) NSString *command;
@property (nonatomic, copy, readonly) NSDictionary *headers;
@property (nonatomic, copy, readonly) NSString *body;

@end

#pragma mark STOMP Message

@interface STOMPMessage : STOMPFrame

- (void)ack;
- (void)ack:(NSDictionary *)theHeaders;
- (void)nack;
- (void)nack:(NSDictionary *)theHeaders;

@end

#pragma mark STOMP Subscription

@interface STOMPSubscription : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;

- (void)unsubscribe;

@end

#pragma mark STOMP Transaction

@interface STOMPTransaction : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;

- (void)commit;
- (void)abort;

@end

#pragma mark STOMP Client

@interface STOMPClient : NSObject

@property (nonatomic, copy) STOMPFrameHandler receiptHandler;

- (id)initWithHost:(NSString *)theHost
			  port:(NSUInteger)thePort;

- (void)connectWithLogin:(NSString *)login
                passcode:(NSString *)passcode
              completion:(STOMPFrameHandler)handler;
- (void)connectWithHeaders:(NSDictionary *)headers
                completion:(STOMPFrameHandler)handler;

- (void)sendTo:(NSString *)destination
          body:(NSString *)body;
- (void)sendTo:(NSString *)destination
       headers:(NSDictionary *)headers
          body:(NSString *)body;

- (STOMPSubscription *)subscribeTo:(NSString *)destination
                           handler:(STOMPMessageHandler)handler;
- (STOMPSubscription *)subscribeTo:(NSString *)destination
                           headers:(NSDictionary *)headers
                           handler:(STOMPMessageHandler)handler;

- (STOMPTransaction *)begin;
- (STOMPTransaction *)begin:(NSString *)identifier;

- (void)disconnect;
- (void)disconnect:(void (^)(void))handler;

@end