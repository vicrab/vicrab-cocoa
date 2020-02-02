//
//  Vicrab.h
//  Vicrab
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for Vicrab.
FOUNDATION_EXPORT double VicrabVersionNumber;

//! Project version string for Vicrab.
FOUNDATION_EXPORT const unsigned char VicrabVersionString[];

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabCrash.h>
#import <Vicrab/VicrabClient.h>
#import <Vicrab/VicrabSwizzle.h>

#import <Vicrab/VicrabNSURLRequest.h>

#import <Vicrab/VicrabSerializable.h>

#import <Vicrab/VicrabEvent.h>
#import <Vicrab/VicrabThread.h>
#import <Vicrab/VicrabMechanism.h>
#import <Vicrab/VicrabException.h>
#import <Vicrab/VicrabStacktrace.h>
#import <Vicrab/VicrabFrame.h>
#import <Vicrab/VicrabUser.h>
#import <Vicrab/VicrabDebugMeta.h>
#import <Vicrab/VicrabContext.h>
#import <Vicrab/VicrabBreadcrumb.h>
#import <Vicrab/VicrabBreadcrumbStore.h>

#import <Vicrab/VicrabJavaScriptBridgeHelper.h>

#else

#import "VicrabCrash.h"
#import "VicrabClient.h"
#import "VicrabSwizzle.h"

#import "VicrabNSURLRequest.h"

#import "VicrabSerializable.h"

#import "VicrabEvent.h"
#import "VicrabThread.h"
#import "VicrabMechanism.h"
#import "VicrabException.h"
#import "VicrabStacktrace.h"
#import "VicrabFrame.h"
#import "VicrabUser.h"
#import "VicrabDebugMeta.h"
#import "VicrabContext.h"
#import "VicrabBreadcrumb.h"
#import "VicrabBreadcrumbStore.h"

#import "VicrabJavaScriptBridgeHelper.h"

#endif

