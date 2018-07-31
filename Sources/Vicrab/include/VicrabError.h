//
//  VicrabError.h
//  Vicrab
//
//  Created by Daniel Griesser on 03/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabDefines.h>

#else
#import "VicrabDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, VicrabError) {
    kVicrabErrorUnknownError = -1,
    kVicrabErrorInvalidDsnError = 100,
    kVicrabErrorVicrabCrashNotInstalledError = 101,
    kVicrabErrorInvalidCrashReportError = 102,
    kVicrabErrorCompressionError = 103,
    kVicrabErrorJsonConversionError = 104,
    kVicrabErrorCouldNotFindDirectory = 105,
    kVicrabErrorRequestError = 106,
    kVicrabErrorEventNotSent = 107,
};

SENTRY_EXTERN NSError *_Nullable NSErrorFromVicrabError(VicrabError error, NSString *description);

SENTRY_EXTERN NSString *const VicrabErrorDomain;

NS_ASSUME_NONNULL_END
