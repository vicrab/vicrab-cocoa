//
//  VicrabInterfacesTests.m
//  Vicrab
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Vicrab/Vicrab.h>
#import "VicrabContext.h"
#import "VicrabFileManager.h"
#import "NSDate+Extras.h"

@interface VicrabInterfacesTests : XCTestCase

@end

@implementation VicrabInterfacesTests

// TODO test event

- (void)testDebugMeta {
    VicrabDebugMeta *debugMeta = [[VicrabDebugMeta alloc] init];
    debugMeta.uuid = @"abcd";
    XCTAssertNotNil(debugMeta.uuid);
    NSDictionary *serialized = @{@"uuid": @"abcd"};
    XCTAssertEqualObjects([debugMeta serialize], serialized);

    VicrabDebugMeta *debugMeta2 = [[VicrabDebugMeta alloc] init];
    debugMeta2.uuid = @"abcde";
    debugMeta2.imageAddress = @"0x0000000100034000";
    debugMeta2.type = @"1";
    debugMeta2.cpuSubType = @(2);
    debugMeta2.cpuType = @(3);
    debugMeta2.imageVmAddress = @"0x01";
    debugMeta2.imageSize = @(4);
    debugMeta2.name = @"name";
    debugMeta2.revisionVersion = @(10);
    debugMeta2.minorVersion = @(20);
    debugMeta2.majorVersion = @(30);
    NSDictionary *serialized2 = @{@"image_addr": @"0x0000000100034000",
                                  @"image_vmaddr": @"0x01",
                                  @"image_addr": @"0x02",
                                  @"image_size": @(4),
                                  @"type": @"1",
                                  @"name": @"name",
                                  @"cpu_subtype": @(2),
                                  @"cpu_type": @(3),
                                  @"revision_version": @(10),
                                  @"minor_version": @(20),
                                  @"major_version": @(30),
                                  @"uuid": @"abcde"};
    XCTAssertEqualObjects([debugMeta2 serialize], serialized2);
}

- (void)testFrame {
    VicrabFrame *frame = [[VicrabFrame alloc] init];
    frame.symbolAddress = @"0x01";
    XCTAssertNotNil(frame.symbolAddress);
    NSDictionary *serialized = @{@"symbol_addr": @"0x01", @"function": @"<redacted>"};
    XCTAssertEqualObjects([frame serialize], serialized);

    VicrabFrame *frame2 = [[VicrabFrame alloc] init];
    frame2.symbolAddress = @"0x01";
    XCTAssertNotNil(frame2.symbolAddress);

    frame2.fileName = @"file://b.swift";
    frame2.function = @"[hey2 alloc]";
    frame2.module = @"b";
    frame2.lineNumber = @(100);
    frame2.columnNumber = @(200);
    frame2.package = @"package";
    frame2.imageAddress = @"image_addr";
    frame2.instructionAddress = @"instruction_addr";
    frame2.symbolAddress = @"symbol_addr";
    frame2.platform = @"platform";
    NSDictionary *serialized2 = @{@"filename": @"file://b.swift",
                                  @"function": @"[hey2 alloc]",
                                  @"module": @"b",
                                  @"package": @"package",
                                  @"image_addr": @"image_addr",
                                  @"instruction_addr": @"instruction_addr",
                                  @"symbol_addr": @"symbol_addr",
                                  @"platform": @"platform",
                                  @"lineno": @(100),
                                  @"colno": @(200)};
    XCTAssertEqualObjects([frame2 serialize], serialized2);
}

