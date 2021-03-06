//
//  VicrabNSDataCompressionTests.m
//  Vicrab
//
//  Created by Daniel Griesser on 08/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Vicrab/Vicrab.h>
#import "NSData+VicrabCompression.h"

@interface VicrabNSDataCompressionTests : XCTestCase

@end

@implementation VicrabNSDataCompressionTests

- (void)testCompress {
    NSUInteger numBytes = 1000000;
    NSMutableData *data = [NSMutableData dataWithCapacity:numBytes];
    for (NSUInteger i = 0; i < numBytes; i++) {
        unsigned char byte = (unsigned char) i;
        [data appendBytes:&byte length:1];
    }

    NSError *error = nil;
    NSData *original = [NSData dataWithData:data];
    NSData *compressed = [original vicrab_gzippedWithCompressionLevel:-1 error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(compressed);
}

- (void)testCompressEmpty {
    NSError *error = nil;
    NSData *original = [NSData data];
    NSData *compressed = [original vicrab_gzippedWithCompressionLevel:-1 error:&error];
    XCTAssertNil(error, @"");

    XCTAssertEqualObjects(compressed, original, @"");
}

- (void)testCompressNilError {
    NSUInteger numBytes = 1000;
    NSMutableData *data = [NSMutableData dataWithCapacity:numBytes];
    for (NSUInteger i = 0; i < numBytes; i++) {
        unsigned char byte = (unsigned char) i;
        [data appendBytes:&byte length:1];
    }

    NSData *original = [NSData dataWithData:data];
    NSData *compressed = [original vicrab_gzippedWithCompressionLevel:-1 error:nil];
    XCTAssertNotNil(compressed);
}

- (void)testCompressEmptyNilError {
    NSData *original = [NSData data];
    NSData *compressed = [original vicrab_gzippedWithCompressionLevel:-1 error:nil];

    XCTAssertEqualObjects(compressed, original, @"");
}

- (void)testBogusParamerte {
    NSUInteger numBytes = 1000;
    NSMutableData *data = [NSMutableData dataWithCapacity:numBytes];
    for (NSUInteger i = 0; i < numBytes; i++) {
        unsigned char byte = (unsigned char) i;
        [data appendBytes:&byte length:1];
    }

    NSError *error = nil;
    NSData *original = [NSData dataWithData:data];
    NSData *compressed = [original vicrab_gzippedWithCompressionLevel:INT_MAX error:&error];
    XCTAssertNil(compressed);
    XCTAssertNotNil(error);
}

@end
