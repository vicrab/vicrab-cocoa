//
//  VicrabRequestTests.m
//  Vicrab
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Vicrab/Vicrab.h>
#import "VicrabQueueableRequestManager.h"
#import "VicrabFileManager.h"
#import "NSDate+VicrabExtras.h"
#import "VicrabClient+Internal.h"

NSInteger requestShouldReturnCode = 200;
NSString *dsn = @"https://username:password@app.getvicrab.com/12345";

@interface VicrabClient (Private)

- (_Nullable instancetype)initWithOptions:(NSDictionary<NSString *, id> *)options
                           requestManager:(id <VicrabRequestManager>)requestManager
                         didFailWithError:(NSError *_Nullable *_Nullable)error;

@end

@interface VicrabMockNSURLSessionDataTask: NSURLSessionDataTask

@property (nonatomic, assign) BOOL isCancelled;
@property (nonatomic, copy) void (^completionHandler)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable);

@end

@implementation VicrabMockNSURLSessionDataTask

- (instancetype)initWithCompletionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    self = [super init];
    if (self) {
        self.completionHandler = completionHandler;
        self.isCancelled = NO;
    }
    return self;
}

- (void)resume {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.isCancelled) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[[NSURL alloc] initWithString:dsn] statusCode:requestShouldReturnCode HTTPVersion:nil headerFields:nil];
            if (requestShouldReturnCode != 200) {
                self.completionHandler(nil, response, [NSError errorWithDomain:@"" code:requestShouldReturnCode userInfo:nil]);
            } else {
                self.completionHandler(nil, response, nil);
            }
        }
    });
}

- (void)cancel {
    self.isCancelled = YES;
    self.completionHandler(nil, nil, [NSError errorWithDomain:@"" code:1 userInfo:nil]);
}

@end

@interface VicrabMockNSURLSession: NSURLSession

@end

@implementation VicrabMockNSURLSession

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    return [[VicrabMockNSURLSessionDataTask alloc] initWithCompletionHandler:completionHandler];
}
#pragma GCC diagnostic pop

@end

@interface VicrabMockRequestManager : NSObject <VicrabRequestManager>

@property(nonatomic, strong) NSOperationQueue *queue;
@property(nonatomic, strong) VicrabMockNSURLSession *session;
@property(nonatomic, strong) VicrabRequestOperation *lastOperation;
@property(nonatomic, assign) NSInteger requestsSuccessfullyFinished;
@property(nonatomic, assign) NSInteger requestsWithErrors;

@end

@implementation VicrabMockRequestManager

- (instancetype)initWithSession:(VicrabMockNSURLSession *)session {
    self = [super init];
    if (self) {
        self.session = session;
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.name = @"io.vicrab.VicrabMockRequestManager.OperationQueue";
        self.queue.maxConcurrentOperationCount = 3;
        self.requestsWithErrors = 0;
        self.requestsSuccessfullyFinished = 0;
    }
    return self;
}

- (BOOL)isReady {
    return self.queue.operationCount <= 1;
}

- (void)addRequest:(NSURLRequest *)request completionHandler:(_Nullable VicrabRequestOperationFinished)completionHandler {
    if (request.allHTTPHeaderFields[@"X-TEST"]) {
        if (completionHandler) {
            completionHandler(nil, [NSError errorWithDomain:@"" code:9898 userInfo:nil]);
            return;
        }
    }

    self.lastOperation = [[VicrabRequestOperation alloc] initWithSession:self.session
                                                                                request:request
                                                                      completionHandler:^(NSHTTPURLResponse *_Nullable response, NSError * _Nullable error) {
                                                                          [VicrabLog logWithMessage:[NSString stringWithFormat:@"Queued requests: %lu", (unsigned long)(self.queue.operationCount - 1)] andLevel:kVicrabLogLevelDebug];
                                                                          if ([response statusCode] != 200) {
                                                                              self.requestsWithErrors++;
                                                                          } else {
                                                                              self.requestsSuccessfullyFinished++;
                                                                          }
                                                                          if (completionHandler) {
                                                                              completionHandler(response, error);
                                                                          }
                                                                      }];
    [self.queue addOperation:self.lastOperation];
    // leave this here, we ask for it because NSOperation isAsynchronous
    // because it needs to be overwritten
    NSLog(@"%d", self.lastOperation.isAsynchronous);
}

