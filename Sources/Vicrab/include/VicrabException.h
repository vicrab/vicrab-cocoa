//
//  VicrabException.h
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

@class VicrabThread, VicrabMechanism;

NS_SWIFT_NAME(Exception)
@interface VicrabException : NSObject <VicrabSerializable>
VICRAB_NO_INIT

/**
 * The name of the exception
 */
@property(nonatomic, copy) NSString *value;

/**
 * Type of the exception
 */
@property(nonatomic, copy) NSString *type;

/**
 * Additional information about the exception
 */
@property(nonatomic, strong) VicrabMechanism *_Nullable mechanism;

/**
 * Can be set to define the module
 */
@property(nonatomic, copy) NSString *_Nullable module;

/**
 * Determines if the exception was reported by a user BOOL
 */
@property(nonatomic, copy) NSNumber *_Nullable userReported;

/**
 * VicrabThread of the VicrabException
 */
@property(nonatomic, strong) VicrabThread *_Nullable thread;

/**
 * Initialize an VicrabException with value and type
 * @param value String
 * @param type String
 * @return VicrabException
 */
- (instancetype)initWithValue:(NSString *)value type:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
