//
//  SKSocketUtility.m
//  StompKit
//
//  Created by Travis Bowers on 4/2/15.
//  Copyright (c) 2015 Jeff Mesnil. All rights reserved.
//

#import "SKSocketUtility.h"

@implementation SKSocketUtility

+ (NSData*)zeroData {
    return [NSData dataWithBytes:"" length:1];
}

+ (NSData*)lineFeedData {
    return [NSData dataWithBytes:"\x0A" length:1];
}

@end