- (void)cancelAllOperations {
    [self.queue cancelAllOperations];
}

- (void)restart {
    [self.lastOperation start];
}

@end

@interface VicrabRequestTests : XCTestCase

@property(nonatomic, strong) VicrabClient *client;
@property(nonatomic, strong) VicrabMockRequestManager *requestManager;
@property(nonatomic, strong) VicrabEvent *event;

@end

@implementation VicrabRequestTests

- (void)clearAllFiles {
    NSError *error = nil;
    VicrabFileManager *fileManager = [[VicrabFileManager alloc] initWithDsn:[[VicrabDsn alloc] initWithString:dsn didFailWithError:nil] didFailWithError:&error];
    [fileManager deleteAllStoredEvents];
    [fileManager deleteAllStoredBreadcrumbs];
    [fileManager deleteAllFolders];
}

- (void)tearDown {
    [super tearDown];
    requestShouldReturnCode = 200;
    [self.client clearContext];
    [self clearAllFiles];
    [self.requestManager cancelAllOperations];
}

- (void)setUp {
    [super setUp];
    [self clearAllFiles];
    self.requestManager = [[VicrabMockRequestManager alloc] initWithSession:[VicrabMockNSURLSession new]];
    self.client = [[VicrabClient alloc] initWithOptions:@{@"dsn": dsn}
                                         requestManager:self.requestManager
                                       didFailWithError:nil];
    self.event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityDebug];
}

