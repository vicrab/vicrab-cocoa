//
//  VicrabBreadcrumb.m
//  Vicrab
//
//  Created by Daniel Griesser on 22/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabBreadcrumb.h>
#import <Vicrab/NSDate+Extras.h>
#import <Vicrab/NSDictionary+Sanitize.h>

#else
#import "VicrabBreadcrumb.h"
#import "NSDate+Extras.h"
#import "NSDictionary+Sanitize.h"
#endif


@implementation VicrabBreadcrumb

- (instancetype)initWithLevel:(enum VicrabSeverity)level category:(NSString *)category {
    self = [super init];
    if (self) {
        self.level = level;
        self.category = category;
        self.timestamp = [NSDate date];
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    [serializedData setValue:VicrabSeverityNames[self.level] forKey:@"level"];
    [serializedData setValue:[self.timestamp vicrab_toIso8601String] forKey:@"timestamp"];
    [serializedData setValue:self.category forKey:@"category"];
    [serializedData setValue:self.type forKey:@"type"];
    [serializedData setValue:self.message forKey:@"message"];
    [serializedData setValue:[self.data vicrab_sanitize] forKey:@"data"];

    return serializedData;
}

@end
