//
//  StompKit.m
//  StompKit
//
//  Created by Jeff Mesnil on 09/10/2013.
//  Copyright (c) 2013 Jeff Mesnil. All rights reserved.
//

#import "StompKit.h"

#define kDefaultTimeout 5
#define kVersion1_2 @"1.2"

#pragma mark Logging macros

#if 0 // set to 1 to enable logs

#define LogDebug(frmt, ...) NSLog(frmt, ##__VA_ARGS__);

#else

#define LogDebug(frmt, ...) {}

#endif

#pragma mark Frame commands

#define kCommandAbort       @"ABORT"
#define kCommandAck         @"ACK"
#define kCommandBegin       @"BEGIN"
#define kCommandCommit      @"COMMIT"
#define kCommandConnect     @"CONNECT"
#define kCommandConnected   @"CONNECTED"
#define kCommandDisconnect  @"DISCONNECT"
#define kCommandError       @"ERROR"
#define kCommandMessage     @"MESSAGE"
#define kCommandNack        @"NACK"
#define kCommandReceipt     @"RECEIPT"
#define kCommandSend        @"SEND"
#define kCommandSubscribe   @"SUBSCRIBE"
#define kCommandUnsubscribe @"UNSUBSCRIBE"

#pragma mark Control characters

#define	kLineFeed @"\x0A"
#define	kNullChar @"\x00"
#define kHeaderSeparator @":"

#pragma mark -
#pragma mark STOMP Client private interface

@interface STOMPClient()

@property (nonatomic, retain) GCDAsyncSocket *socket;
@property (nonatomic, copy) NSString *host;
@property (nonatomic) NSUInteger port;

@property (copy) STOMPFrameHandler connectedHandler;
@property (copy) void (^disconnectedHandler)(void);
@property (nonatomic, retain) NSMutableDictionary *subscriptions;

- (void) sendFrameWithCommand:(NSString *)command
                      headers:(NSDictionary *)headers
                         body:(NSString *)body;

@end

#pragma mark STOMP Frame

@interface STOMPFrame()

@property (nonatomic, retain) STOMPClient *client;

- (id)initWithClient:(STOMPClient *)theClient
             command:(NSString *)theCommand
             headers: (NSDictionary *)theHeaders
                body:(NSString *)theBody;

@end

@implementation STOMPFrame

@synthesize command, headers, body;
@synthesize client;

- (id)initWithClient:(STOMPClient *)theClient
             command:(NSString *)theCommand
             headers:(NSDictionary *)theHeaders
                body:(NSString *)theBody {
    if(self = [super init]) {
        client = theClient;
        command = theCommand;
        headers = theHeaders;
        body = theBody;
    }
    return self;
}

@end

#pragma mark STOMP Message

@interface STOMPMessage()

- (id)initWithClient:(STOMPClient *)theClient
             headers: (NSDictionary *)theHeaders
                body:(NSString *)theBody;

@end

@implementation STOMPMessage

- (id)initWithClient:(STOMPClient *)theClient
             headers:(NSDictionary *)theHeaders
                body:(NSString *)theBody {
    if (self = [super initWithClient:theClient
                             command:kCommandMessage
                             headers:theHeaders
                                body:theBody]) {
    }
    return self;
}

- (void)ack {
    [self ackWithCommand:kCommandAck headers:nil];
}

- (void)ack: (NSDictionary *)theHeaders {
    [self ackWithCommand:kCommandAck headers:theHeaders];
}

- (void)nack {
    [self ackWithCommand:kCommandNack headers:nil];
}

- (void)nack: (NSDictionary *)theHeaders {
    [self ackWithCommand:kCommandNack headers:theHeaders];
}

- (void)ackWithCommand: (NSString *)command
               headers: (NSDictionary *)theHeaders {
    NSMutableDictionary *ackHeaders = [[NSMutableDictionary alloc] initWithDictionary:theHeaders];
    ackHeaders[kHeaderID] = self.headers[kHeaderAck];
    [self.client sendFrameWithCommand:command
                              headers:ackHeaders
                                 body:nil];
}

@end

#pragma mark STOMP Subscription

@interface STOMPSubscription()

@property (nonatomic, retain) STOMPClient *client;

- (id)initWithClient:(STOMPClient *)theClient
          identifier:(NSString *)theIdentifier;

@end

@implementation STOMPSubscription

@synthesize client;
@synthesize identifier;

