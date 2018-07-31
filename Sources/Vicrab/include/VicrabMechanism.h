//
//  VicrabMechanism.h
//  Vicrab
//
//  Created by Daniel Griesser on 17.05.18.
//  Copyright © 2018 Vicrab. All rights reserved.
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

NS_SWIFT_NAME(Mechanism)
@interface VicrabMechanism : NSObject <VicrabSerializable>
SENTRY_NO_INIT

/**
 * A unique identifier of this mechanism determining rendering and processing
 * of the mechanism data
 */
@property(nonatomic, copy) NSString *type;

/**
 * Human readable description of the error mechanism and a possible
 * hint on how to solve this error
 */
@property(nonatomic, copy) NSString *_Nullable desc;

/**
 * Arbitrary extra data that might help the user understand the error thrown by
 * this mechanism
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable data;

/**
 * Flag indicating whether the exception has been handled by the user
 * (e.g. via ``try..catch``)
 */
@property(nonatomic, copy) NSNumber *_Nullable handled;

/**
 * Fully qualified URL to an online help resource, possible
 * interpolated with error parameters
 */
@property(nonatomic, copy) NSString *_Nullable helpLink;


/**
 * Information from the operating system or runtime on the exception
 * mechanism
 */
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable meta;

/**
 * Initialize an VicrabMechanism with a type
 * @param type String
 * @return VicrabMechanism
 */
- (instancetype)initWithType:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
