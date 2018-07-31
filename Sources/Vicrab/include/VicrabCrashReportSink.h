//
//  VicrabCrashReportSink.h
//  Vicrab
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Vicrab/Vicrab.h>)
#import <Vicrab/VicrabCrash.h>
#else
#import "VicrabCrash.h"
#endif


@interface VicrabCrashReportSink : NSObject <VicrabCrashReportFilter>

@end
