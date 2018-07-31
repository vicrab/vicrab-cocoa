//
//  VicrabError.m
//  Vicrab
//
//  Created by Daniel Griesser on 03/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabError.h>

#else
#import "VicrabError.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NSString *const VicrabErrorDomain = @"VicrabErrorDomain";

NSError *_Nullable NSErrorFromVicrabError(VicrabError error, NSString *description) {
    NSMutableDictionary *userInfo = [NSMutableDictionary new];
    [userInfo setValue:description forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:VicrabErrorDomain code:error userInfo:userInfo];
}

NS_ASSUME_NONNULL_END
