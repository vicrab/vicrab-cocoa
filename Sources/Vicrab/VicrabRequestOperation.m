//
//  VicrabRequestOperation.m
//  Vicrab
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabRequestOperation.h>
#import <Vicrab/VicrabLog.h>
#import <Vicrab/VicrabError.h>
#import <Vicrab/VicrabClient.h>

#else
#import "VicrabRequestOperation.h"
#import "VicrabLog.h"
#import "VicrabError.h"
#import "VicrabClient.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface VicrabRequestOperation ()

@property(nonatomic, strong) NSURLSessionTask *task;
@property(nonatomic, strong) NSURLRequest *request;

@end

@implementation VicrabRequestOperation

- (instancetype)initWithSession:(NSURLSession *)session request:(NSURLRequest *)request
              completionHandler:(_Nullable VicrabRequestOperationFinished)completionHandler {
    self = [super init];
    if (self) {
        self.request = request;
        self.task = [session dataTaskWithRequest:self.request completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSInteger statusCode = [httpResponse statusCode];
            
            // We only have these if's here because of performance reasons
            [VicrabLog logWithMessage:[NSString stringWithFormat:@"Request status: %ld", (long) statusCode] andLevel:kVicrabLogLevelDebug];
            if (VicrabClient.logLevel == kVicrabLogLevelVerbose) {
                [VicrabLog logWithMessage:[NSString stringWithFormat:@"Request response: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]] andLevel:kVicrabLogLevelVerbose];
            }
            
            if (nil != error) {
                [VicrabLog logWithMessage:[NSString stringWithFormat:@"Request failed: %@", error] andLevel:kVicrabLogLevelError];
            }

            if (completionHandler) {
                completionHandler(httpResponse, error);
            }

            [self completeOperation];
        }];
    }
    return self;
}

- (void)cancel {
    if (nil != self.task) {
        [self.task cancel];
    }
    [super cancel];
}

- (void)main {
    if (nil != self.task) {
        [self.task resume];
    }
}

@end

NS_ASSUME_NONNULL_END