- (void)testEvent {
    NSDate *date = [NSDate date];
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityInfo];
    event.timestamp = date;
    event.environment = @"bla";
    event.infoDict = @{@"CFBundleIdentifier": @"a", @"CFBundleShortVersionString": @"b", @"CFBundleVersion": @"c"};
    event.extra = @{@"__vicrab_stacktrace": @"f", @"date": date};
    NSDictionary *serialized = @{@"contexts": [[[VicrabContext alloc] init] serialize],
                                 @"event_id": event.eventId,
                                 @"extra": @{@"date": [date vicrab_toIso8601String]},
                                 @"level": @"info",
                                 @"environment": @"bla",
                                 @"platform": @"cocoa",
                                 @"release": @"a-b",
                                 @"dist": @"c",
                                 @"sdk": @{@"name": @"vicrab-cocoa", @"version": VicrabClient.versionString},
                                 @"timestamp": [date vicrab_toIso8601String]};
    XCTAssertEqualObjects([event serialize], serialized);

    VicrabEvent *event2 = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityInfo];
    event2.timestamp = date;
    NSDictionary *serialized2 = @{@"contexts": [[[VicrabContext alloc] init] serialize],
                                 @"event_id": event2.eventId,
                                 @"level": @"info",
                                 @"platform": @"cocoa",
                                 @"sdk": @{@"name": @"vicrab-cocoa", @"version": VicrabClient.versionString},
                                 @"timestamp": [date vicrab_toIso8601String]};
    XCTAssertEqualObjects([event2 serialize], serialized2);
    
    VicrabEvent *event3 = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityInfo];
    event3.timestamp = date;
    event3.sdk = @{@"version": @"0.15.2", @"name": @"vicrab-react-native", @"integrations": @[@"vicrab-cocoa"]};
    NSDictionary *serialized3 = @{@"contexts": [[[VicrabContext alloc] init] serialize],
                                  @"event_id": event3.eventId,
                                  @"level": @"info",
                                  @"platform": @"cocoa",
                                  @"sdk": @{@"name": @"vicrab-react-native", @"version": @"0.15.2",
                                            @"integrations": @[@"vicrab-cocoa"]},
                                  @"timestamp": [date vicrab_toIso8601String]};
    XCTAssertEqualObjects([event3 serialize], serialized3);
}

- (void)testTransactionEvent {
    NSDate *date = [NSDate date];
    
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityInfo];
    event.timestamp = date;
    event.extra = @{@"__vicrab_transaction": @"yoyoyo"};
    event.sdk = @{@"version": @"0.15.2", @"name": @"vicrab-react-native", @"integrations": @[@"vicrab-cocoa"]};
    NSDictionary *serialized = @{@"contexts": [[[VicrabContext alloc] init] serialize],
                                 @"event_id": event.eventId,
                                 @"level": @"info",
                                 @"extra": @{},
                                 @"transaction": @"yoyoyo",
                                 @"platform": @"cocoa",
                                 @"sdk": @{@"name": @"vicrab-react-native", @"version": @"0.15.2",
                                           @"integrations": @[@"vicrab-cocoa"]},
                                 @"timestamp": [date vicrab_toIso8601String]};
    XCTAssertEqualObjects([event serialize], serialized);
    
    VicrabEvent *event3 = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityInfo];
    event3.timestamp = date;
    event3.transaction = @"UIViewControllerTest";
    event3.sdk = @{@"version": @"0.15.2", @"name": @"vicrab-react-native", @"integrations": @[@"vicrab-cocoa"]};
    NSDictionary *serialized3 = @{@"contexts": [[[VicrabContext alloc] init] serialize],
                                  @"event_id": event3.eventId,
                                  @"level": @"info",
                                  @"transaction": @"UIViewControllerTest",
                                  @"platform": @"cocoa",
                                  @"sdk": @{@"name": @"vicrab-react-native", @"version": @"0.15.2",
                                            @"integrations": @[@"vicrab-cocoa"]},
                                  @"timestamp": [date vicrab_toIso8601String]};
    XCTAssertEqualObjects([event3 serialize], serialized3);
}

- (void)testSetDistToNil {
    VicrabEvent *eventEmptyDist = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityInfo];
    eventEmptyDist.infoDict = @{@"CFBundleIdentifier": @"a", @"CFBundleShortVersionString": @"b", @"CFBundleVersion": @"c"};
    eventEmptyDist.releaseName = @"abc";
    XCTAssertNil([[eventEmptyDist serialize] objectForKey:@"dist"]);
    XCTAssertEqualObjects([[eventEmptyDist serialize] objectForKey:@"release"], @"abc");
}

