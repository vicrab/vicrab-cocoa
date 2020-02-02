//
//  VicrabFileManagerTests.m
//  Vicrab
//
//  Created by Daniel Griesser on 23/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Vicrab/Vicrab.h>
#import "VicrabFileManager.h"
#import "VicrabDsn.h"

@interface VicrabFileManagerTests : XCTestCase

@property (nonatomic, strong) VicrabFileManager *fileManager;

@end

@implementation VicrabFileManagerTests

- (void)setUp {
    [super setUp];
    VicrabClient.logLevel = kVicrabLogLevelDebug;
    NSError *error = nil;
    self.fileManager = [[VicrabFileManager alloc] initWithDsn:[[VicrabDsn alloc] initWithString:@"https://username:password@app.getvicrab.com/12345" didFailWithError:nil] didFailWithError:&error];
    XCTAssertNil(error);
}

- (void)tearDown {
    [super tearDown];
    VicrabClient.logLevel = kVicrabLogLevelError;
    [self.fileManager deleteAllStoredEvents];
    [self.fileManager deleteAllStoredBreadcrumbs];
    [self.fileManager deleteAllFolders];
}

- (void)testEventStoring {
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityInfo];
    [self.fileManager storeEvent:event];
    NSArray<NSDictionary<NSString *, NSData *>*> *events = [self.fileManager getAllStoredEvents];
    XCTAssertTrue(events.count == 1);
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[event serialize]
                                                       options:0
                                                         error:nil];
    XCTAssertEqualObjects(((NSDictionary *)events.firstObject)[@"data"], jsonData);
}

- (void)testEventDataStoring {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{@"id": @"1234"}
                                                       options:0
                                                         error:nil];
    VicrabEvent *event = [[VicrabEvent alloc] initWithJSON:jsonData];
    [self.fileManager storeEvent:event];
    NSArray<NSDictionary<NSString *, NSData *>*> *events = [self.fileManager getAllStoredEvents];
    XCTAssertTrue(events.count == 1);
    XCTAssertEqualObjects(((NSDictionary *)events.firstObject)[@"data"], jsonData);
}

- (void)testEventStore {
    NSError *error = nil;
    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"https://username:password@app.getvicrab.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityInfo];
    [client storeEvent:event];
    NSArray<NSDictionary<NSString *, NSData *>*> *events = [self.fileManager getAllStoredEvents];
    XCTAssertTrue(events.count == 1);
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[event serialize]
                                                       options:0
                                                         error:nil];
    XCTAssertEqualObjects(((NSDictionary *)events.firstObject)[@"data"], jsonData);
}

- (void)testBreadcrumbStoring {
    VicrabBreadcrumb *crumb = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityInfo category:@"category"];
    [self.fileManager storeBreadcrumb:crumb];
    NSArray<NSDictionary<NSString *, NSData *>*> *crumbs = [self.fileManager getAllStoredBreadcrumbs];
    XCTAssertTrue(crumbs.count == 1);
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[crumb serialize]
                                                       options:0
                                                         error:nil];
    XCTAssertEqualObjects(((NSDictionary *)crumbs.firstObject)[@"data"], jsonData);
}

- (void)testCreateDir {
    NSError *error = nil;
    [VicrabFileManager createDirectoryAtPath:@"a" withError:&error];
    XCTAssertNil(error);
}

- (void)testAllFilesInFolder {
    NSArray<NSString *> *files = [self.fileManager allFilesInFolder:@"x"];
    XCTAssertTrue(files.count == 0);
}

- (void)testDeleteFileNotExsists {
    XCTAssertFalse([self.fileManager removeFileAtPath:@"x"]);
}

- (void)testFailingStoreDictionary {
    [self.fileManager storeDictionary:@{@"date": [NSDate date]} toPath:@""];
    NSArray<NSString *> *files = [self.fileManager allFilesInFolder:@"x"];
    XCTAssertTrue(files.count == 0);
}

- (void)testEventStoringHardLimit {
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityInfo];
    for (NSInteger i = 0; i <= 20; i++) {
        [self.fileManager storeEvent:event];
    }
    NSArray<NSDictionary<NSString *, NSData *>*> *events = [self.fileManager getAllStoredEvents];
    XCTAssertEqual(events.count, (unsigned long)10);
}

- (void)testBreadcrumbStoringHardLimit {
    VicrabBreadcrumb *crumb = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityInfo category:@"category"];
    for (NSInteger i = 0; i <= 210; i++) {
        [self.fileManager storeBreadcrumb:crumb];
    }
    NSArray<NSDictionary<NSString *, NSData *>*> *crumbs = [self.fileManager getAllStoredBreadcrumbs];
    XCTAssertEqual(crumbs.count, (unsigned long)200);
}

- (void)testEventStoringHardLimitSet {
    self.fileManager.maxEvents = 15;
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityInfo];
    for (NSInteger i = 0; i <= 20; i++) {
        [self.fileManager storeEvent:event];
    }
    NSArray<NSDictionary<NSString *, NSData *>*> *events = [self.fileManager getAllStoredEvents];
    XCTAssertEqual(events.count, (unsigned long)15);
}

- (void)testBreadcrumbStoringHardLimitSet {
    self.fileManager.maxBreadcrumbs = 205;
    VicrabBreadcrumb *crumb = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityInfo category:@"category"];
    for (NSInteger i = 0; i <= 210; i++) {
        [self.fileManager storeBreadcrumb:crumb];
    }
    NSArray<NSDictionary<NSString *, NSData *>*> *crumbs = [self.fileManager getAllStoredBreadcrumbs];
    XCTAssertEqual(crumbs.count, (unsigned long)205);
}

- (void)testEventLimitOverClient {
    NSError *error = nil;
    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"https://username:password@app.getvicrab.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityInfo];
    client.maxEvents = 16;
    for (NSInteger i = 0; i <= 20; i++) {
        [client storeEvent:event];
    }
    NSArray<NSDictionary<NSString *, NSData *>*> *events = [self.fileManager getAllStoredEvents];
    XCTAssertEqual(events.count, (unsigned long)16);
}

@end
