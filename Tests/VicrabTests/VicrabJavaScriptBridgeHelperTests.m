//
//  VicrabJavaScriptBridgeHelperTests.m
//  VicrabTests
//
//  Created by Daniel Griesser on 23.10.17.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "VicrabJavaScriptBridgeHelper.h"
#import <Vicrab/Vicrab.h>

NSString *rnReportPath = @"";

@interface VicrabJavaScriptBridgeHelper()

+ (NSArray *)parseJavaScriptStacktrace:(NSString *)stacktrace;
+ (NSArray *)parseRavenFrames:(NSArray *)ravenFrames;
+ (NSArray<VicrabFrame *> *)convertReactNativeStacktrace:(NSArray *)stacktrace;
+ (void)addExceptionToEvent:(VicrabEvent *)event type:(NSString *)type value:(NSString *)value frames:(NSArray *)frames;
+ (VicrabSeverity)vicrabSeverityFromLevel:(NSString *)level;

@end

@interface VicrabJavaScriptBridgeHelperTests : XCTestCase

@end

@implementation VicrabJavaScriptBridgeHelperTests

- (void)testVicrabSeverityFromLevel {
    XCTAssertEqual([VicrabJavaScriptBridgeHelper vicrabSeverityFromLevel:nil], kVicrabSeverityError);
    XCTAssertEqual([VicrabJavaScriptBridgeHelper vicrabSeverityFromLevel:@"log"], kVicrabSeverityInfo);
    XCTAssertEqual([VicrabJavaScriptBridgeHelper vicrabSeverityFromLevel:@"info"], kVicrabSeverityInfo);
    XCTAssertEqual([VicrabJavaScriptBridgeHelper vicrabSeverityFromLevel:@"bla"], kVicrabSeverityError);
    XCTAssertEqual([VicrabJavaScriptBridgeHelper vicrabSeverityFromLevel:@"error"], kVicrabSeverityError);
    XCTAssertEqual([VicrabJavaScriptBridgeHelper vicrabSeverityFromLevel:@"fatal"], kVicrabSeverityFatal);
    XCTAssertEqual([VicrabJavaScriptBridgeHelper vicrabSeverityFromLevel:@"debug"], kVicrabSeverityDebug);
    XCTAssertEqual([VicrabJavaScriptBridgeHelper vicrabSeverityFromLevel:@"warning"], kVicrabSeverityWarning);
}

- (void)testSanitizeDictionary {
    VicrabFrame *frame = [[VicrabFrame alloc] init];
    frame.symbolAddress = @"0x01";
    NSDictionary *result =  @{@"yo": [NSString stringWithFormat:@"%@", frame]};
    XCTAssertEqualObjects([VicrabJavaScriptBridgeHelper sanitizeDictionary:@{@"yo": frame}], result);
}

- (void)testCreateVicrabUser {
    for (NSString *userIdKey in @[@"id", @"userId", @"userID"]) {
        VicrabUser *user1 = [VicrabJavaScriptBridgeHelper createVicrabUserFromJavaScriptUser:@{userIdKey: @"1"}];
        VicrabUser *user1Expectation = [[VicrabUser alloc] initWithUserId:@"1"];
        XCTAssertEqualObjects(user1.userId, user1Expectation.userId);
        XCTAssertNil(user1.username);
        XCTAssertNil(user1.email);
        XCTAssertNil(user1.extra);
    }
    
    VicrabUser *user2 = [VicrabJavaScriptBridgeHelper createVicrabUserFromJavaScriptUser:@{@"username": @"user"}];
    VicrabUser *user2Expectation = [[VicrabUser alloc] init];
    user2Expectation.username = @"user";
    XCTAssertEqualObjects(user2.username, user2Expectation.username);
    XCTAssertNil(user2.userId);
    XCTAssertNil(user2.email);
    XCTAssertNil(user2.extra);
    
    VicrabUser *user3 = [VicrabJavaScriptBridgeHelper createVicrabUserFromJavaScriptUser:@{@"email": @"email"}];
    VicrabUser *user3Expectation = [[VicrabUser alloc] init];
    user3Expectation.email = @"email";
    XCTAssertEqualObjects(user3.email, user3Expectation.email);
    XCTAssertNil(user3.userId);
    XCTAssertNil(user3.username);
    XCTAssertNil(user3.extra);
    
    VicrabUser *user4 = [VicrabJavaScriptBridgeHelper createVicrabUserFromJavaScriptUser:@{@"email": @"email", @"extra":  @{@"yo": @"foo"}}];
    VicrabUser *user4Expectation = [[VicrabUser alloc] init];
    user4Expectation.email = @"email";
    XCTAssertEqualObjects(user4.email, user4Expectation.email);
    XCTAssertEqualObjects(user4.extra, @{@"yo": @"foo"});
    XCTAssertNil(user4.userId);
    XCTAssertNil(user4.username);
    
    VicrabUser *user5 = [VicrabJavaScriptBridgeHelper createVicrabUserFromJavaScriptUser:@{@"extra":  @{@"yo": @"foo"}}];
    XCTAssertNil(user5);
}