- (void)testRealRequest {
    VicrabQueueableRequestManager *requestManager = [[VicrabQueueableRequestManager alloc] initWithSession:[VicrabMockNSURLSession new]];
    VicrabClient *client = [[VicrabClient alloc] initWithOptions:@{@"dsn": dsn}
                                                  requestManager:requestManager
                                                didFailWithError:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    [client sendEvent:self.event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRealRequestWithMock {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    [self.client sendEvent:self.event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestFailed {
    requestShouldReturnCode = 429;

    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should fail"];
    [self.client sendEvent:self.event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestFailedSerialization {
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Request should finish1"];
    VicrabEvent *event1 = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityError];
    event1.extra = @{@"a": event1};
    [self.client sendEvent:event1 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation1 fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];

}

- (void)testRequestQueueReady {
    VicrabQueueableRequestManager *requestManager = [[VicrabQueueableRequestManager alloc] initWithSession:[VicrabMockNSURLSession new]];
    VicrabClient *client = [[VicrabClient alloc] initWithOptions:@{@"dsn": dsn}
                                                  requestManager:requestManager
                                                didFailWithError:nil];

    XCTAssertTrue(requestManager.isReady);

    [client sendEvent:self.event withCompletionHandler:NULL];

    for (NSInteger i = 0; i <= 5; i++) {
        [client sendEvent:self.event withCompletionHandler:NULL];
    }

    XCTAssertFalse(requestManager.isReady);
}

- (void)testRequestQueueCancel {
    VicrabClient.logLevel = kVicrabLogLevelVerbose;
    VicrabQueueableRequestManager *requestManager = [[VicrabQueueableRequestManager alloc] initWithSession:[VicrabMockNSURLSession new]];
    VicrabClient *client = [[VicrabClient alloc] initWithOptions:@{@"dsn": @"http://a:b@vicrab.io/1"}
                                                  requestManager:requestManager
                                                didFailWithError:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should fail"];
    [client sendEvent:self.event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation fulfill];
    }];
    [requestManager cancelAllOperations];
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
    VicrabClient.logLevel = kVicrabLogLevelError;
}

- (void)testRequestQueueCancelWithMock {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should fail"];
    [self.client sendEvent:self.event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation fulfill];
    }];
    [self.requestManager cancelAllOperations];
    [self.requestManager restart];
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestQueueWithDifferentEvents1 {
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Request should finish1"];
    VicrabEvent *event1 = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityError];
    [self.client sendEvent:event1 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestQueueWithDifferentEvents2 {
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Request should finish2"];
    VicrabEvent *event2 = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityInfo];
    [self.client sendEvent:event2 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestQueueWithDifferentEvents3 {
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Request should finish3"];
    VicrabEvent *event3 = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityFatal];
    [self.client sendEvent:event3 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation3 fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestQueueWithDifferentEvents4 {
    XCTestExpectation *expectation4 = [self expectationWithDescription:@"Request should finish4"];
    VicrabEvent *event4 = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
    [self.client sendEvent:event4 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation4 fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestQueueMultipleEvents {
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Request should finish1"];
    VicrabEvent *event1 = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityError];
    [self.client sendEvent:event1 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];

    XCTestExpectation *expectation4 = [self expectationWithDescription:@"Request should finish4"];
    VicrabEvent *event4 = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
    [self.client sendEvent:event4 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation4 fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testUseClientProperties {
    self.client.tags = @{@"a": @"b"};
    self.client.extra = @{@"c": @"d"};
    self.client.user = [[VicrabUser alloc] initWithUserId:@"XXXXXX"];
    NSDate *date = [NSDate date];
    VicrabBreadcrumb *crumb = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityInfo category:@"you"];
    crumb.timestamp = date;
    [self.client.breadcrumbs addBreadcrumb:crumb];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish4"];
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
    event.infoDict = @{@"CFBundleIdentifier": @"a", @"CFBundleShortVersionString": @"b", @"CFBundleVersion": @"c"};
    crumb.timestamp = date;
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        VicrabContext *context = [[VicrabContext alloc] init];
        NSDictionary *serialized = @{@"breadcrumbs": @[ @{
                                                            @"category": @"you",
                                                            @"level": @"info",
                                                            @"timestamp": [date vicrab_toIso8601String]
                                                            }
                                                        ],
                                     @"user": @{@"id": @"XXXXXX"},
                                     @"contexts": [context serialize],
                                     @"event_id": event.eventId,
                                     @"extra": @{@"c": @"d"},
                                     @"level": @"warning",
                                     @"platform": @"cocoa",
                                     @"release": @"a-b",
                                     @"dist": @"c",
                                     @"sdk": @{@"name": @"vicrab-cocoa", @"version": VicrabClient.versionString},
                                     @"tags": @{@"a": @"b"},
                                     @"timestamp": [date vicrab_toIso8601String]};
        XCTAssertEqualObjects([self.client.lastEvent serialize], serialized);
        [self.client.breadcrumbs clear];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testUseClientPropertiesMerge {
    self.client.tags = @{@"a": @"b"};
    self.client.extra = @{@"c": @"d"};
    NSDate *date = [NSDate date];
    VicrabBreadcrumb *crumb = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityInfo category:@"you"];
    crumb.timestamp = date;
    [self.client.breadcrumbs addBreadcrumb:crumb];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish4"];
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
    event.infoDict = @{@"CFBundleIdentifier": @"a", @"CFBundleShortVersionString": @"b", @"CFBundleVersion": @"c"};
    event.timestamp = date;
    event.tags = @{@"1": @"2"};
    event.extra = @{@"3": @"4"};
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        VicrabContext *context = [[VicrabContext alloc] init];
        NSDictionary *serialized = @{@"breadcrumbs": @[ @{
                                                            @"category": @"you",
                                                            @"level": @"info",
                                                            @"timestamp": [date vicrab_toIso8601String]
                                                            }
                                                        ],
                                     @"contexts": [context serialize],
                                     @"event_id": event.eventId,
                                     @"extra": @{@"c": @"d", @"3": @"4"},
                                     @"level": @"warning",
                                     @"platform": @"cocoa",
                                     @"release": @"a-b",
                                     @"dist": @"c",
                                     @"sdk": @{@"name": @"vicrab-cocoa", @"version": VicrabClient.versionString},
                                     @"tags": @{@"a": @"b", @"1": @"2"},
                                     @"timestamp": [date vicrab_toIso8601String]};
        XCTAssertEqualObjects([self.client.lastEvent serialize], serialized);
        [self.client.breadcrumbs clear];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}


- (void)testEventPropsAreStrongerThanClientProperties {
    self.client.tags = @{@"a": @"b"};
    self.client.extra = @{@"c": @"d"};
    NSDate *date = [NSDate date];
    VicrabBreadcrumb *crumb = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityInfo category:@"you"];
    crumb.timestamp = date;
    [self.client.breadcrumbs addBreadcrumb:crumb];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish4"];
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
    event.infoDict = @{@"CFBundleIdentifier": @"a", @"CFBundleShortVersionString": @"b", @"CFBundleVersion": @"c"};
    event.timestamp = date;
    event.tags = @{@"a": @"1"};
    event.extra = @{@"c": @"2"};
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        VicrabContext *context = [[VicrabContext alloc] init];
        NSDictionary *serialized = @{@"breadcrumbs": @[ @{
                                                            @"category": @"you",
                                                            @"level": @"info",
                                                            @"timestamp": [date vicrab_toIso8601String]
                                                            }
                                                        ],
                                     @"contexts": [context serialize],
                                     @"event_id": event.eventId,
                                     @"extra": @{@"c": @"2"},
                                     @"level": @"warning",
                                     @"platform": @"cocoa",
                                     @"release": @"a-b",
                                     @"dist": @"c",
                                     @"sdk": @{@"name": @"vicrab-cocoa", @"version": VicrabClient.versionString},
                                     @"tags": @{@"a": @"1"},
                                     @"timestamp": [date vicrab_toIso8601String]};
        XCTAssertEqualObjects([self.client.lastEvent serialize], serialized);
        [self.client.breadcrumbs clear];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestQueueWithAndFlushItAfterSuccess {
    requestShouldReturnCode = 429;
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Request should finish"];
    VicrabEvent *event1 = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityError];
    [self.client sendEvent:event1 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation1 fulfill];
    }];

    [self waitForExpectations:@[expectation1] timeout:5];
    XCTAssertEqual(self.requestManager.requestsWithErrors, 1);
    requestShouldReturnCode = 200;

    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Request should finish"];
    VicrabEvent *event2 = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityError];
    [self.client sendEvent:event2 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation2 fulfill];
    }];

    [self waitForExpectations:@[expectation2] timeout:5];
    XCTAssertEqual(self.requestManager.requestsSuccessfullyFinished, 1);
    XCTAssertEqual(self.requestManager.requestsWithErrors, 1);
    requestShouldReturnCode = 200;

    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Request should finish"];
    VicrabEvent *event3 = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityError];
    [self.client sendEvent:event3 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation3 fulfill];
    }];
    [self waitForExpectations:@[expectation3] timeout:5];

    VicrabFileManager *fileManager = [[VicrabFileManager alloc] initWithDsn:[[VicrabDsn alloc] initWithString:dsn didFailWithError:nil] didFailWithError:nil];
    [self waitForExpectations:@[[self waitUntilLocalFileQueueIsFlushed:fileManager]] timeout:5.0];
    XCTAssertEqual(self.requestManager.requestsSuccessfullyFinished, 3);
    XCTAssertEqual(self.requestManager.requestsWithErrors, 1);
}

