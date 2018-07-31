//
//  VicrabContext.h
//  Vicrab
//
//  Created by Daniel Griesser on 18/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabSerializable.h>

#else
#import "VicrabSerializable.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Context)
@interface VicrabContext : NSObject <VicrabSerializable>

/**
 * Operating System information in contexts
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable osContext;

/**
 * Device information in contexts
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable deviceContext;

/**
 * App information in contexts
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable appContext;

- (instancetype)init;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
