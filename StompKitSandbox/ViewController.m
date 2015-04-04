//
//  ViewController.m
//  StompKitSandbox
//
//  Created by Travis Bowers on 4/2/15.
//  Copyright (c) 2015 Jeff Mesnil. All rights reserved.
//

#import "ViewController.h"
#import "StompKit.h"

@interface ViewController ()
@property (nonatomic, strong) STOMPClient *client;
@end

@implementation ViewController
@synthesize client;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)connectButtonPressed:(id)sender {
    // create the client
    client = [[STOMPClient alloc] initWithHost:@"ws://localhost:61614/stomp"];
    // connect to the broker
    [client connectWithCompletionHandler:^(STOMPFrame *_, NSError *error) {
        if (error) {
            NSLog(@"%@", error);
            return;
        }
        
        // send a message
        [client sendTo:@"/queue/bowers" body:@"Hello, iOS!"];
        // and disconnect
        [client disconnect];
    }];
}

- (IBAction)disconnectButtonPressed:(id)sender {
    if (client != nil) {
        [client disconnect];
    }
}

- (IBAction)sendButtonPressed:(id)sender {
    // send a message
    [client sendTo:@"/queue/myqueue" body:@"Hello, iOS!"];
}

@end
