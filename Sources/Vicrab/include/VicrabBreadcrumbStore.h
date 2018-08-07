//
//  VicrabBreadcrumbStore.h
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

@class VicrabBreadcrumb, VicrabFileManager;

NS_SWIFT_NAME(BreadcrumbStore)
@interface VicrabBreadcrumbStore : NSObject <VicrabSerializable>
VICRAB_NO_INIT

/*
 * This property defines how many breadcrumbs should be stored.
 * Change this to reflect you needs.
 */
@property(nonatomic, assign) NSUInteger maxBreadcrumbs;

/**
 * Init VicrabBreadcrumbStore, should only be used internally
 *
 * @param fileManager VicrabFileManager
 * @return VicrabBreadcrumbStore
 */
- (instancetype)initWithFileManager:(VicrabFileManager *)fileManager;

/**
 * Add a VicrabBreadcrumb to the store
 * @param crumb VicrabBreadcrumb
 */
- (void)addBreadcrumb:(VicrabBreadcrumb *)crumb;

/**
 * Deletes all stored VicrabBreadcrumbs
 */
- (void)clear;

/**
 * Returns the number of stored VicrabBreadcrumbs
 * This number can be higher than maxBreadcrumbs since we
 * only remove breadcrumbs over the limit once we sent them
 * @return number of VicrabBreadcrumb
 */
- (NSUInteger)count;

@end

NS_ASSUME_NONNULL_END
