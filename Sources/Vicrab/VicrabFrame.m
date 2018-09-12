//
//  VicrabFrame.m
//  Vicrab
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabFrame.h>

#else
#import "VicrabFrame.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation VicrabFrame

- (instancetype)init {
    self = [super init];
    if (self) {
        self.function = @"<redacted>";
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    
    [serializedData setValue:self.symbolAddress forKey:@"symbol_addr"];
    [serializedData setValue:self.fileName forKey:@"filename"];
    [serializedData setValue:self.function forKey:@"function"];
    [serializedData setValue:self.module forKey:@"module"];
    [serializedData setValue:self.lineNumber forKey:@"lineno"];
    [serializedData setValue:self.columnNumber forKey:@"colno"];
    
    //liuh 2018-09-10
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(NSUTF8StringEncoding);
    NSData *data = [self.package dataUsingEncoding:enc];
    NSString *packageValue = [[NSString alloc] initWithData:data encoding:enc];
    [serializedData setValue:packageValue forKey:@"package"];
    
    [serializedData setValue:self.imageAddress forKey:@"image_addr"];
    [serializedData setValue:self.instructionAddress forKey:@"instruction_addr"];
    [serializedData setValue:self.platform forKey:@"platform"];

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
