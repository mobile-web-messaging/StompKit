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

@end

@implementation ViewController

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
}

@end