- (XCTestExpectation *)waitUntilLocalFileQueueIsFlushed:(VicrabFileManager *)fileManager {
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait for file queue"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSInteger i = 0; i <= 100; i++) {
            NSLog(@"@@ %lu", (unsigned long)[fileManager getAllStoredEvents].count);
            if ([fileManager getAllStoredEvents].count == 0) {
                [expectation fulfill];
                return;
            }
            sleep(1);
        }
    });
    return expectation;
}

- (void)testBlockBeforeSerializeEvent {
    NSDictionary *tags = @{@"a": @"b"};
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
    self.client.beforeSerializeEvent = ^(VicrabEvent * _Nonnull event) {
        event.tags = tags;
    };
    XCTAssertNil(event.tags);
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertEqualObjects(self.client.lastEvent.tags, tags);
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testBlockBeforeSendRequest {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
    self.client.beforeSendRequest = ^(VicrabNSURLRequest * _Nonnull request) {
        [request setValue:@"12345" forHTTPHeaderField:@"X-TEST"];
    };

    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, 9898);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testSnapshotStacktrace {
    XCTestExpectation *expectationSnap = [self expectationWithDescription:@"Snapshot"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];

    VicrabThread *thread = [[VicrabThread alloc] initWithThreadId:@(9999)];
    [self.client startCrashHandlerWithError:nil];
    self.client._snapshotThreads = @[thread];

    self.client._debugMeta = @[[[VicrabDebugMeta alloc] init]];

    [self.client snapshotStacktrace:^{
        [self.client appendStacktraceToEvent:event];
        XCTAssertTrue(YES);
        [expectationSnap fulfill];
    }];

    [self waitForExpectations:@[expectationSnap] timeout:5.0];

    __weak id weakSelf = self;
    self.client.beforeSerializeEvent = ^(VicrabEvent * _Nonnull event) {
        id self = weakSelf;
        XCTAssertEqualObjects(event.threads.firstObject.threadId, @(9999));
        XCTAssertNotNil(event.debugMeta);
        XCTAssertTrue(event.debugMeta.count > 0);
    };

    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:5.0];
}