- (void)testLogLevel {
    XCTAssertEqual([VicrabJavaScriptBridgeHelper vicrabLogLevelFromJavaScriptLevel:0], kVicrabLogLevelNone);
    XCTAssertEqual([VicrabJavaScriptBridgeHelper vicrabLogLevelFromJavaScriptLevel:1], kVicrabLogLevelError);
    XCTAssertEqual([VicrabJavaScriptBridgeHelper vicrabLogLevelFromJavaScriptLevel:2], kVicrabLogLevelDebug);
    XCTAssertEqual([VicrabJavaScriptBridgeHelper vicrabLogLevelFromJavaScriptLevel:3], kVicrabLogLevelVerbose);
}

- (void)testCreateBreadcrumb {
    VicrabBreadcrumb *crumb1 = [VicrabJavaScriptBridgeHelper createVicrabBreadcrumbFromJavaScriptBreadcrumb:@{
                                                                                                             @"message": @"test",
                                                                                                             @"category": @"action"
                                                                                                             }];
    XCTAssertEqualObjects(crumb1.message, @"test");
    XCTAssertEqualObjects(crumb1.category, @"action");
    XCTAssertNotNil(crumb1.timestamp, @"timestamp");
    
    NSDate *date = [NSDate date];
    VicrabBreadcrumb *crumb2 = [VicrabJavaScriptBridgeHelper createVicrabBreadcrumbFromJavaScriptBreadcrumb:@{
                                                                                                              @"message": @"test",
                                                                                                              @"category": @"action",
                                                                                                              @"timestamp": [NSString stringWithFormat:@"%ld", (long)date.timeIntervalSince1970],
                                                                                                              }];
    XCTAssertEqualObjects(crumb2.message, @"test");
    XCTAssertEqual(crumb2.level, kVicrabSeverityInfo);
    XCTAssertEqualObjects(crumb2.category, @"action");
    XCTAssertTrue([crumb2.timestamp compare:date]);
    
    VicrabBreadcrumb *crumb3 = [VicrabJavaScriptBridgeHelper createVicrabBreadcrumbFromJavaScriptBreadcrumb:@{
                                                                                                              @"message": @"test",
                                                                                                              @"category": @"action",
                                                                                                              @"timestamp": @""
                                                                                                              }];
    XCTAssertEqualObjects(crumb3.message, @"test");
    XCTAssertEqualObjects(crumb3.category, @"action");
    XCTAssertNotNil(crumb3.timestamp, @"timestamp");
}

- (NSDictionary *)getCrashReport {
    NSString *jsonPath = [[NSBundle bundleForClass:self.class] pathForResource:rnReportPath ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:jsonPath]];
    return [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
}

- (void)testCreateEvent {
    rnReportPath = @"Resources/raven-sendMessage";
    VicrabEvent *vicrabEvent1 = [VicrabJavaScriptBridgeHelper createVicrabEventFromJavaScriptEvent:[self getCrashReport]];
    XCTAssertEqualObjects(vicrabEvent1.message, @"TEST message");
    XCTAssertNotNil(vicrabEvent1.extra);
    XCTAssertNotNil(vicrabEvent1.tags);
    XCTAssertNotNil(vicrabEvent1.user);
 
    rnReportPath = @"Resources/raven-rejectedpromise";
    VicrabEvent *vicrabEvent2 = [VicrabJavaScriptBridgeHelper createVicrabEventFromJavaScriptEvent:[self getCrashReport]];
    XCTAssertEqualObjects(vicrabEvent2.message, @"Boom promise");
    XCTAssertEqualObjects(vicrabEvent2.platform, @"cocoa");
    XCTAssertEqualObjects(vicrabEvent2.exceptions.firstObject.type, @"Unhandled Promise Rejection");
    XCTAssertEqualObjects(vicrabEvent2.exceptions.firstObject.value, @"Boom promise");
    XCTAssertEqual(vicrabEvent2.exceptions.firstObject.thread.stacktrace.frames.count, (NSUInteger)11);
    XCTAssertEqualObjects(vicrabEvent2.exceptions.firstObject.thread.stacktrace.frames.firstObject.fileName, @"app:///index.bundle");
    XCTAssertNotNil(vicrabEvent2.extra);
    XCTAssertNotNil(vicrabEvent2.tags);
    XCTAssertNotNil(vicrabEvent2.user);
   
    rnReportPath = @"Resources/raven-throwerror";
    VicrabEvent *vicrabEvent3 = [VicrabJavaScriptBridgeHelper createVicrabEventFromJavaScriptEvent:[self getCrashReport]];
    XCTAssertEqualObjects(vicrabEvent3.exceptions.firstObject.value, @"Vicrab: Test throw error");
    XCTAssertEqualObjects(vicrabEvent3.exceptions.firstObject.type, @"Error");
    XCTAssertEqual(vicrabEvent3.exceptions.firstObject.thread.stacktrace.frames.count, (NSUInteger)30);
    XCTAssertEqualObjects(vicrabEvent3.exceptions.firstObject.thread.stacktrace.frames.firstObject.fileName, @"app:///index.bundle");
    XCTAssertNotNil(vicrabEvent3.extra);
    XCTAssertNotNil(vicrabEvent3.tags);
    XCTAssertNotNil(vicrabEvent3.user);
}

