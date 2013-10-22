//
//  StompKitTests.m
//  StompKitTests
//
//  Created by Jeff Mesnil on 09/10/2013.
//  Copyright (c) 2013 Jeff Mesnil. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "StompKit.h"
#import "StompKitTests.h"

// These integration tests expects that a STOMP broker is running
// and listening on localhost:61613
// The credentials are user / password
// and the tests uses the destinations: "/queue/myqueue" "/queue/myqueue_2"
// All these configuration variables are defined in StompKitTests.h

@interface StompKitTests : XCTestCase

@property (nonatomic, retain) STOMPClient *client;
@end

@implementation StompKitTests

@synthesize client;

- (void)setUp
{
    [super setUp];

    self.client = [[STOMPClient alloc] initWithHost:HOST
                                               port:PORT];
}

- (void)tearDown
{
    [self.client disconnect];
    [super tearDown];
}

- (void)testInvalidServerInfo {

    dispatch_semaphore_t errorReceived = dispatch_semaphore_create(0);

    STOMPClient *otherClient = [[STOMPClient alloc] initWithHost:@"invalid host" port:61613];
    [otherClient connectWithLogin:LOGIN
                         passcode:PASSCODE
                completionHandler:^(STOMPFrame *connectedFrame, NSError *error) {
                    if (error) {
                        NSLog(@"got error: %@", error);
                        dispatch_semaphore_signal(errorReceived);
                    }
                }];
    XCTAssertTrue(gotSignal(errorReceived, 2));
}

- (void)testConnect {
    dispatch_semaphore_t connected = dispatch_semaphore_create(0);

    [self.client connectWithLogin:LOGIN
                         passcode:PASSCODE
                completionHandler:^(STOMPFrame *connectedFrame, NSError *error) {
                    if (!error) {
                        dispatch_semaphore_signal(connected);
                    }
                }];
    XCTAssertTrue(gotSignal(connected, 2), @"can not connect to %@:%d with credentials %@ / %@", HOST, PORT, LOGIN, PASSCODE);
}

- (void)testConnectWithError {
    dispatch_semaphore_t errorReceived = dispatch_semaphore_create(0);

    [self.client connectWithLogin:@"not a valid login"
                         passcode:PASSCODE
                completionHandler:^(STOMPFrame *connectedFrame, NSError *error) {
                    if (error) {
                        NSLog(@"got error: %@", error);
                        dispatch_semaphore_signal(errorReceived);
                    }
                }];
    XCTAssertTrue(gotSignal(errorReceived, 2));
}

- (void)testDisconnect
{
    dispatch_semaphore_t disconnected = dispatch_semaphore_create(0);

    [self.client connectWithLogin:LOGIN
                         passcode:PASSCODE
                completionHandler:^(STOMPFrame *connectedFrame, NSError *error) {
                    [self.client disconnect:^(NSError *error) {
                        dispatch_semaphore_signal(disconnected);
                    }];
                }];
    XCTAssertTrue(gotSignal(disconnected, 2));
}

- (void)testSingleSubscription
{
    dispatch_semaphore_t messageReceived = dispatch_semaphore_create(0);

    NSString *msg = @"testSingleSubscription";
    __block NSString *reply;

    [self.client connectWithLogin:LOGIN
                         passcode:PASSCODE
                completionHandler:^(STOMPFrame *_, NSError *error) {
                           [self.client subscribeTo:QUEUE_DEST
                                     messageHandler:^(STOMPMessage *message) {
                                         reply = message.body;
                                         dispatch_semaphore_signal(messageReceived);
                                     }];
                           [self.client sendTo:QUEUE_DEST
                                          body:msg];
                       }];

    XCTAssertTrue(gotSignal(messageReceived, 2), @"did not receive signal");
    XCTAssert([msg isEqualToString:reply], @"did not receive expected message ");
}

- (void)testMultipleSubscription
{
    dispatch_semaphore_t messageReceivedFromSub1 = dispatch_semaphore_create(0);
    dispatch_semaphore_t messageReceivedFromSub2 = dispatch_semaphore_create(0);

    STOMPMessageHandler handler1 = ^void (STOMPMessage *message) {
        dispatch_semaphore_signal(messageReceivedFromSub1);
    };
    STOMPMessageHandler handler2 = ^void (STOMPMessage *message) {
        dispatch_semaphore_signal(messageReceivedFromSub2);
    };
    [self.client connectWithLogin:LOGIN
                         passcode:PASSCODE
                completionHandler:^(STOMPFrame *connectedFrame, NSError *error) {
                    [self.client subscribeTo:QUEUE_DEST messageHandler:handler1];
                    [self.client subscribeTo:QUEUE_DEST_2 messageHandler:handler2];

                    [self.client sendTo:QUEUE_DEST body:@"testMultipleSubscription #1"];
                    [self.client sendTo:QUEUE_DEST_2 body:@"testMultipleSubscription #2"];
                }];

    XCTAssertTrue(gotSignal(messageReceivedFromSub1, 2), @"did not receive signal");
    XCTAssertTrue(gotSignal(messageReceivedFromSub2, 2), @"did not receive signal");
}

