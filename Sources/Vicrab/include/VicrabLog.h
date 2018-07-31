//
//  VicrabLog.h
//  Vicrab
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabDefines.h>

#else
#import "VicrabDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface VicrabLog : NSObject

+ (void)logWithMessage:(NSString *)message andLevel:(VicrabLogLevel)level;

@end

NS_ASSUME_NONNULL_END