- (void)testStacktrace {
    VicrabFrame *frame = [[VicrabFrame alloc] init];
    frame.symbolAddress = @"0x01";
    VicrabStacktrace *stacktrace = [[VicrabStacktrace alloc] initWithFrames:@[frame] registers:@{@"a": @"1"}];
    XCTAssertNotNil(stacktrace.frames);
    XCTAssertNotNil(stacktrace.registers);
    [stacktrace fixDuplicateFrames];
    NSDictionary *serialized = @{@"frames": @[@{@"symbol_addr": @"0x01", @"function": @"<redacted>"}],
                                 @"registers": @{@"a": @"1"}};
    XCTAssertEqualObjects([stacktrace serialize], serialized);
}

- (void)testThread {
    VicrabThread *thread = [[VicrabThread alloc] initWithThreadId:@(1)];
    XCTAssertNotNil(thread.threadId);
    NSDictionary *serialized = @{@"id": @(1)};
    XCTAssertEqualObjects([thread serialize], serialized);

    VicrabThread *thread2 = [[VicrabThread alloc] initWithThreadId:@(2)];
    XCTAssertNotNil(thread2.threadId);
    thread2.crashed = @(YES);
    thread2.current = @(NO);
    thread2.name = @"name";
    VicrabFrame *frame = [[VicrabFrame alloc] init];
    frame.symbolAddress = @"0x01";
    thread2.stacktrace = [[VicrabStacktrace alloc] initWithFrames:@[frame] registers:@{@"a": @"1"}];
    NSDictionary *serialized2 = @{
                                  @"id": @(2),
                                  @"crashed": @(YES),
                                  @"current": @(NO),
                                  @"name": @"name",
                                  @"stacktrace": @{@"frames": @[@{@"symbol_addr": @"0x01", @"function": @"<redacted>"}],
                                                   @"registers": @{@"a": @"1"}}
                                  };
    XCTAssertEqualObjects([thread2 serialize], serialized2);
}

- (void)testUser {
    VicrabUser *user = [[VicrabUser alloc] init];
    user.userId = @"1";
    XCTAssertNotNil(user.userId);
    NSDictionary *serialized = @{@"id": @"1"};
    XCTAssertEqualObjects([user serialize], serialized);

    VicrabUser *user2 = [[VicrabUser alloc] init];
    user2.userId = @"1";
    XCTAssertNotNil(user2.userId);
    user2.email = @"a@b.com";
    user2.username = @"tony";
    user2.extra = @{@"test": @"a"};
    NSDictionary *serialized2 = @{
                                  @"id": @"1",
                                  @"email": @"a@b.com",
                                  @"username": @"tony",
                                  @"extra": @{@"test": @"a"}
                                  };
    XCTAssertEqualObjects([user2 serialize], serialized2);
}

- (void)testException {
    VicrabException *exception = [[VicrabException alloc] initWithValue:@"value" type:@"type"];
    XCTAssertNotNil(exception.value);
    XCTAssertNotNil(exception.type);
    NSDictionary *serialized = @{
                                 @"value": @"value",
                                 @"type": @"type",
                                 };
    XCTAssertEqualObjects([exception serialize], serialized);

    VicrabException *exception2 = [[VicrabException alloc] initWithValue:@"value" type:@"type"];
    XCTAssertNotNil(exception2.value);
    XCTAssertNotNil(exception2.type);

    VicrabThread *thread2 = [[VicrabThread alloc] initWithThreadId:@(2)];
    XCTAssertNotNil(thread2.threadId);
    thread2.crashed = @(YES);
    thread2.current = @(NO);
    thread2.name = @"name";
    VicrabFrame *frame = [[VicrabFrame alloc] init];
    frame.symbolAddress = @"0x01";
    thread2.stacktrace = [[VicrabStacktrace alloc] initWithFrames:@[frame] registers:@{@"a": @"1"}];

    exception2.thread = thread2;
    exception2.mechanism = [[VicrabMechanism alloc] initWithType:@"test"];
    exception2.module = @"module";
    NSDictionary *serialized2 = @{
                                 @"value": @"value",
                                 @"type": @"type",
                                 @"thread_id": @(2),
                                 @"stacktrace": @{@"frames": @[@{@"symbol_addr": @"0x01", @"function": @"<redacted>"}],
                                                  @"registers": @{@"a": @"1"}},
                                 @"module": @"module",
                                 @"mechanism": @{@"type": @"test"}
                                 };

    XCTAssertEqualObjects([exception2 serialize], serialized2);
}

