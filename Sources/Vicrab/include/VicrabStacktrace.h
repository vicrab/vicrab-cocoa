//
//  VicrabStacktrace.h
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

@class VicrabFrame;

NS_SWIFT_NAME(Stacktrace)
@interface VicrabStacktrace : NSObject <VicrabSerializable>
SENTRY_NO_INIT

/**
 * Array of all VicrabFrame in the stacktrace
 */
@property(nonatomic, strong) NSArray<VicrabFrame *> *frames;

/**
 * Registers of the thread for additional information used on the server
 */
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *registers;

/**
 * Initialize a VicrabStacktrace with frames and registers
 * @param frames NSArray
 * @param registers NSArray
 * @return VicrabStacktrace
 */
- (instancetype)initWithFrames:(NSArray<VicrabFrame *> *)frames
                     registers:(NSDictionary<NSString *, NSString *> *)registers;

/**
 * This will be called internally, is used to remove duplicated frames for certain crashes.
 */
- (void)fixDuplicateFrames;

@end

NS_ASSUME_NONNULL_END
