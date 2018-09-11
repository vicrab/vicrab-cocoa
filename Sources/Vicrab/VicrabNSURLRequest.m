//
//  VicrabNSURLRequest.m
//  Vicrab
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabDsn.h>
#import <Vicrab/VicrabNSURLRequest.h>
#import <Vicrab/VicrabClient.h>
#import <Vicrab/VicrabEvent.h>
#import <Vicrab/VicrabError.h>
#import <Vicrab/VicrabLog.h>
#import <Vicrab/NSData+Compression.h>

#else
#import "VicrabDsn.h"
#import "VicrabNSURLRequest.h"
#import "VicrabClient.h"
#import "VicrabEvent.h"
#import "VicrabError.h"
#import "VicrabLog.h"
#import "NSData+Compression.h"

#endif

NS_ASSUME_NONNULL_BEGIN

NSString *const VicrabServerVersionString = @"7";
NSTimeInterval const VicrabRequestTimeout = 15;

@interface VicrabNSURLRequest ()

@property(nonatomic, strong) VicrabDsn *dsn;

@end

@implementation VicrabNSURLRequest

- (_Nullable instancetype)initStoreRequestWithDsn:(VicrabDsn *)dsn
                                         andEvent:(VicrabEvent *)event
                                 didFailWithError:(NSError *_Nullable *_Nullable)error {
    NSDictionary *serialized = [event serialize];
    if (![NSJSONSerialization isValidJSONObject:serialized]) {
        if (error) {
            *error = NSErrorFromVicrabError(kVicrabErrorJsonConversionError, @"Event cannot be converted to JSON");
        }
        return nil;
    }

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:serialized
                                                       options:VicrabClient.logLevel == kVicrabLogLevelVerbose ? NSJSONWritingPrettyPrinted : 0
                                                         error:error];
    
    if (VicrabClient.logLevel == kVicrabLogLevelVerbose) {
        [VicrabLog logWithMessage:@"Sending JSON -------------------------------" andLevel:kVicrabLogLevelVerbose];
        [VicrabLog logWithMessage:[NSString stringWithFormat:@"%@", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]] andLevel:kVicrabLogLevelVerbose];
        [VicrabLog logWithMessage:@"--------------------------------------------" andLevel:kVicrabLogLevelVerbose];
    }
    return [self initStoreRequestWithDsn:dsn andData:jsonData didFailWithError:error];
}

- (_Nullable instancetype)initStoreRequestWithDsn:(VicrabDsn *)dsn
                                          andData:(NSData *)data
                                 didFailWithError:(NSError *_Nullable *_Nullable)error {
    NSURL *apiURL = [self.class getStoreUrlFromDsn:dsn];
    self = [super initWithURL:apiURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:VicrabRequestTimeout];
    if (self) {
        NSString *authHeader = newAuthHeader(dsn.url);

        self.HTTPMethod = @"POST";
        [self setValue:authHeader forHTTPHeaderField:@"X-Vicrab-Auth"];
        [self setValue:@"application/json;charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        [self setValue:@"vicrab-cocoa" forHTTPHeaderField:@"User-Agent"];
        [self setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        self.HTTPBody = [data vicrab_gzippedWithCompressionLevel:0 error:error];
    }
    return self;
}

+ (NSURL *)getStoreUrlFromDsn:(VicrabDsn *)dsn {
    NSURL *url = dsn.url;
    NSString *projectId = url.lastPathComponent;
    NSMutableArray *paths = [url.pathComponents mutableCopy];
    // [0] = /
    // [1] = projectId
    // If there are more than two, that means someone wants to have an additional path
    // ref: https://github.com/getvicrab/vicrab-cocoa/issues/236
    NSString *path = @"";
    if ([paths count] > 2) {
        [paths removeObjectAtIndex:0]; // We remove the leading /
        [paths removeLastObject]; // We remove projectId since we add it later
        path = [NSString stringWithFormat:@"/%@", [paths componentsJoinedByString:@"/"]]; // We put together the path
    }
    NSURLComponents *components = [NSURLComponents new];
    components.scheme = url.scheme;
    components.host = url.host;
    components.port = url.port;
    components.path = [NSString stringWithFormat:@"%@/api/%@/store/", path, projectId];
    return components.URL;
}

static NSString *newHeaderPart(NSString *key, id value) {
    return [NSString stringWithFormat:@"%@=%@", key, value];
}

static NSString *newAuthHeader(NSURL *url) {
    NSMutableString *string = [NSMutableString stringWithString:@"Vicrab "];
    [string appendFormat:@"%@,", newHeaderPart(@"vicrab_version", VicrabServerVersionString)];
    [string appendFormat:@"%@,", newHeaderPart(@"vicrab_client", [NSString stringWithFormat:@"vicrab-cocoa/%@", VicrabClient.versionString])];
    [string appendFormat:@"%@,", newHeaderPart(@"vicrab_timestamp", @((NSInteger) [[NSDate date] timeIntervalSince1970]))];
    [string appendFormat:@"%@", newHeaderPart(@"vicrab_key", url.user)];
    if (nil != url.password) {
        [string appendFormat:@",%@", newHeaderPart(@"vicrab_secret", url.password)];
    }
    return string;
}

@end

NS_ASSUME_NONNULL_END