- (void)testParseJavaScriptStacktrace {
    NSString *jsStacktrace = @"enqueueNativeCall@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:61481:36\n\
    fn@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:1786:38\n\
    nativeCrash@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:61412:21\n\
    nativeCrash@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:58712:75\n\
    _nativeCrash@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:58474:44\n\
    onPress@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:58557:39\n\
    touchableHandlePress@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:38588:45\n\
    touchableHandlePress@[native code]\n\
    _performSideEffectsForTransition@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:38145:34\n\
    _performSideEffectsForTransition@[native code]\n\
    _receiveSignal@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:38082:44\n\
    _receiveSignal@[native code]\n\
    touchableHandleResponderRelease@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:37971:24\n\
    touchableHandleResponderRelease@[native code]\n\
    _invokeGuardedCallback@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:2539:23\n\
    invokeGuardedCallback@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:2513:41\n\
    invokeGuardedCallbackAndCatchFirstError@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:2516:60\n\
    executeDispatch@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:2599:132\n\
    executeDispatchesInOrder@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:2606:52\n\
    executeDispatchesAndRelease@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:6216:62\n\
    forEach@[native code]\n\
    forEachAccumulated@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:6211:41\n\
    processEventQueue@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:6282:147\n\
    runEventQueueInBatch@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:6526:83\n\
    handleTopLevel@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:6530:33\n\
    http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:6558:55\n\
    batchedUpdates@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:5637:26\n\
    batchedUpdatesWithControlledComponents@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:2706:34\n\
    _receiveRootNodeIDEvent@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:6557:50\n\
    receiveTouches@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:6572:249\n\
    __callFunction@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:2072:47\n\
    http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:1888:29\n\
    __guard@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:2043:11\n\
    callFunctionReturnFlushedQueue@http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false:1887:20";
    
    NSArray *frames = [VicrabJavaScriptBridgeHelper parseJavaScriptStacktrace:jsStacktrace];
    XCTAssertEqualObjects(frames.firstObject[@"methodName"], @"enqueueNativeCall");
    XCTAssertEqualObjects(frames.firstObject[@"lineNumber"], @61481);
    
    XCTAssertEqualObjects(frames.lastObject[@"methodName"], @"callFunctionReturnFlushedQueue");
    XCTAssertEqualObjects(frames.lastObject[@"lineNumber"], @1887);
    
    XCTAssertEqualObjects([frames objectAtIndex:7][@"file"], @"[native code]");
    XCTAssertEqualObjects([frames objectAtIndex:7][@"methodName"], @"touchableHandlePress");
    XCTAssertNil([frames objectAtIndex:7][@"lineNumber"]);
    
    XCTAssertEqual(frames.count, (NSUInteger)32);
}

- (void)testConvertReactNativeStacktrace {
    NSArray *frames1 = [VicrabJavaScriptBridgeHelper convertReactNativeStacktrace:@[@{
                                                                                       @"file": @"file:///index.js",
                                                                                       @"lineNumber": @"11",
                                                                                       @"column": @"1"
                                                                                       }]];
    
    XCTAssertEqual(frames1.count, (NSUInteger)0);
    
    NSArray *frames2 = [VicrabJavaScriptBridgeHelper convertReactNativeStacktrace:@[@{
                                                                                        @"methodName": @"1",
                                                                                        @"file": @"file:///index.js",
                                                                                        @"lineNumber": @"1",
                                                                                        @"column": @"1"
                                                                                        }, @{
                                                                                        @"methodName": @"2",
                                                                                        @"file": @"file:///index.js",
                                                                                        @"lineNumber": @"2",
                                                                                        @"column": @"2"
                                                                                        }]];
    
    XCTAssertEqual(frames2.count, (NSUInteger)2);
    XCTAssertEqualObjects(((VicrabFrame *)[frames2 objectAtIndex:0]).function, @"2");
    XCTAssertEqualObjects(((VicrabFrame *)[frames2 objectAtIndex:0]).fileName, @"app:///index.js");
    XCTAssertEqualObjects(((VicrabFrame *)[frames2 objectAtIndex:0]).lineNumber, @"2");
    XCTAssertEqualObjects(((VicrabFrame *)[frames2 objectAtIndex:0]).columnNumber, @"2");
}

- (void)testCordovaEvent {
    rnReportPath = @"Resources/cordova-exception";
    VicrabEvent *vicrabEvent1 = [VicrabJavaScriptBridgeHelper createVicrabEventFromJavaScriptEvent:[self getCrashReport]];
    XCTAssertNotNil(vicrabEvent1.exceptions);
}

@end
