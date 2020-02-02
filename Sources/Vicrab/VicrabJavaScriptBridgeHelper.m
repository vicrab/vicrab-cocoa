//
//  VicrabJavaScriptBridgeHelper.m
//  Vicrab
//
//  Created by Daniel Griesser on 23.10.17.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabJavaScriptBridgeHelper.h>
#import <Vicrab/VicrabError.h>
#import <Vicrab/VicrabLog.h>
#import <Vicrab/VicrabEvent.h>
#import <Vicrab/VicrabFrame.h>
#import <Vicrab/VicrabException.h>
#import <Vicrab/VicrabThread.h>
#import <Vicrab/VicrabStacktrace.h>
#import <Vicrab/VicrabUser.h>
#import <Vicrab/VicrabBreadcrumb.h>

#else
#import "VicrabJavaScriptBridgeHelper.h"
#import "VicrabError.h"
#import "VicrabLog.h"
#import "VicrabEvent.h"
#import "VicrabFrame.h"
#import "VicrabException.h"
#import "VicrabThread.h"
#import "VicrabStacktrace.h"
#import "VicrabUser.h"
#import "VicrabBreadcrumb.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation VicrabJavaScriptBridgeHelper

+ (NSNumberFormatter *)numberFormatter {
    static dispatch_once_t onceToken;
    static NSNumberFormatter *formatter = nil;
    dispatch_once(&onceToken, ^{
        formatter = [NSNumberFormatter new];
        formatter.numberStyle = NSNumberFormatterNoStyle;
    });
    return formatter;
}

+ (NSRegularExpression *)frameRegex {
    static dispatch_once_t onceTokenRegex;
    static NSRegularExpression *regex = nil;
    dispatch_once(&onceTokenRegex, ^{
        //        NSString *pattern = @"at (.+?) \\((?:(.+?):([0-9]+?):([0-9]+?))\\)"; // Regex with debugger
        // Regex taken from
        // https://github.com/getvicrab/raven-js/blob/66a5db5333c22f36819c95844a1583489c1d2661/vendor/TraceKit/tracekit.js#L372
        NSString *pattern = @"^\\s*(.*?)(?:\\((.*?)\\))?(?:^|@)((?:app|file|https?|blob|chrome|webpack|resource|\\[native).*?|[^@]*bundle)(?::(\\d+))?(?::(\\d+))?\\s*$"; // Regex without debugger
        regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    });
    return regex;
}

+ (NSArray *)parseRavenFrames:(NSArray *)ravenFrames {
    NSNumberFormatter *formatter = [self.class numberFormatter];
    NSMutableArray *frames = [NSMutableArray array];
    for (NSDictionary *ravenFrame in ravenFrames) {
        NSMutableDictionary *frame = [[NSMutableDictionary alloc] initWithDictionary:@{@"methodName": ravenFrame[@"function"],
                                                                                       @"file": ravenFrame[@"filename"]}];
        if (ravenFrame[@"lineno"] != NSNull.null) {
            [frame addEntriesFromDictionary:@{@"column": [formatter numberFromString:[NSString stringWithFormat:@"%@", ravenFrame[@"colno"]]],
                                              @"lineNumber": [formatter numberFromString:[NSString stringWithFormat:@"%@", ravenFrame[@"lineno"]]]}];

        }
        [frames addObject:frame];
    }
    return frames;
}

