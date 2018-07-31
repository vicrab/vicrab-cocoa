//
//  VicrabCrashExceptionApplication.h
//  Vicrab
//
//  Created by Daniel Griesser on 31.08.17.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
@interface VicrabCrashExceptionApplication : NSApplication
#else
#import <Foundation/Foundation.h>
@interface VicrabCrashExceptionApplication : NSObject
#endif

@end
