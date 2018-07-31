//
//  VicrabCrashReportSink.m
//  Vicrab
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabDefines.h>
#import <Vicrab/VicrabCrashReportSink.h>
#import <Vicrab/VicrabCrashReportConverter.h>
#import <Vicrab/VicrabClient+Internal.h>
#import <Vicrab/VicrabClient.h>
#import <Vicrab/VicrabEvent.h>
#import <Vicrab/VicrabException.h>
#import <Vicrab/VicrabLog.h>
#import <Vicrab/VicrabThread.h>

#import <Vicrab/VicrabCrash.h>

#else
#import "VicrabDefines.h"
#import "VicrabCrashReportSink.h"
#import "VicrabCrashReportConverter.h"
#import "VicrabClient.h"
#import "VicrabClient+Internal.h"
#import "VicrabEvent.h"
#import "VicrabException.h"
#import "VicrabLog.h"
#import "VicrabThread.h"

#import "VicrabCrash.h"
#endif


@implementation VicrabCrashReportSink

- (void)handleConvertedEvent:(VicrabEvent *)event report:(NSDictionary *)report sentReports:(NSMutableArray *)sentReports {
    if (nil != event.exceptions.firstObject && [event.exceptions.firstObject.value isEqualToString:@"SENTRY_SNAPSHOT"]) {
        [VicrabLog logWithMessage:@"Snapshotting stacktrace" andLevel:kVicrabLogLevelDebug];
        VicrabClient.sharedClient._snapshotThreads = @[event.exceptions.firstObject.thread];
        VicrabClient.sharedClient._debugMeta = event.debugMeta;
    } else {
        [sentReports addObject:report];
        [VicrabClient.sharedClient sendEvent:event withCompletionHandler:NULL];
    }
}

- (void)filterReports:(NSArray *)reports
          onCompletion:(VicrabCrashReportFilterCompletion)onCompletion {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSMutableArray *sentReports = [NSMutableArray new];
        for (NSDictionary *report in reports) {
            VicrabCrashReportConverter *reportConverter = [[VicrabCrashReportConverter alloc] initWithReport:report];
            if (nil != VicrabClient.sharedClient) {
                reportConverter.userContext = VicrabClient.sharedClient.lastContext;
                VicrabEvent *event = [reportConverter convertReportToEvent];
                [self handleConvertedEvent:event report:report sentReports:sentReports];
            }
        }
        if (onCompletion) {
            onCompletion(sentReports, TRUE, nil);
        }
    });

}

@end
