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
#define kNoHeartBeat @"0,0"

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

@property (nonatomic, copy) void (^disconnectedHandler)(NSError *error);
@property (nonatomic, copy) void (^connectionCompletionHandler)(STOMPFrame *connectedFrame, NSError *error);
@property (nonatomic, retain) NSMutableDictionary *subscriptions;

- (void) sendFrameWithCommand:(NSString *)command
                      headers:(NSDictionary *)headers
                         body:(NSString *)body;

@end

#pragma mark STOMP Frame

@interface STOMPFrame()

- (id)initWithCommand:(NSString *)theCommand
              headers:(NSDictionary *)theHeaders
                body:(NSString *)theBody;

- (NSData *)toData;

@end

@implementation STOMPFrame

@synthesize command, headers, body;

- (id)initWithCommand:(NSString *)theCommand
              headers:(NSDictionary *)theHeaders
                 body:(NSString *)theBody {
    if(self = [super init]) {
        command = theCommand;
        headers = theHeaders;
        body = theBody;
    }
    return self;
}

- (NSString *)toString {
    NSMutableString *frame = [NSMutableString stringWithString: [self.command stringByAppendingString:kLineFeed]];
	for (id key in self.headers) {
        [frame appendString:[NSString stringWithFormat:@"%@%@%@%@", key, kHeaderSeparator, self.headers[key], kLineFeed]];
	}
    [frame appendString:kLineFeed];
	if (self.body) {
		[frame appendString:self.body];
	}
    [frame appendString:kNullChar];
    return frame;
}

- (NSData *)toData {
    return [[self toString] dataUsingEncoding:NSUTF8StringEncoding];
}

+ (STOMPFrame *) STOMPFrameFromData:(NSData *)data {
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
    return [[STOMPFrame alloc] initWithCommand:command headers:headers body:body];
}

- (NSString *)description {
    return [self toString];
}


@end

#pragma mark STOMP Message

@interface STOMPMessage()

@property (nonatomic, retain) STOMPClient *client;

+ (STOMPMessage *)STOMPMessageFromFrame:(STOMPFrame *)frame
                                 client:(STOMPClient *)client;

@end

@implementation STOMPMessage

@synthesize client;

- (id)initWithClient:(STOMPClient *)theClient
             headers:(NSDictionary *)theHeaders
                body:(NSString *)theBody {
    if (self = [super initWithCommand:kCommandMessage
                              headers:theHeaders
                                 body:theBody]) {
        self.client = theClient;
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

+ (STOMPMessage *)STOMPMessageFromFrame:(STOMPFrame *)frame
                                 client:(STOMPClient *)client {
    return [[STOMPMessage alloc] initWithClient:client headers:frame.headers body:frame.body];
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

- (NSString *)description {
    return [NSString stringWithFormat:@"<STOMPSubscription identifier:%@>", identifier];
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

- (NSString *)description {
    return [NSString stringWithFormat:@"<STOMPTransaction identifier:%@>", identifier];
}

@end

#pragma mark STOMP Client Implementation

@implementation STOMPClient

@synthesize socket, host, port;
@synthesize connectionCompletionHandler, disconnectedHandler, receiptHandler, errorHandler;
@synthesize subscriptions;

BOOL connected;
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
        connected = NO;
        self.subscriptions = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)connectWithLogin:(NSString *)login
                passcode:(NSString *)passcode
       completionHandler:(void (^)(STOMPFrame *connectedFrame, NSError *error))completionHandler {
    [self connectWithHeaders:@{kHeaderLogin: login, kHeaderPasscode: passcode}
           completionHandler:completionHandler];
}

- (void)connectWithHeaders:(NSDictionary *)headers
         completionHandler:(void (^)(STOMPFrame *connectedFrame, NSError *error))completionHandler {
    self.connectionCompletionHandler = completionHandler;

    NSError *err;
    if(![self.socket connectToHost:host onPort:port error:&err]) {
        if (self.connectionCompletionHandler) {
            self.connectionCompletionHandler(nil, err);
        }
    }

    NSMutableDictionary *connectHeaders = [[NSMutableDictionary alloc] initWithDictionary:headers];
    connectHeaders[kHeaderAcceptVersion] = kVersion1_2;
    connectHeaders[kHeaderHeartBeat] = kNoHeartBeat;

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
                    messageHandler:(STOMPMessageHandler)handler {
    return [self subscribeTo:destination
                     headers:nil
              messageHandler:handler];
}

- (STOMPSubscription *)subscribeTo:(NSString *)destination
                           headers:(NSDictionary *)headers
                    messageHandler:(STOMPMessageHandler)handler {
	NSMutableDictionary *subHeaders = [[NSMutableDictionary alloc] initWithDictionary:headers];
    subHeaders[kHeaderDestination] = destination;
    NSString *identifier = subHeaders[kHeaderID];
    if (!identifier) {
        identifier = [NSString stringWithFormat:@"sub-%d", idGenerator++];
        subHeaders[kHeaderID] = identifier;
    }
    self.subscriptions[identifier] = handler;
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

- (void)disconnect:(void (^)(NSError *error))completionHandler {
    self.disconnectedHandler = completionHandler;
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
    STOMPFrame *frame = [[STOMPFrame alloc] initWithCommand:command headers:headers body:body];
    NSData *data = [frame toData];
    [self.socket writeData:data withTimeout:kDefaultTimeout tag:123];
}

- (void)receivedFrame:(STOMPFrame *)frame {
	// CONNECTED
	if([kCommandConnected isEqual:frame.command]) {
        connected = YES;
        if (self.connectionCompletionHandler) {
            self.connectionCompletionHandler(frame, nil);
        }
    // MESSAGE
	} else if([kCommandMessage isEqual:frame.command]) {
        STOMPMessageHandler handler = self.subscriptions[frame.headers[kHeaderSubscription]];
        if (handler) {
            STOMPMessage *message = [STOMPMessage STOMPMessageFromFrame:frame
                                                                 client:self];
            handler(message);
        } else {
            //TODO default handler
        }
        // RECEIPT
	} else if([kCommandReceipt isEqual:frame.command]) {
        if (self.receiptHandler) {
            self.receiptHandler(frame);
        }
        // ERROR
	} else if([kCommandError isEqual:frame.command]) {
        NSError *error = [[NSError alloc] initWithDomain:@"StompKit" code:1 userInfo:@{@"frame": frame}];
        if (self.connectionCompletionHandler) {
            self.connectionCompletionHandler(frame, error);
        }
	} else {
        NSError *error = [[NSError alloc] initWithDomain:@"StompKit"
                                                    code:2
                                                userInfo:@{@"message": [NSString stringWithFormat:@"Unknown frame %@", frame.command]}];
        if (self.errorHandler) {
            self.errorHandler(error);
        }
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
    STOMPFrame *frame = [STOMPFrame STOMPFrameFromData:data];
    [self receivedFrame:frame];
    [self readFrame];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    [self readFrame];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock
                  withError:(NSError *)err {
    if (!connected && self.connectionCompletionHandler) {
        self.connectionCompletionHandler(nil, err);
    } else if (connected && self.disconnectedHandler) {
        self.disconnectedHandler(err);
    }
    connected = NO;
}

@end
