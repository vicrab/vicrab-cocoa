//
//  VicrabCrashExceptionApplication.m
//  Vicrab
//
//  Created by Daniel Griesser on 31.08.17.
//  Copyright © 2017 Vicrab. All rights reserved.
//


#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabDefines.h>
#import <Vicrab/VicrabCrashExceptionApplication.h>
#import <Vicrab/VicrabCrash.h>

#else
#import "VicrabDefines.h"
#import "VicrabCrashExceptionApplication.h"
#import "VicrabCrash.h"
#endif


@implementation VicrabCrashExceptionApplication

#if TARGET_OS_OSX

- (void)reportException:(NSException *)exception {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"NSApplicationCrashOnExceptions": @YES }];
    if (nil != VicrabCrash.sharedInstance.uncaughtExceptionHandler && nil != exception) {
        VicrabCrash.sharedInstance.uncaughtExceptionHandler(exception);
    }
    [super reportException:exception];
}
#endif

@end
