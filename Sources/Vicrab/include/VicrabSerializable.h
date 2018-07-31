//
//  VicrabSerializable.h
//  Vicrab
//
//  Created by Daniel Griesser on 08/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol VicrabSerializable <NSObject>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (NSDictionary<NSString *, id> *)serialize;

@end

NS_ASSUME_NONNULL_END
