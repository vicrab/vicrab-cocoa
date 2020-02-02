//
//  NSDate+VicrabExtras.m
//  Vicrab
//
//  Created by Daniel Griesser on 19/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//


#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/NSDate+VicrabExtras.h>

#else
#import "NSDate+VicrabExtras.h"
#endif


NS_ASSUME_NONNULL_BEGIN

@implementation NSDate (VicrabExtras)

+ (NSDateFormatter *)getIso8601Formatter {
    static NSDateFormatter *isoFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isoFormatter = [[NSDateFormatter alloc] init];
        [isoFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        isoFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        [isoFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    });

    return isoFormatter;
}

+ (NSDate *)vicrab_fromIso8601String:(NSString *)string {
    return [[self.class getIso8601Formatter] dateFromString:string];
}

- (NSString *)vicrab_toIso8601String {
    return [[self.class getIso8601Formatter] stringFromDate:self];
}

@end

NS_ASSUME_NONNULL_END