- (id)initWithClient:(STOMPClient *)theClient
          identifier:(NSString *)theIdentifier {
    if(self = [super init]) {
        self.client = theClient;
        identifier = [theIdentifier copy];
    }
    return self;
}

- (void)unsubscribe {
    [self.client sendFrameWithCommand:kCommandUnsubscribe
                              headers:@{kHeaderID: self.identifier}
                                 body:nil];
}

@end

#pragma mark STOMP Transaction

@interface STOMPTransaction()

@property (nonatomic, retain) STOMPClient *client;

- (id)initWithClient:(STOMPClient *)theClient
          identifier:(NSString *)theIdentifier;

@end

@implementation STOMPTransaction

@synthesize identifier;

- (id)initWithClient:(STOMPClient *)theClient
          identifier:(NSString *)theIdentifier {
    if(self = [super init]) {
        self.client = theClient;
        identifier = [theIdentifier copy];
    }
    return self;
}

- (void)commit {
    [self.client sendFrameWithCommand:kCommandCommit
                              headers:@{kHeaderTransaction: self.identifier}
                                 body:nil];
}

- (void)abort {
    [self.client sendFrameWithCommand:kCommandAbort
                              headers:@{kHeaderTransaction: self.identifier}
                                 body:nil];
}

@end

#pragma mark STOMP Client Implementation

@implementation STOMPClient

@synthesize socket, host, port;
@synthesize connectedHandler, disconnectedHandler, receiptHandler;
@synthesize subscriptions;

int idGenerator;

#pragma mark -
#pragma mark Public API

