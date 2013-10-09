//
//  StompKitTests.h
//  StompKit
//
//  Created by Jeff Mesnil on 09/10/2013.
//  Copyright (c) 2013 Jeff Mesnil. All rights reserved.
//

#ifndef StompKit_StompKitTests_h
#define StompKit_StompKitTests_h

#define HOST @"localhost"
#define PORT 61613
#define LOGIN @"user"
#define PASSCODE @"password"

#define QUEUE_DEST @"/queue/myqueue"
#define QUEUE_DEST_2 @"/queue/myqueue_2"

#define secondsToNanoseconds(t) (t * 1000000000) // in nanoseconds
#define gotSignal(semaphore, timeout) ((dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, secondsToNanoseconds(timeout)))) == 0l)

#endif