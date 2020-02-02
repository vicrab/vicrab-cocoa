//
//  VicrabTests.m
//  VicrabTests
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Vicrab/Vicrab.h>
#import "VicrabInstallation.h"
#import "NSDate+VicrabExtras.h"

@interface VicrabBreadcrumbTracker (Private)

+ (NSString *)sanitizeViewControllerName:(NSString *)controller;

@end

@interface VicrabTests : XCTestCase

@end

@implementation VicrabTests

- (void)testVersion {
    NSDictionary *info = [[NSBundle bundleForClass:[VicrabClient class]] infoDictionary];
    NSString *version = [NSString stringWithFormat:@"%@", info[@"CFBundleShortVersionString"]];
    XCTAssert([version isEqualToString:VicrabClient.versionString]);
}

- (void)testSharedClient {
    NSError *error = nil;
    VicrabClient.logLevel = kVicrabLogLevelNone;
    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"https://username:password@app.getvicrab.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    XCTAssertNil(VicrabClient.sharedClient);
    VicrabClient.sharedClient = client;
    XCTAssertNotNil(VicrabClient.sharedClient);
}

// TODO
//- (void)testCrash {
//    NSError *error = nil;
//    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"https://username:password@app.getvicrab.com/12345" didFailWithError:&error];
//    [client crash];
//}

// TODO
//- (void)testCrashedLastLaunch {
//    NSError *error = nil;
//    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"https://username:password@app.getvicrab.com/12345" didFailWithError:&error];
//    XCTAssertFalse([client crashedLastLaunch]);
//}

- (void)testBreadCrumbTracking {
    NSError *error = nil;
    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"https://username:password@app.getvicrab.com/123456" didFailWithError:&error];
    [client.breadcrumbs clear];
    [client enableAutomaticBreadcrumbTracking];
    XCTAssertEqual(client.breadcrumbs.count, (unsigned long)0);
    [VicrabClient setSharedClient:client];
    [VicrabClient.sharedClient enableAutomaticBreadcrumbTracking];
    XCTAssertEqual(VicrabClient.sharedClient.breadcrumbs.count, (unsigned long)1);
    [VicrabClient setSharedClient:nil];
    [client.breadcrumbs clear];
}

- (void)testUserException {
    NSError *error = nil;
    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"https://username:password@app.getvicrab.com/12345" didFailWithError:&error];
    [client reportUserException:@"a" reason:@"b" language:@"c" lineOfCode:@"1" stackTrace:[NSArray new] logAllThreads:YES terminateProgram:NO];
}

- (void)testSeverity {
    XCTAssertEqualObjects(@"fatal", VicrabSeverityNames[kVicrabSeverityFatal]);
    XCTAssertEqualObjects(@"error", VicrabSeverityNames[kVicrabSeverityError]);
    XCTAssertEqualObjects(@"warning", VicrabSeverityNames[kVicrabSeverityWarning]);
    XCTAssertEqualObjects(@"info", VicrabSeverityNames[kVicrabSeverityInfo]);
    XCTAssertEqualObjects(@"debug", VicrabSeverityNames[kVicrabSeverityDebug]);
}

- (void)testDateCategory {
    NSDate *date = [NSDate date];
    XCTAssertEqual((NSInteger)[[NSDate vicrab_fromIso8601String:[date vicrab_toIso8601String]] timeIntervalSince1970], (NSInteger)[date timeIntervalSince1970]);
}

- (void)testBreadcrumbTracker {
    XCTAssertEqualObjects(@"vicrab_ios_cocoapods.ViewController", [VicrabBreadcrumbTracker sanitizeViewControllerName:@"<vicrab_ios_cocoapods.ViewController: 0x7fd9201253c0>"]);
    XCTAssertEqualObjects(@"vicrab_ios_cocoapodsViewController: 0x7fd9201253c0", [VicrabBreadcrumbTracker sanitizeViewControllerName:@"vicrab_ios_cocoapodsViewController: 0x7fd9201253c0"]);
    XCTAssertEqualObjects(@"vicrab_ios_cocoapods.ViewController.miau", [VicrabBreadcrumbTracker sanitizeViewControllerName:@"<vicrab_ios_cocoapods.ViewController.miau: 0x7fd9201253c0>"]);
}

@end
