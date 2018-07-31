//
//  VicrabThread.m
//  Vicrab
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabThread.h>
#import <Vicrab/VicrabStacktrace.h>

#else
#import "VicrabThread.h"
#import "VicrabStacktrace.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation VicrabThread

- (instancetype)initWithThreadId:(NSNumber *)threadId {
    self = [super init];
    if (self) {
        self.threadId = threadId;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize {
    NSMutableDictionary *serializedData = @{
            @"id": self.threadId
    }.mutableCopy;

    [serializedData setValue:self.crashed forKey:@"crashed"];
    [serializedData setValue:self.current forKey:@"current"];
    [serializedData setValue:self.name forKey:@"name"];
    [serializedData setValue:[self.stacktrace serialize] forKey:@"stacktrace"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
