//
//  VicrabLogTests.m
//  Vicrab
//
//  Created by Daniel Griesser on 08/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Vicrab/Vicrab.h>
#import "VicrabLog.h"

@interface VicrabLogTests : XCTestCase

@end

@implementation VicrabLogTests

- (void)testLogTypes {
    VicrabClient.logLevel = kVicrabLogLevelVerbose;
    [VicrabLog logWithMessage:@"1" andLevel:kVicrabLogLevelError];
    [VicrabLog logWithMessage:@"2" andLevel:kVicrabLogLevelDebug];
    [VicrabLog logWithMessage:@"3" andLevel:kVicrabLogLevelVerbose];
    [VicrabLog logWithMessage:@"4" andLevel:kVicrabLogLevelNone];
    VicrabClient.logLevel = kVicrabSeverityError;
}

@end
