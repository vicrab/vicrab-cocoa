//
//  VicrabNSUIntegerValue.m
//  Vicrab
//
//  Created by Crazy凡 on 2019/3/21.
//  Copyright © 2019 Vicrab. All rights reserved.
//



#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/NSString+VicrabNSUIntegerValue.h>

#else
#import "NSString+VicrabNSUIntegerValue.h"
#endif

@implementation NSString (VicrabNSUIntegerValue)

- (NSUInteger)unsignedLongLongValue {
    return strtoull([self UTF8String], NULL, 0);
}

@end
