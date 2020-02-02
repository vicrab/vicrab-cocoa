//
//  VicrabOptions.m
//  Vicrab
//
//  Created by Daniel Griesser on 12.03.19.
//  Copyright © 2019 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabOptions.h>
#import <Vicrab/VicrabDsn.h>
#import <Vicrab/VicrabError.h>

#else
#import "VicrabOptions.h"
#import "VicrabDsn.h"
#import "VicrabError.h"
#endif

@implementation VicrabOptions

- (_Nullable instancetype)initWithOptions:(NSDictionary<NSString *, id> *)options
                         didFailWithError:(NSError *_Nullable *_Nullable)error {
    self = [super init];
    if (self) {
        [self validateOptions:options didFailWithError:error];
        if (nil != error && nil != *error) {
            return nil;
        }
    }
    return self;
}
    
- (void)validateOptions:(NSDictionary<NSString *, id> *)options
       didFailWithError:(NSError *_Nullable *_Nullable)error {
    if (nil == [options valueForKey:@"dsn"] || ![[options valueForKey:@"dsn"] isKindOfClass:[NSString class]]) {
        *error = NSErrorFromVicrabError(kVicrabErrorInvalidDsnError, @"Dsn cannot be empty");
        return;
    }
    self.dsn = [[VicrabDsn alloc] initWithString:[options valueForKey:@"dsn"] didFailWithError:error];
    
    if ([[options objectForKey:@"release"] isKindOfClass:[NSString class]]) {
        self.releaseName = [options objectForKey:@"release"];
    }
    
    if ([[options objectForKey:@"environment"] isKindOfClass:[NSString class]]) {
        self.environment = [options objectForKey:@"environment"];
    }
    
    if ([[options objectForKey:@"dist"] isKindOfClass:[NSString class]]) {
        self.dist = [options objectForKey:@"dist"];
    }
    
    if (nil != [options objectForKey:@"enabled"]) {
        self.enabled = [NSNumber numberWithBool:[[options objectForKey:@"enabled"] boolValue]];
    }
}
    
@end
