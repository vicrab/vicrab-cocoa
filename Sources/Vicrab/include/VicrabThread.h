//
//  VicrabThread.h
//  Vicrab
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Vicrab/Vicrab.h>)
#import <Vicrab/VicrabDefines.h>
#import <Vicrab/VicrabSerializable.h>
#else
#import "VicrabDefines.h"
#import "VicrabSerializable.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class VicrabStacktrace;

NS_SWIFT_NAME(Thread)
@interface VicrabThread : NSObject <VicrabSerializable>
SENTRY_NO_INIT

/**
 * Number of the thread
 */
@property(nonatomic, copy) NSNumber *threadId;

/**
 * Name (if available) of the thread
 */
@property(nonatomic, copy) NSString *_Nullable name;

/**
 * VicrabStacktrace of the VicrabThread
 */
@property(nonatomic, strong) VicrabStacktrace *_Nullable stacktrace;

/**
 * Did this thread crash?
 */
@property(nonatomic, copy) NSNumber *_Nullable crashed;

/**
 * Was it the current thread.
 */
@property(nonatomic, copy) NSNumber *_Nullable current;

/**
 * Initializes a VicrabThread with its id
 * @param threadId NSNumber
 * @return VicrabThread
 */
- (instancetype)initWithThreadId:(NSNumber *)threadId;

@end

NS_ASSUME_NONNULL_END