- (id)initWithHost:(NSString *)aHost
              port:(NSUInteger)aPort {
    if(self = [super init]) {
        self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                 delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
        self.host = aHost;
        self.port = aPort;
        idGenerator = 0;
        self.subscriptions = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)connectWithLogin:(NSString *)aLogin
                passcode:(NSString *)aPasscode
              completion:(STOMPFrameHandler)aHandler {
    [self connectWithHeaders:@{kHeaderLogin: aLogin, kHeaderPasscode: aPasscode}
                  completion:aHandler];
}

- (void)connectWithHeaders:(NSDictionary *)headers
                completion:(STOMPFrameHandler)aHandler {
    self.connectedHandler = aHandler;

    NSError *err;
    if(![self.socket connectToHost:host onPort:port error:&err]) {
        LogDebug(@"StompService error: %@", err);
    }

    NSMutableDictionary *connectHeaders = [[NSMutableDictionary alloc] initWithDictionary:headers];
    connectHeaders[kHeaderAcceptVersion] = kVersion1_2;

    [self sendFrameWithCommand:kCommandConnect
                       headers:connectHeaders
                          body: nil];
}

- (void)sendTo:(NSString *)destination
          body:(NSString *)body {
    [self sendTo:destination
         headers:nil
            body:body];
}

- (void)sendTo:(NSString *)destination
       headers:(NSDictionary *)headers
          body:(NSString *)body {
	NSMutableDictionary *msgHeaders = [NSMutableDictionary dictionaryWithDictionary:headers];
    msgHeaders[kHeaderDestination] = destination;
    if (body) {
        msgHeaders[kHeaderContentLength] = [NSNumber numberWithInt:[body length]];
    }
    [self sendFrameWithCommand:kCommandSend
                       headers:msgHeaders
                          body:body];
}

- (STOMPSubscription *)subscribeTo:(NSString *)destination
                           handler:(STOMPMessageHandler)aHandler {
    return [self subscribeTo:destination
                     headers:nil
                     handler:aHandler];
}

- (STOMPSubscription *)subscribeTo:(NSString *)destination
                           headers:(NSDictionary *)headers
                           handler:(STOMPMessageHandler)aHandler {
	NSMutableDictionary *subHeaders = [[NSMutableDictionary alloc] initWithDictionary:headers];
    subHeaders[kHeaderDestination] = destination;
    NSString *identifier = subHeaders[kHeaderID];
    if (!identifier) {
        identifier = [NSString stringWithFormat:@"sub-%d", idGenerator++];
        subHeaders[kHeaderID] = identifier;
    }
    self.subscriptions[identifier] = aHandler;
    [self sendFrameWithCommand:kCommandSubscribe
                       headers:subHeaders
                          body:nil];
    return [[STOMPSubscription alloc] initWithClient:self identifier:identifier];
}

- (STOMPTransaction *)begin {
    NSString *identifier = [NSString stringWithFormat:@"tx-%d", idGenerator++];
    return [self begin:identifier];
}

- (STOMPTransaction *)begin:(NSString *)identifier {
    [self sendFrameWithCommand:kCommandBegin
                       headers:@{kHeaderTransaction: identifier}
                          body:nil];
    return [[STOMPTransaction alloc] initWithClient:self identifier:identifier];
}

- (void)disconnect {
    [self disconnect: nil];
}

- (void)disconnect:(void (^)(void))aHandler {
    self.disconnectedHandler = aHandler;
    [self sendFrameWithCommand:kCommandDisconnect
                       headers:nil
                          body:nil];
    [self.subscriptions removeAllObjects];
    [self.socket disconnectAfterReadingAndWriting];
}


#pragma mark -
#pragma mark Private Methods
- (void)sendFrameWithCommand:(NSString *)command
                     headers:(NSDictionary *)headers
                        body:(NSString *)body {
    NSMutableString *frame = [NSMutableString stringWithString: [command stringByAppendingString:kLineFeed]];
	for (id key in headers) {
        [frame appendString:[NSString stringWithFormat:@"%@%@%@%@", key, kHeaderSeparator, headers[key], kLineFeed]];
	}
    [frame appendString:kLineFeed];
	if (body) {
		[frame appendString:body];
	}
    [frame appendString:kNullChar];
    LogDebug(@">>> %@", frame);
    NSData *data = [frame dataUsingEncoding:NSUTF8StringEncoding];
    [self.socket writeData:data withTimeout:kDefaultTimeout tag:123];
}

- (void)frameReceivedWithCommand:(NSString *)command
                         headers:(NSDictionary *)headers
                            body:(NSString *)body {
    STOMPFrame *frame = [[STOMPFrame alloc] initWithClient:self
                                                   command:command
                                                   headers:headers
                                                      body:body];

	// CONNECTED
	if([kCommandConnected isEqual:command]) {
        if (self.connectedHandler) {
            self.connectedHandler(frame);
        }
        // MESSAGE
	} else if([kCommandMessage isEqual:command]) {
        STOMPMessageHandler handler = self.subscriptions[headers[kHeaderSubscription]];
        if (handler) {
            STOMPMessage *message = [[STOMPMessage alloc] initWithClient:self
                                                                 headers:headers
                                                                    body:body];
            handler(message);
        } else {
            //TODO default handler
        }
        // RECEIPT
	} else if([kCommandReceipt isEqual:command]) {
        if (self.receiptHandler) {
            self.receiptHandler(frame);
        }
        // ERROR
	} else if([kCommandError isEqual:command]) {
        //TODO
	} else {
        //TODO
    }
}

- (void)readFrame {
	[[self socket] readDataToData:[GCDAsyncSocket ZeroData] withTimeout:-1 tag:0];
}

#pragma mark -
#pragma mark GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock
   didReadData:(NSData *)data
       withTag:(long)tag {
	NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length])];
	NSString *msg = [[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding];
    LogDebug(@"<<< %@", msg);
    NSMutableArray *contents = (NSMutableArray *)[[msg componentsSeparatedByString:kLineFeed] mutableCopy];
	if([[contents objectAtIndex:0] isEqual:@""]) {
		[contents removeObjectAtIndex:0];
	}
	NSString *command = [[contents objectAtIndex:0] copy];
	NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
	NSMutableString *body = [[NSMutableString alloc] init];
	BOOL hasHeaders = NO;
    [contents removeObjectAtIndex:0];
	for(NSString *line in contents) {
		if(hasHeaders) {
            for (int i=0; i < [line length]; i++) {
                unichar c = [line characterAtIndex:i];
                if (c != '\x00') {
                    [body appendString:[NSString stringWithFormat:@"%c", c]];
                }
            }
		} else {
			if ([line isEqual:@""]) {
				hasHeaders = YES;
			} else {
				NSMutableArray *parts = [NSMutableArray arrayWithArray:[line componentsSeparatedByString:kHeaderSeparator]];
				// key ist the first part
				NSString *key = parts[0];
            	[parts removeObjectAtIndex:0];
                headers[key] = [parts componentsJoinedByString:kHeaderSeparator];
			}
		}
	}
    [self frameReceivedWithCommand:command headers:headers body:body];
	[self readFrame];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    [self readFrame];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock
                  withError:(NSError *)err {
    if (err) {
        //TODO
    } else {
        if (self.disconnectedHandler) {
            self.disconnectedHandler();
        }
    }
}

@end