+ (NSArray *)parseJavaScriptStacktrace:(NSString *)stacktrace {
    NSNumberFormatter *formatter = [self.class numberFormatter];
    NSArray *lines = [stacktrace componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *frames = [NSMutableArray array];
    for (NSString *line in lines) {
        NSRange searchedRange = NSMakeRange(0, [line length]);
        NSArray *matches = [[self.class frameRegex] matchesInString:line options:0 range:searchedRange];
        for (NSTextCheckingResult *match in matches) {
            NSMutableDictionary *frame = [[NSMutableDictionary alloc] initWithDictionary:@{@"methodName": [line substringWithRange:[match rangeAtIndex:1]],
                                                                                           @"file": [line substringWithRange:[match rangeAtIndex:3]]}];
            if ([match rangeAtIndex:5].location != NSNotFound) {
                [frame addEntriesFromDictionary:@{@"column": [formatter numberFromString:[line substringWithRange:[match rangeAtIndex:5]]],
                                                  @"lineNumber": [formatter numberFromString:[line substringWithRange:[match rangeAtIndex:4]]]}];
            }
            [frames addObject:frame];
        }
    }
    return frames;
}

+ (VicrabBreadcrumb *)createVicrabBreadcrumbFromJavaScriptBreadcrumb:(NSDictionary *)jsonBreadcrumb {
    NSString *level = jsonBreadcrumb[@"level"];
    if (level == nil) {
        level = @"info";
    }
    VicrabBreadcrumb *breadcrumb = [[VicrabBreadcrumb alloc] initWithLevel:[self.class vicrabSeverityFromLevel:level]
                                                             category:jsonBreadcrumb[@"category"]];
    breadcrumb.message = jsonBreadcrumb[@"message"];
    if ([jsonBreadcrumb[@"timestamp"] integerValue] > 0) {
        breadcrumb.timestamp = [NSDate dateWithTimeIntervalSince1970:[jsonBreadcrumb[@"timestamp"] integerValue]];
    } else {
        breadcrumb.timestamp = [NSDate date];
    }

    breadcrumb.type = jsonBreadcrumb[@"type"];
    breadcrumb.data = jsonBreadcrumb[@"data"];
    return breadcrumb;
}

+ (VicrabEvent *)createVicrabEventFromJavaScriptEvent:(NSDictionary *)jsonEvent {
    VicrabSeverity level = [self.class vicrabSeverityFromLevel:jsonEvent[@"level"]];
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:level];
    if (jsonEvent[@"event_id"]) {
        event.eventId = jsonEvent[@"event_id"];
    }
    if (jsonEvent[@"message"]) {
        event.message = jsonEvent[@"message"];
    }
    if (jsonEvent[@"logger"]) {
        event.logger = jsonEvent[@"logger"];
    }
    if (jsonEvent[@"fingerprint"]) {
        event.fingerprint = jsonEvent[@"fingerprint"];
    }
    if (jsonEvent[@"environment"]) {
        event.environment = jsonEvent[@"environment"];
    }
    event.tags = [self.class sanitizeDictionary:jsonEvent[@"tags"]];
    if (jsonEvent[@"extra"]) {
        event.extra = jsonEvent[@"extra"];
    }
    event.user = [self.class createVicrabUserFromJavaScriptUser:jsonEvent[@"user"]];
    if (jsonEvent[@"exception"] || (jsonEvent[@"stacktrace"] && jsonEvent[@"stacktrace"][@"frames"])) {
        NSArray *jsStacktrace = @[];
        NSString *exceptionType = @"";
        NSString *exceptionValue = @"";
        if (jsonEvent[@"exception"]) {
            NSDictionary *exception;
            if ([jsonEvent valueForKeyPath:@"exception.values"] && [jsonEvent valueForKeyPath:@"exception.values"][0] != NSNull.null) {
                exception = jsonEvent[@"exception"][@"values"][0];
            } else {
                exception = jsonEvent[@"exception"][0];
            }
            jsStacktrace = exception[@"stacktrace"][@"frames"];
            exceptionType = exception[@"type"];
            exceptionValue = exception[@"value"];
        } else if (jsonEvent[@"stacktrace"] && jsonEvent[@"stacktrace"][@"frames"]) {
            jsStacktrace = jsonEvent[@"stacktrace"][@"frames"];
            exceptionValue = jsonEvent[@"message"];
            if (jsonEvent[@"type"]) {
                exceptionType = jsonEvent[@"type"];
            }
        }
        NSMutableArray *frames = [NSMutableArray array];
        NSArray<VicrabFrame *> *stacktrace = [self.class convertReactNativeStacktrace:
                                              [self.class parseRavenFrames:jsStacktrace]];
        for (NSInteger i = (stacktrace.count-1); i >= 0; i--) {
            [frames addObject:[stacktrace objectAtIndex:i]];
        }
        [self.class addExceptionToEvent:event type:exceptionType value:exceptionValue frames:frames];
    }
    return event;
}