- (void)testContext {
    VicrabContext *context = [[VicrabContext alloc] init];
    XCTAssertNotNil(context);
    XCTAssertEqual([context serialize].count, (unsigned long)3);
}

- (void)testBreadcrumb {
    VicrabBreadcrumb *crumb = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityInfo category:@"http"];
    XCTAssertTrue(crumb.level >= 0);
    XCTAssertNotNil(crumb.category);
    NSDate *date = [NSDate date];
    crumb.timestamp = date;
    NSDictionary *serialized = @{
                                 @"level": @"info",
                                 @"timestamp": [date vicrab_toIso8601String],
                                 @"category": @"http",
                                 };
    XCTAssertEqualObjects([crumb serialize], serialized);

    VicrabBreadcrumb *crumb2 = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityInfo category:@"http"];
    XCTAssertTrue(crumb2.level >= 0);
    XCTAssertNotNil(crumb2.category);
    crumb2.data = @{@"bla": @"1"};
    crumb2.type = @"type";
    crumb2.timestamp = date;
    crumb2.message = @"message";
    NSDictionary *serialized2 = @{
                                 @"level": @"info",
                                 @"type": @"type",
                                 @"message": @"message",
                                 @"timestamp": [date vicrab_toIso8601String],
                                 @"category": @"http",
                                 @"data": @{@"bla": @"1"},
                                 };
    XCTAssertEqualObjects([crumb2 serialize], serialized2);
}

- (void)testBreadcrumbStore {
    VicrabBreadcrumbStore *store = [[VicrabBreadcrumbStore alloc] initWithFileManager:[[VicrabFileManager alloc] initWithDsn:[[VicrabDsn alloc] initWithString:@"https://username:password@app.getvicrab.com/12345" didFailWithError:nil] didFailWithError:nil]];
    [store clear];
    VicrabBreadcrumb *crumb = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityInfo category:@"http"];
    [store addBreadcrumb:crumb];
    NSDate *date = [NSDate date];
    crumb.timestamp = date;
    NSDictionary *serialized = @{
                                 @"breadcrumbs": @[
                                        @{
                                            @"level": @"info",
                                            @"category": @"http",
                                            @"timestamp": [date vicrab_toIso8601String]
                                            }
                                        ]
                                 };
    XCTAssertEqualObjects([store serialize], serialized);
    [store clear];
}

- (void)testEventSdkIntegrations {
    NSDate *date = [NSDate date];
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityInfo];
    event.timestamp = date;
    event.environment = @"bla";
    event.infoDict = @{@"CFBundleIdentifier": @"a", @"CFBundleShortVersionString": @"b", @"CFBundleVersion": @"c"};
    event.extra = @{@"__vicrab_stacktrace": @"f", @"__vicrab_sdk_integrations": @[@"react-native"]};
    NSDictionary *serialized = @{@"contexts": [[[VicrabContext alloc] init] serialize],
                                 @"event_id": event.eventId,
                                 @"extra": [NSDictionary new],
                                 @"level": @"info",
                                 @"environment": @"bla",
                                 @"platform": @"cocoa",
                                 @"release": @"a-b",
                                 @"dist": @"c",
                                 @"sdk": @{@"name": @"vicrab-cocoa", @"version": VicrabClient.versionString, @"integrations": @[@"react-native"]},
                                 @"timestamp": [date vicrab_toIso8601String]};
    XCTAssertEqualObjects([event serialize], serialized);

}

@end
