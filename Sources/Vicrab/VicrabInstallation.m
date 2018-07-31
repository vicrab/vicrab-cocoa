//
//  VicrabCrashInstallation.m
//  Vicrab
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabDefines.h>
#import <Vicrab/VicrabInstallation.h>
#import <Vicrab/VicrabCrashReportSink.h>
#import <Vicrab/VicrabLog.h>

#import <Vicrab/VicrabCrash.h>
#import <Vicrab/VicrabCrashInstallation+Private.h>

#else
#import "VicrabDefines.h"
#import "VicrabInstallation.h"
#import "VicrabCrashReportSink.h"
#import "VicrabLog.h"

#import "VicrabCrash.h"
#import "VicrabCrashInstallation+Private.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation VicrabInstallation

- (id)init {
    return [super initWithRequiredProperties:[NSArray new]];
}

- (id<VicrabCrashReportFilter>)sink {
    return [[VicrabCrashReportSink alloc] init];
}

- (void)sendAllReports {
    [self sendAllReportsWithCompletion:NULL];
}

- (void)sendAllReportsWithCompletion:(VicrabCrashReportFilterCompletion)onCompletion {
    [super sendAllReportsWithCompletion:^(NSArray *filteredReports, BOOL completed, NSError *error) {
        if (nil != error) {
            [VicrabLog logWithMessage:error.localizedDescription andLevel:kVicrabLogLevelError];
        }
        [VicrabLog logWithMessage:[NSString stringWithFormat:@"Sent %lu crash report(s)", (unsigned long)filteredReports.count] andLevel:kVicrabLogLevelDebug];
        if (completed && onCompletion) {
            onCompletion(filteredReports, completed, error);
        }
    }];
}

@end

NS_ASSUME_NONNULL_END