- (void)testShouldSendEventNo {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
    event.message = @"abc";
    __weak id weakSelf = self;
    self.client.shouldSendEvent = ^BOOL(VicrabEvent * _Nonnull event) {
        id self = weakSelf;
        if ([event.message isEqualToString:@"abc"]) {
            XCTAssertTrue(YES);
        } else {
            XCTAssertTrue(NO);
        }
        return NO;
    };
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testShouldSendEventYes {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
    event.message = @"abc";
    __weak id weakSelf = self;
    self.client.shouldSendEvent = ^BOOL(VicrabEvent * _Nonnull event) {
        id self = weakSelf;
        if ([event.message isEqualToString:@"abc"]) {
            XCTAssertTrue(YES);
        } else {
            XCTAssertTrue(NO);
        }
        return YES;
    };
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testSamplingZero {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
    event.message = @"abc";
    self.client.sampleRate = 0.0;
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testSamplingOne {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
    event.message = @"abc";
    self.client.sampleRate = 1.0;
    XCTAssertEqual(self.client.sampleRate, 1.0);
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testSamplingBogus {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
    event.message = @"abc";
    self.client.sampleRate = -123.0;
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testLocalFileQueueLimit {
    NSError *error = nil;
    VicrabFileManager *fileManager = [[VicrabFileManager alloc] initWithDsn:[[VicrabDsn alloc] initWithString:dsn didFailWithError:nil] didFailWithError:&error];

    requestShouldReturnCode = 429;

    NSMutableArray *expectations = [NSMutableArray new];
    for (NSInteger i = 0; i <= 20; i++) {
        XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"Request should fail %ld", (long)i]];
        VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
        event.message = @"abc";
        [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
            XCTAssertNotNil(error);
            [expectation fulfill];
        }];
        [expectations addObject:expectation];
    }
    [self waitForExpectations:expectations timeout:5.0];
    XCTAssertEqual([fileManager getAllStoredEvents].count, (unsigned long)10);
}

- (void)testDoNotRetryEvenOnce {
    NSError *error = nil;
    VicrabFileManager *fileManager = [[VicrabFileManager alloc] initWithDsn:[[VicrabDsn alloc] initWithString:dsn didFailWithError:nil] didFailWithError:&error];

    requestShouldReturnCode = 429;

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
    // We overwrite the shouldQueueEvent
    // People could implement their own maxAge or Severity check on the event
    // A simple NO will never ever try again sending a event
    self.client.shouldQueueEvent = ^BOOL(VicrabEvent * _Nonnull event, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        return NO;
    };
#pragma GCC diagnostic pop

    NSMutableArray *expectations = [NSMutableArray new];
    for (NSInteger i = 0; i <= 3; i++) {
        XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"Request should fail %ld", (long)i]];
        VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
        event.message = @"abc";
        [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
            XCTAssertNotNil(error);
            [expectation fulfill];
        }];
        [expectations addObject:expectation];
    }
    [self waitForExpectations:expectations timeout:5.0];
    XCTAssertEqual([fileManager getAllStoredEvents].count, (unsigned long)0);
}

- (void)testDisabledClient {
    NSError *error = nil;
    VicrabFileManager *fileManager = [[VicrabFileManager alloc] initWithDsn:[[VicrabDsn alloc] initWithString:dsn didFailWithError:nil] didFailWithError:&error];

    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
    event.message = @"abc";
    VicrabClient.logLevel = kVicrabLogLevelDebug;
    self.client.enabled = @NO;
    [self.client sendEvent:event withCompletionHandler:nil];

    XCTAssertEqual([fileManager getAllStoredEvents].count, (unsigned long)1);
}

@end
