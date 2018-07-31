//
//  VicrabUser.h
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

NS_SWIFT_NAME(User)
@interface VicrabUser : NSObject <VicrabSerializable>

/**
 * Optional: Id of the user
 */
@property(nonatomic, copy) NSString *userId;

/**
 * Optional: Email of the user
 */
@property(nonatomic, copy) NSString *_Nullable email;

/**
 * Optional: Username
 */
@property(nonatomic, copy) NSString *_Nullable username;

/**
 * Optional: Additional data
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable extra;

/**
 * Initializes a VicrabUser with the id
 * @param userId NSString
 * @return VicrabUser
 */
- (instancetype)initWithUserId:(NSString *)userId;

- (instancetype)init;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
