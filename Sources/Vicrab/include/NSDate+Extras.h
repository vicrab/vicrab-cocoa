//
//  NSDate+Extras.h
//  Vicrab
//
//  Created by Daniel Griesser on 19/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDate (Extras)

+ (NSDate *)vicrab_fromIso8601String:(NSString *)string;

- (NSString *)vicrab_toIso8601String;

@end

NS_ASSUME_NONNULL_END
