//
//  NSDictionary+VicrabSanitize.m
//  Vicrab
//
//  Created by Daniel Griesser on 16/06/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/NSDictionary+VicrabSanitize.h>
#import <Vicrab/NSDate+VicrabExtras.h>

#else
#import "NSDictionary+VicrabSanitize.h"
#import "NSDate+VicrabExtras.h"
#endif

@implementation NSDictionary (VicrabSanitize)

- (NSDictionary *)vicrab_sanitize {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (NSString *key in self.allKeys) {
        if ([[self objectForKey:key] isKindOfClass:NSDictionary.class]) {
            [dict setValue:[((NSDictionary *)[self objectForKey:key]) vicrab_sanitize] forKey:key];
        } else if ([[self objectForKey:key] isKindOfClass:NSDate.class]) {
            [dict setValue:[((NSDate *)[self objectForKey:key]) vicrab_toIso8601String] forKey:key];
        } else if ([key hasPrefix:@"__vicrab"]) {
            continue; // We don't want to add __vicrab variables
        } else {
            [dict setValue:[self objectForKey:key] forKey:key];
        }
    }
    return dict;
}

@end
