//
//  VicrabBreadcrumb.h
//  Vicrab
//
//  Created by Daniel Griesser on 22/05/2017.
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

NS_SWIFT_NAME(Breadcrumb)
@interface VicrabBreadcrumb : NSObject <VicrabSerializable>
SENTRY_NO_INIT

/**
 * Level of breadcrumb
 */
@property(nonatomic) enum VicrabSeverity level;

/**
 * Category of bookmark, can be any string
 */
@property(nonatomic, copy) NSString *category;

/**
 * NSDate when the breadcrumb happened
 */
@property(nonatomic, strong) NSDate *_Nullable timestamp;

/**
 * Type of breadcrumb, can be e.g.: http, empty, user, navigation
 * This will be used as icon of the breadcrumb
 */
@property(nonatomic, copy) NSString *_Nullable type;

/**
 * Message for the breadcrumb
 */
@property(nonatomic, copy) NSString *_Nullable message;

/**
 * Arbitrary additional data that will be sent with the breadcrumb
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable data;

/**
 * Initializer for VicrabBreadcrumb
 *
 * @param level VicrabSeverity
 * @param category String
 * @return VicrabBreadcrumb
 */
- (instancetype)initWithLevel:(enum VicrabSeverity)level category:(NSString *)category;

@end

NS_ASSUME_NONNULL_END