- (void)testUnsubscribe
{
    dispatch_semaphore_t messageReceived = dispatch_semaphore_create(0);
    dispatch_semaphore_t subscribed = dispatch_semaphore_create(0);

    __block STOMPSubscription *subscription;

    [self.client connectWithLogin:LOGIN
                         passcode:PASSCODE
                completionHandler:^(STOMPFrame *connectedFrame, NSError *error) {
                    subscription = [self.client subscribeTo:QUEUE_DEST
                                             messageHandler:^(STOMPMessage *message) {
                                                 dispatch_semaphore_signal(messageReceived);
                                             }];
                    dispatch_semaphore_signal(subscribed);
                }];

    XCTAssertTrue(gotSignal(subscribed, 2));

    [subscription unsubscribe];

    [self.client sendTo:QUEUE_DEST body:@"testUnsubscribe"];

    XCTAssertFalse(gotSignal(messageReceived, 2));

    // resubscribe to consume the message and leave the queue empty:
    [self.client subscribeTo:QUEUE_DEST messageHandler:^(STOMPMessage *message) {
        dispatch_semaphore_signal(messageReceived);
    }];

    XCTAssertTrue(gotSignal(messageReceived, 2));
}

- (void)testAck {
    dispatch_semaphore_t receiptForAckReceived = dispatch_semaphore_create(0);

    NSString *receiptID = @"receipt-for-ack";

    self.client.receiptHandler = ^(STOMPFrame *frame) {
        if ([frame.headers[kHeaderReceiptID] isEqualToString:receiptID]) {
            dispatch_semaphore_signal(receiptForAckReceived);
        }
    };

    [self.client connectWithLogin:LOGIN
                         passcode:PASSCODE
                completionHandler:^(STOMPFrame *connectedFrame, NSError *error) {
                    [self.client subscribeTo:QUEUE_DEST
                                     headers: @{kHeaderAck:kAckClient}
                              messageHandler:^(STOMPMessage *message) {
                                  [message ack:@{kHeaderReceipt: receiptID}];
                              }];
                    [self.client sendTo:QUEUE_DEST body:@"testAck"];
                }];

    XCTAssertTrue(gotSignal(receiptForAckReceived, 2));
}

- (void)testNack {
    dispatch_semaphore_t receiptForNackReceived = dispatch_semaphore_create(0);

    NSString *receiptID = @"receipt-for-nack";
    self.client.receiptHandler = ^(STOMPFrame *frame) {
        if ([frame.headers[kHeaderReceiptID] isEqualToString:receiptID]) {
            dispatch_semaphore_signal(receiptForNackReceived);
        }
    };

    [self.client connectWithLogin:LOGIN
                         passcode:PASSCODE
                completionHandler:^(STOMPFrame *connectedFrame, NSError *error) {
                    [self.client subscribeTo:QUEUE_DEST
                                     headers: @{kHeaderAck: kAckClient}
                              messageHandler:^(STOMPMessage *message) {
                                  [message nack:@{kHeaderReceipt: receiptID}];
                              }];
                    [self.client sendTo:QUEUE_DEST body:@"testNack"];
                }];

    XCTAssertTrue(gotSignal(receiptForNackReceived, 2));
}

- (void)testCommitTransaction {
    dispatch_semaphore_t messageReceived = dispatch_semaphore_create(0);

    __block STOMPTransaction *transaction;

    [self.client connectWithLogin:LOGIN
                         passcode:PASSCODE
                completionHandler:^(STOMPFrame *connectedFrame, NSError *error) {
                        [self.client subscribeTo:QUEUE_DEST
                                  messageHandler:^(STOMPMessage *message) {
                                      dispatch_semaphore_signal(messageReceived);
                                  }];
                    transaction = [self.client begin];
                    [self.client sendTo:QUEUE_DEST
                                headers:@{kHeaderTransaction: transaction.identifier}
                                   body:@"in a transaction"];
                }];

    XCTAssertFalse(gotSignal(messageReceived, 1));

    [transaction commit];

    XCTAssertTrue(gotSignal(messageReceived, 1));
}

- (void)testAbortTransaction {
    dispatch_semaphore_t messageSent = dispatch_semaphore_create(0);
    dispatch_semaphore_t messageReceived = dispatch_semaphore_create(0);

    __block STOMPTransaction *transaction;

    [self.client connectWithLogin:LOGIN
                         passcode:PASSCODE
                completionHandler:^(STOMPFrame *connectedFrame, NSError *error) {
                    [self.client subscribeTo:QUEUE_DEST
                              messageHandler:^(STOMPMessage *message) {
                                  dispatch_semaphore_signal(messageReceived);
                              }];
                    transaction = [self.client begin];
                    [self.client sendTo:QUEUE_DEST
                                headers:@{kHeaderTransaction: transaction.identifier}
                                   body:@"in a transaction"];
                    dispatch_semaphore_signal(messageSent);
                }];

    XCTAssertTrue(gotSignal(messageSent, 2));

    [transaction abort];

    XCTAssertFalse(gotSignal(messageReceived, 2));
}

- (void)testJSON
{
    dispatch_semaphore_t messageReceived = dispatch_semaphore_create(0);

    NSDictionary *dict = @{@"foo": @"bar"};
    __block NSString *receivedBody;

    [self.client connectWithLogin:LOGIN
                         passcode:PASSCODE
                completionHandler:^(STOMPFrame *connectedFrame, NSError *error) {
                    [self.client subscribeTo:QUEUE_DEST
                              messageHandler:^(STOMPMessage *message) {
                                  receivedBody = message.body;
                                  dispatch_semaphore_signal(messageReceived);
                              }];
                    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
                    NSString *body =[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    [self.client sendTo:QUEUE_DEST body:body];
                }];

    XCTAssertTrue(gotSignal(messageReceived, 2), @"did not receive signal");

    NSDictionary *receivedDict = [NSJSONSerialization JSONObjectWithData:[receivedBody dataUsingEncoding:NSUTF8StringEncoding]
                                    options:NSJSONReadingMutableContainers
                                      error:nil];
    XCTAssertTrue([receivedDict[@"foo"] isEqualToString:@"bar"]);
}

@end