//
//  VicrabLog.m
//  Vicrab
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabClient.h>
#import <Vicrab/VicrabLog.h>

#else
#import "VicrabClient.h"
#import "VicrabLog.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation VicrabLog

+ (void)logWithMessage:(NSString *)message andLevel:(VicrabLogLevel)level {
    VicrabLogLevel defaultLevel = kVicrabLogLevelError;
    if (VicrabClient.logLevel > 0) {
        defaultLevel = VicrabClient.logLevel;
    }
    if (level <= defaultLevel && level != kVicrabLogLevelNone) {
        NSLog(@"Vicrab - %@:: %@", [self.class logLevelToString:level], message);
    }
}

+ (NSString *)logLevelToString:(VicrabLogLevel)level {
    switch (level) {
        case kVicrabLogLevelDebug:
            return @"Debug";
        case kVicrabLogLevelVerbose:
            return @"Verbose";
        default:
            return @"Error";
    }
}
@end

NS_ASSUME_NONNULL_END
