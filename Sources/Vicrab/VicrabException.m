//
//  VicrabException.m
//  Vicrab
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabException.h>
#import <Vicrab/VicrabThread.h>
#import <Vicrab/VicrabMechanism.h>
#import <Vicrab/VicrabStacktrace.h>

#else
#import "VicrabException.h"
#import "VicrabThread.h"
#import "VicrabMechanism.h"
#import "VicrabStacktrace.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation VicrabException

- (instancetype)initWithValue:(NSString *)value type:(NSString *)type {
    self = [super init];
    if (self) {
        self.value = value;
        self.type = type;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    [serializedData setValue:self.value forKey:@"value"];
    [serializedData setValue:self.type forKey:@"type"];
    [serializedData setValue:[self.mechanism serialize] forKey:@"mechanism"];
    [serializedData setValue:self.module forKey:@"module"];
    [serializedData setValue:self.thread.threadId forKey:@"thread_id"];
    [serializedData setValue:[self.thread.stacktrace serialize] forKey:@"stacktrace"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
