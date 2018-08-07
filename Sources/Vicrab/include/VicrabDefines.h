//
//  VicrabDefines.h
//  Vicrab
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
#define VICRAB_EXTERN        extern "C" __attribute__((visibility ("default")))
#else
#define VICRAB_EXTERN        extern __attribute__((visibility ("default")))
#endif

#if TARGET_OS_IOS || TARGET_OS_TV
#define VICRABY_HAS_UIDEVICE 1
#else
#define VICRAB_HAS_UIDEVICE 0
#endif

#if VICRAB_HAS_UIDEVICE
#define VICRAB_HAS_UIKIT 1
#else
#define VICRAB_HAS_UIKIT 0
#endif

#define VICRAB_NO_INIT \
- (instancetype)init NS_UNAVAILABLE; \
+ (instancetype)new NS_UNAVAILABLE;

@class VicrabEvent, VicrabNSURLRequest;

/**
 * Block used for returning after a request finished
 */
typedef void (^VicrabRequestFinished)(NSError *_Nullable error);

/**
 * Block used for request operation finished, shouldDiscardEvent is YES if event should be deleted
 * regardless if an error occured or not
 */
typedef void (^VicrabRequestOperationFinished)(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error);

/**
 * Block can be used to mutate event before its send
 */
typedef void (^VicrabBeforeSerializeEvent)(VicrabEvent *_Nonnull event);
/**
 * Block can be used to mutate NSURLRequest e.g.: add headers before request is executed
 */
typedef void (^VicrabBeforeSendRequest)(VicrabNSURLRequest *_Nonnull request);
/**
 * Block can be used to prevent the event from being sent
 */
typedef BOOL (^VicrabShouldSendEvent)(VicrabEvent *_Nonnull event);
/**
 * Block can be used to determine if an event should be queued and stored locally.
 * It will be tried to send again after next successful send.
 * Note that this will only be called once the event is created and send manully.
 * Once it has been queued once it will be discarded if it fails again.
 */
typedef BOOL (^VicrabShouldQueueEvent)(VicrabEvent *_Nonnull event, NSHTTPURLResponse *_Nullable response, NSError *_Nullable error);
/**
 * Loglevel
 */
typedef NS_ENUM(NSInteger, VicrabLogLevel) {
    kVicrabLogLevelNone = 1,
    kVicrabLogLevelError,
    kVicrabLogLevelDebug,
    kVicrabLogLevelVerbose
};

/**
 * Level of severity
 */
typedef NS_ENUM(NSInteger, VicrabSeverity) {
    kVicrabSeverityFatal = 0,
    kVicrabSeverityError = 1,
    kVicrabSeverityWarning = 2,
    kVicrabSeverityInfo = 3,
    kVicrabSeverityDebug = 4,
};

/**
 * Static internal helper to convert enum to string
 */
static NSString *_Nonnull const VicrabSeverityNames[] = {
        @"fatal",
        @"error",
        @"warning",
        @"info",
        @"debug",
};
