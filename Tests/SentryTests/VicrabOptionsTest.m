//
//  VicrabOptionsTest.m
//  VicrabTests
//
//  Created by Daniel Griesser on 12.03.19.
//  Copyright © 2019 Vicrab. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "VicrabError.h"
#import "VicrabOptions.h"


@interface VicrabOptionsTest : XCTestCase

@end

@implementation VicrabOptionsTest

- (void)testEmptyDsn {
    NSError *error = nil;
    VicrabOptions *options = [[VicrabOptions alloc] initWithOptions:@{} didFailWithError:&error];
    XCTAssertEqual(kVicrabErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}

- (void)testInvalidDsn {
    NSError *error = nil;
    VicrabOptions *options = [[VicrabOptions alloc] initWithOptions:@{@"dsn": @"https://vicrab.io"} didFailWithError:&error];
    XCTAssertEqual(kVicrabErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}

- (void)testInvalidDsnBoolean {
    NSError *error = nil;
    VicrabOptions *options = [[VicrabOptions alloc] initWithOptions:@{@"dsn": @YES} didFailWithError:&error];
    XCTAssertEqual(kVicrabErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}
    
- (void)testRelease {
    NSError *error = nil;
    VicrabOptions *options = [[VicrabOptions alloc] initWithOptions:@{@"dsn": @"https://username:password@vicrab.io/1"} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertNil(options.releaseName);
    
    options = [[VicrabOptions alloc] initWithOptions:@{@"dsn": @"https://username:password@vicrab.io/1", @"release": @"abc"} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(options.releaseName, @"abc");
}
    
- (void)testEnvironment {
    NSError *error = nil;
    VicrabOptions *options = [[VicrabOptions alloc] initWithOptions:@{@"dsn": @"https://username:password@vicrab.io/1"} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertNil(options.environment);
    
    options = [[VicrabOptions alloc] initWithOptions:@{@"dsn": @"https://username:password@vicrab.io/1", @"environment": @"xxx"} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(options.environment, @"xxx");
}

- (void)testDist {
    NSError *error = nil;
    VicrabOptions *options = [[VicrabOptions alloc] initWithOptions:@{@"dsn": @"https://username:password@vicrab.io/1"} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertNil(options.dist);
    
    options = [[VicrabOptions alloc] initWithOptions:@{@"dsn": @"https://username:password@vicrab.io/1", @"dist": @"hhh"} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(options.dist, @"hhh");
}
    
- (void)testEnabled {
    NSError *error = nil;
    VicrabOptions *options = [[VicrabOptions alloc] initWithOptions:@{@"dsn": @"https://username:password@vicrab.io/1"} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertFalse([options.enabled boolValue]);
    
    options = [[VicrabOptions alloc] initWithOptions:@{@"dsn": @"https://username:password@vicrab.io/1", @"enabled": @YES} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertTrue([options.enabled boolValue]);
    
    options = [[VicrabOptions alloc] initWithOptions:@{@"dsn": @"https://username:password@vicrab.io/1", @"enabled": @NO} didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertFalse([options.enabled boolValue]);
}

@end