+ (NSArray<VicrabFrame *> *)convertReactNativeStacktrace:(NSArray *)stacktrace {
    NSMutableArray<VicrabFrame *> *frames = [NSMutableArray new];
    for (NSDictionary *frame in stacktrace) {
        if (nil == frame[@"methodName"]) {
            continue;
        }
        NSString *simpleFilename = [[[frame[@"file"] lastPathComponent] componentsSeparatedByString:@"?"] firstObject];
        VicrabFrame *vicrabFrame = [[VicrabFrame alloc] init];
        vicrabFrame.fileName = [NSString stringWithFormat:@"app:///%@", simpleFilename];
        vicrabFrame.function = frame[@"methodName"];
        if (nil != frame[@"lineNumber"]) {
            vicrabFrame.lineNumber = frame[@"lineNumber"];
        }
        if (nil != frame[@"column"]) {
            vicrabFrame.columnNumber = frame[@"column"];
        }
        vicrabFrame.platform = @"javascript";
        [frames addObject:vicrabFrame];
    }
    return [frames reverseObjectEnumerator].allObjects;
}

+ (void)addExceptionToEvent:(VicrabEvent *)event type:(NSString *)type value:(NSString *)value frames:(NSArray *)frames {
    VicrabException *vicrabException = [[VicrabException alloc] initWithValue:value type:type];
    VicrabThread *thread = [[VicrabThread alloc] initWithThreadId:@(99)];
    thread.crashed = @(YES);
    thread.stacktrace = [[VicrabStacktrace alloc] initWithFrames:frames registers:@{}];
    vicrabException.thread = thread;
    event.exceptions = @[vicrabException];
}

+ (VicrabUser *_Nullable)createVicrabUserFromJavaScriptUser:(NSDictionary *)user {
    NSString *userId = nil;
    if (nil != user[@"userID"]) {
        userId = [NSString stringWithFormat:@"%@", user[@"userID"]];
    } else if (nil != user[@"userId"]) {
        userId = [NSString stringWithFormat:@"%@", user[@"userId"]];
    } else if (nil != user[@"id"]) {
        userId = [NSString stringWithFormat:@"%@", user[@"id"]];
    }
    VicrabUser *vicrabUser = [[VicrabUser alloc] init];
    if (nil != userId) {
        vicrabUser.userId = userId;
    }
    if (nil != user[@"email"]) {
        vicrabUser.email = [NSString stringWithFormat:@"%@", user[@"email"]];
    }
    if (nil != user[@"username"]) {
        vicrabUser.username = [NSString stringWithFormat:@"%@", user[@"username"]];
    }
    // If there is neither id email or username we return nil
    if (vicrabUser.userId == nil && vicrabUser.email == nil && vicrabUser.username == nil) {
        return nil;
    }
    vicrabUser.extra = user[@"extra"];
    return vicrabUser;
}

+ (VicrabSeverity)vicrabSeverityFromLevel:(NSString *)level {
    if ([level isEqualToString:@"fatal"]) {
        return kVicrabSeverityFatal;
    } else if ([level isEqualToString:@"warning"]) {
        return kVicrabSeverityWarning;
    } else if ([level isEqualToString:@"info"] || [level isEqualToString:@"log"]) {
        return kVicrabSeverityInfo;
    } else if ([level isEqualToString:@"debug"]) {
        return kVicrabSeverityDebug;
    } else if ([level isEqualToString:@"error"]) {
        return kVicrabSeverityError;
    }
    return kVicrabSeverityError;
}

+ (VicrabLogLevel)vicrabLogLevelFromJavaScriptLevel:(int)level {
    switch (level) {
        case 1:
            return kVicrabLogLevelError;
        case 2:
            return kVicrabLogLevelDebug;
        case 3:
            return kVicrabLogLevelVerbose;
        default:
            return kVicrabLogLevelNone;
    }
}

+ (NSDictionary *)sanitizeDictionary:(NSDictionary *)dictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (NSString *key in dictionary.allKeys) {
        [dict setObject:[NSString stringWithFormat:@"%@", [dictionary objectForKey:key]] forKey:key];
    }
    return [NSDictionary dictionaryWithDictionary:dict];
}

@end

NS_ASSUME_NONNULL_END
