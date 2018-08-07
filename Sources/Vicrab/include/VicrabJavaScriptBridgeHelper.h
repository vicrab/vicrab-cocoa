//
//  VicrabJavaScriptBridgeHelper.h
//  Vicrab
//
//  Created by Daniel Griesser on 23.10.17.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Vicrab/Vicrab.h>)
#import <Vicrab/VicrabDefines.h>
#else
#import "VicrabDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class VicrabEvent, VicrabUser, VicrabFrame, VicrabBreadcrumb;

@interface VicrabJavaScriptBridgeHelper : NSObject
VICRAB_NO_INIT

+ (VicrabEvent *)createVicrabEventFromJavaScriptEvent:(NSDictionary *)jsonEvent;
+ (VicrabBreadcrumb *)createVicrabBreadcrumbFromJavaScriptBreadcrumb:(NSDictionary *)jsonBreadcrumb;
+ (VicrabLogLevel)vicrabLogLevelFromJavaScriptLevel:(int)level;
+ (VicrabUser *_Nullable)createVicrabUserFromJavaScriptUser:(NSDictionary *)user;
+ (NSArray *)parseJavaScriptStacktrace:(NSString *)stacktrace;
+ (NSDictionary *)sanitizeDictionary:(NSDictionary *)dictionary;
+ (NSArray<VicrabFrame *> *)convertReactNativeStacktrace:(NSArray *)stacktrace;

@end

NS_ASSUME_NONNULL_END
