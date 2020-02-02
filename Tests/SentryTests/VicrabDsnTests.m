//
//  VicrabDsnTests.m
//  Vicrab
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Vicrab/Vicrab.h>
#import "VicrabError.h"
#import "VicrabDsn.h"

@interface VicrabNSURLRequest (Private)

+ (NSURL *)getStoreUrlFromDsn:(VicrabDsn *)dsn;

@end

@interface VicrabDsnTests : XCTestCase

@end

//+ (NSURL *)getStoreUrlFromDsn:(VicrabDsn *)dsn

@implementation VicrabDsnTests

- (void)testMissingUsernamePassword {
    NSError *error = nil;
    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"https://vicrab.io" didFailWithError:&error];
    XCTAssertEqual(kVicrabErrorInvalidDsnError, error.code);
    XCTAssertNil(client);
}

- (void)testDsnHeaderUsernameAndPassword {
    NSError *error = nil;
    VicrabDsn *dsn = [[VicrabDsn alloc] initWithString:@"https://username:password@vicrab.io/1" didFailWithError:&error];
    VicrabNSURLRequest *request = [[VicrabNSURLRequest alloc] initStoreRequestWithDsn:dsn andData:[NSData data] didFailWithError:&error];
    
    NSDictionary *info = [[NSBundle bundleForClass:[VicrabClient class]] infoDictionary];
    NSString *version = [NSString stringWithFormat:@"%@", info[@"CFBundleShortVersionString"]];
    
    NSString *authHeader = [[NSString alloc] initWithFormat: @"Vicrab vicrab_version=7,vicrab_client=vicrab-cocoa/%@,vicrab_timestamp=%@,vicrab_key=username,vicrab_secret=password", version, @((NSInteger) [[NSDate date] timeIntervalSince1970])];
    
    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"X-Vicrab-Auth"], authHeader);
    XCTAssertNil(error);
}

- (void)testDsnHeaderUsername {
    NSError *error = nil;
    VicrabDsn *dsn = [[VicrabDsn alloc] initWithString:@"https://username@vicrab.io/1" didFailWithError:&error];
    VicrabNSURLRequest *request = [[VicrabNSURLRequest alloc] initStoreRequestWithDsn:dsn andData:[NSData data] didFailWithError:&error];
    
    NSDictionary *info = [[NSBundle bundleForClass:[VicrabClient class]] infoDictionary];
    NSString *version = [NSString stringWithFormat:@"%@", info[@"CFBundleShortVersionString"]];
    
    NSString *authHeader = [[NSString alloc] initWithFormat: @"Vicrab vicrab_version=7,vicrab_client=vicrab-cocoa/%@,vicrab_timestamp=%@,vicrab_key=username", version, @((NSInteger) [[NSDate date] timeIntervalSince1970])];
    
    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"X-Vicrab-Auth"], authHeader);
    XCTAssertNil(error);
}

- (void)testMissingScheme {
    NSError *error = nil;
    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"vicrab.io" didFailWithError:&error];
    XCTAssertEqual(kVicrabErrorInvalidDsnError, error.code);
    XCTAssertNil(client);
}

- (void)testMissingHost {
    NSError *error = nil;
    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"http:///1" didFailWithError:&error];
    XCTAssertEqual(kVicrabErrorInvalidDsnError, error.code);
    XCTAssertNil(client);
}

- (void)testUnsupportedProtocol {
    NSError *error = nil;
    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"ftp://vicrab.io/1" didFailWithError:&error];
    XCTAssertEqual(kVicrabErrorInvalidDsnError, error.code);
    XCTAssertNil(client);
}
    
- (void)testDsnUrl {
    NSError *error = nil;
    VicrabDsn *dsn = [[VicrabDsn alloc] initWithString:@"https://username:password@getvicrab.net/1" didFailWithError:&error];
    
    XCTAssertEqualObjects([[VicrabNSURLRequest getStoreUrlFromDsn:dsn] absoluteString], @"https://getvicrab.net/api/1/store/");
    XCTAssertNil(error);
    
    VicrabDsn *dsn2 = [[VicrabDsn alloc] initWithString:@"https://username:password@vicrab.io/foo/bar/baz/1" didFailWithError:&error];
    
    XCTAssertEqualObjects([[VicrabNSURLRequest getStoreUrlFromDsn:dsn2] absoluteString], @"https://vicrab.io/foo/bar/baz/api/1/store/");
    XCTAssertNil(error);
}

@end
