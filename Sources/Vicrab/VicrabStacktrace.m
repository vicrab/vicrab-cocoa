//
//  VicrabStacktrace.m
//  Vicrab
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//


#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabStacktrace.h>
#import <Vicrab/VicrabFrame.h>
#import <Vicrab/VicrabLog.h>

#else
#import "VicrabStacktrace.h"
#import "VicrabFrame.h"
#import "VicrabLog.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation VicrabStacktrace

- (instancetype)initWithFrames:(NSArray<VicrabFrame *> *)frames
                     registers:(NSDictionary<NSString *, NSString *> *)registers {
    self = [super init];
    if (self) {
        self.registers = registers;
        self.frames = frames;
    }
    return self;
}

/// This function fixes duplicate frames and removes the first duplicate
/// https://github.com/kstenerud/KSCrash/blob/05cdc801cfc578d256f85de2e72ec7877cbe79f8/Source/KSCrash/Recording/Tools/KSStackCursor_MachineContext.c#L84
- (void)fixDuplicateFrames {
    if (self.frames.count < 2 || nil == self.registers) {
        return;
    }
    
    VicrabFrame *lastFrame = self.frames.lastObject;
    VicrabFrame *beforeLastFrame = [self.frames objectAtIndex:self.frames.count - 2];
 
    if ([lastFrame.symbolAddress isEqualToString:beforeLastFrame.symbolAddress] &&
        [self.registers[@"lr"] isEqualToString:beforeLastFrame.instructionAddress]) {
        NSMutableArray *copyFrames = self.frames.mutableCopy;
        [copyFrames removeObjectAtIndex:self.frames.count - 2];
        self.frames = copyFrames;
        [VicrabLog logWithMessage:@"Found duplicate frame, removing one with link register" andLevel:kVicrabLogLevelDebug];
    }
}

- (NSDictionary<NSString *, id> *)serialize {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    NSMutableArray *frames = [NSMutableArray new];
    for (VicrabFrame *frame in self.frames) {
        NSDictionary *serialized = [frame serialize];
        if (serialized.allKeys.count > 0) {
            [frames addObject:[frame serialize]];
        }
    }
    [serializedData setValue:frames forKey:@"frames"];

    // This is here because we wanted to be conform with the old json
    if (self.registers.count > 0) {
        [serializedData setValue:self.registers forKey:@"registers"];
    }
    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
