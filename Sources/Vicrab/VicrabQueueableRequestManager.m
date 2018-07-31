//
//  VicrabQueueableRequestManager.m
//  Vicrab
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabQueueableRequestManager.h>
#import <Vicrab/VicrabRequestOperation.h>
#import <Vicrab/VicrabLog.h>

#else
#import "VicrabQueueableRequestManager.h"
#import "VicrabRequestOperation.h"
#import "VicrabLog.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface VicrabQueueableRequestManager ()

@property(nonatomic, strong) NSOperationQueue *queue;
@property(nonatomic, strong) NSURLSession *session;

@end

@implementation VicrabQueueableRequestManager

- (instancetype)initWithSession:(NSURLSession *)session {
    self = [super init];
    if (self) {
        self.session = session;
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.name = @"io.vicrab.QueueableRequestManager.OperationQueue";
        self.queue.maxConcurrentOperationCount = 3;
    }
    return self;
}

- (BOOL)isReady {
    // We always have at least one operation in the queue when calling this
    return self.queue.operationCount <= 1;
}

- (void)addRequest:(NSURLRequest *)request completionHandler:(_Nullable VicrabRequestOperationFinished)completionHandler {
    VicrabRequestOperation *operation = [[VicrabRequestOperation alloc] initWithSession:self.session
                                                                                request:request
                                                                      completionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
                                                                          [VicrabLog logWithMessage:[NSString stringWithFormat:@"Queued requests: %@", @(self.queue.operationCount - 1)] andLevel:kVicrabLogLevelDebug];
                                                                          if (completionHandler) {
                                                                              completionHandler(response, error);
                                                                          }
                                                                      }];
    [self.queue addOperation:operation];
}

- (void)cancelAllOperations {
    [self.queue cancelAllOperations];
}

@end

NS_ASSUME_NONNULL_END
