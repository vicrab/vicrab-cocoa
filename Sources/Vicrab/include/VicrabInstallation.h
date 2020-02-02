//
//  VicrabCrashInstallation.h
//  Vicrab
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Vicrab/Vicrab.h>)
#import <Vicrab/VicrabCrash.h>
#import <Vicrab/VicrabCrashInstallation.h>
#else
#import "VicrabCrash.h"
#import "VicrabCrashInstallation.h"
#endif

@interface VicrabInstallation : VicrabCrashInstallation

- (void)sendAllReports;

@end
