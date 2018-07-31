//
//  VicrabBreadcrumbs.m
//  Vicrab
//
//  Created by Daniel Griesser on 22/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Vicrab/Vicrab.h>
#import "VicrabBreadcrumbStore.h"
#import "VicrabFileManager.h"
#import "NSDate+Extras.h"
#import "VicrabDsn.h"
#import "NSDate+Extras.h"

@interface VicrabBreadcrumbTests : XCTestCase

@property (nonatomic, strong) VicrabFileManager *fileManager;

@end

@implementation VicrabBreadcrumbTests

- (void)setUp {
    [super setUp];
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


- (void)testFailAdd {
    VicrabBreadcrumbStore *breadcrumbStore = [[VicrabBreadcrumbStore alloc] initWithFileManager:self.fileManager];
    [breadcrumbStore addBreadcrumb:[self getBreadcrumb]];
}

- (void)testAddBreadcumb {
    NSError *error = nil;
    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"https://username:password@app.getvicrab.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    [client.breadcrumbs clear];
    [client.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
    XCTAssertEqual(client.breadcrumbs.count, (unsigned long)1);
}

- (void)testBreadcumbLimit {
    NSError *error = nil;
    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"https://username:password@app.getvicrab.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    [client.breadcrumbs clear];
    for (NSInteger i = 0; i <= 100; i++) {
        [client.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
    }
    XCTAssertEqual(client.breadcrumbs.count, (unsigned long)50);
    
    [client.breadcrumbs clear];
    for (NSInteger i = 0; i < 49; i++) {
        [client.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
    }
    XCTAssertEqual(client.breadcrumbs.count, (unsigned long)49);
    [client.breadcrumbs serialize];
    XCTAssertEqual(client.breadcrumbs.count, (unsigned long)49);
    
    [client.breadcrumbs clear];
    for (NSInteger i = 0; i < 51; i++) {
        [client.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
    }
    XCTAssertEqual(client.breadcrumbs.count, (unsigned long)50);
}

- (void)testClearBreadcumb {
    NSError *error = nil;
    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"https://username:password@app.getvicrab.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    [client.breadcrumbs clear];
    [client.breadcrumbs addBreadcrumb:[self getBreadcrumb]];
    [client.breadcrumbs clear];
    XCTAssertTrue(client.breadcrumbs.count == 0);
}

- (void)testSerialize {
    NSError *error = nil;
    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"https://username:password@app.getvicrab.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    VicrabBreadcrumb *crumb = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityDebug category:@"http"];
    NSDate *date = [NSDate date];
    crumb.timestamp = date;
    crumb.data = @{@"data": date, @"dict": @{@"date": date}};
    [client.breadcrumbs addBreadcrumb:crumb];
    NSDictionary *serialized = @{@"breadcrumbs": @[@{
                                 @"category": @"http",
                                 @"data": @{
                                         @"data": [date vicrab_toIso8601String],
                                         @"dict": @{
                                                 @"date": [date vicrab_toIso8601String]
                                                 }
                                         },
                                 @"level": @"debug",
                                 @"timestamp": [date vicrab_toIso8601String]
                                 }]
                                 };
    XCTAssertEqualObjects([client.breadcrumbs serialize], serialized);
}

- (void)testSerializeSorted {
    NSError *error = nil;
    VicrabClient *client = [[VicrabClient alloc] initWithDsn:@"https://username:password@app.getvicrab.com/12345" didFailWithError:&error];
    XCTAssertNil(error);
    VicrabBreadcrumb *crumb = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityDebug category:@"http"];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:10];
    crumb.timestamp = date;
    [client.breadcrumbs addBreadcrumb:crumb];
    
    VicrabBreadcrumb *crumb2 = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityDebug category:@"http"];
    NSDate *date2 = [NSDate dateWithTimeIntervalSince1970:899990];
    crumb2.timestamp = date2;
    [client.breadcrumbs addBreadcrumb:crumb2];
    
    VicrabBreadcrumb *crumb3 = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityDebug category:@"http"];
    NSDate *date3 = [NSDate dateWithTimeIntervalSince1970:5];
    crumb3.timestamp = date3;
    [client.breadcrumbs addBreadcrumb:crumb3];
    
    VicrabBreadcrumb *crumb4 = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityDebug category:@"http"];
    NSDate *date4 = [NSDate dateWithTimeIntervalSince1970:11];
    crumb4.timestamp = date4;
    [client.breadcrumbs addBreadcrumb:crumb4];
    
    NSDictionary *serialized = [client.breadcrumbs serialize];
    NSArray *dates = [serialized valueForKeyPath:@"breadcrumbs.timestamp"];
    XCTAssertTrue([[dates objectAtIndex:0] isEqualToString:[date vicrab_toIso8601String]]);
    XCTAssertTrue([[dates objectAtIndex:1] isEqualToString:[date2 vicrab_toIso8601String]]);
    XCTAssertTrue([[dates objectAtIndex:2] isEqualToString:[date3 vicrab_toIso8601String]]);
    XCTAssertTrue([[dates objectAtIndex:3] isEqualToString:[date4 vicrab_toIso8601String]]);
}

- (VicrabBreadcrumb *)getBreadcrumb {
    return [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityDebug category:@"http"];
}

@end
