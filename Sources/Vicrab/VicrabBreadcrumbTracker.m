//
//  VicrabBreadcrumbTracker.m
//  Vicrab
//
//  Created by Daniel Griesser on 31/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabBreadcrumb.h>
#import <Vicrab/VicrabClient.h>
#import <Vicrab/VicrabDefines.h>
#import <Vicrab/VicrabBreadcrumbTracker.h>
#import <Vicrab/VicrabSwizzle.h>
#import <Vicrab/VicrabBreadcrumbStore.h>

#else
#import "VicrabClient.h"
#import "VicrabDefines.h"
#import "VicrabSwizzle.h"
#import "VicrabBreadcrumbTracker.h"
#import "VicrabBreadcrumb.h"
#import "VicrabBreadcrumbStore.h"
#endif

#if VICRAB_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif


@implementation VicrabBreadcrumbTracker

- (void)start {
    [self addEnabledCrumb];
    [self swizzleSendAction];
    [self swizzleViewDidAppear];
}

- (void)addEnabledCrumb {
    if (nil != VicrabClient.sharedClient) {
        VicrabBreadcrumb *crumb = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityInfo category:@"started"];
        crumb.type = @"debug";
        crumb.message = @"Breadcrumb Tracking";
        [VicrabClient.sharedClient.breadcrumbs addBreadcrumb:crumb];
    }
}

- (void)swizzleSendAction {
#if VICRAB_HAS_UIKIT
    static const void *swizzleSendActionKey = &swizzleSendActionKey;
    //    - (BOOL)sendAction:(SEL)action to:(nullable id)target from:(nullable id)sender forEvent:(nullable UIEvent *)event;
    SEL selector = NSSelectorFromString(@"sendAction:to:from:forEvent:");
    VicrabSwizzleInstanceMethod(UIApplication.class,
            selector,
            VicrabSWReturnType(BOOL),
            VicrabSWArguments(SEL action, id target, id sender, UIEvent * event),
            VicrabSWReplacement({
                    if (nil != VicrabClient.sharedClient) {
                        NSDictionary *data = [NSDictionary new];
                        for (UITouch *touch in event.allTouches) {
                            if (touch.phase == UITouchPhaseCancelled || touch.phase == UITouchPhaseEnded) {
                                data = @{@"view": [NSString stringWithFormat:@"%@", touch.view]};
                            }
                        }
                        VicrabBreadcrumb *crumb = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityInfo category:@"touch"];
                        crumb.type = @"user";
                        crumb.message = [NSString stringWithFormat:@"%s", sel_getName(action)];
                        crumb.data = data;
                        [VicrabClient.sharedClient.breadcrumbs addBreadcrumb:crumb];
                    }
                    return VicrabSWCallOriginal(action, target, sender, event);
            }), VicrabSwizzleModeOncePerClassAndSuperclasses, swizzleSendActionKey);
#endif
}

- (void)swizzleViewDidAppear {
#if VICRAB_HAS_UIKIT
    static const void *swizzleViewDidAppearKey = &swizzleViewDidAppearKey;
    SEL selector = NSSelectorFromString(@"viewDidAppear:");
    VicrabSwizzleInstanceMethod(UIViewController.class,
            selector,
            VicrabSWReturnType(void),
            VicrabSWArguments(BOOL animated),
            VicrabSWReplacement({
                    if (nil != VicrabClient.sharedClient) {
                        VicrabBreadcrumb *crumb = [[VicrabBreadcrumb alloc] initWithLevel:kVicrabSeverityInfo category:@"UIViewController"];
                        crumb.type = @"navigation";
                        crumb.message = @"viewDidAppear";
                        NSString *viewControllerName = [VicrabBreadcrumbTracker sanitizeViewControllerName:[NSString stringWithFormat:@"%@", self]];
                        crumb.data = @{@"controller": viewControllerName};
                        [VicrabClient.sharedClient.breadcrumbs addBreadcrumb:crumb];
                        NSMutableDictionary *prevExtra = VicrabClient.sharedClient.extra.mutableCopy;
                        [prevExtra setValue:viewControllerName forKey:@"__vicrab_transaction"];
                        VicrabClient.sharedClient.extra = prevExtra;
                    }
                    VicrabSWCallOriginal(animated);
            }), VicrabSwizzleModeOncePerClassAndSuperclasses, swizzleViewDidAppearKey);
#endif
}

+ (NSRegularExpression *)viewControllerRegex {
    static dispatch_once_t onceTokenRegex;
    static NSRegularExpression *regex = nil;
    dispatch_once(&onceTokenRegex, ^{
        NSString *pattern = @"[<.](\\w+)";
        regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    });
    return regex;
}

+ (NSString *)sanitizeViewControllerName:(NSString *)controller {
    NSRange searchedRange = NSMakeRange(0, [controller length]);
    NSArray *matches = [[self.class viewControllerRegex] matchesInString:controller options:0 range:searchedRange];
    NSMutableArray *strings = [NSMutableArray array];
    for (NSTextCheckingResult *match in matches) {
        [strings addObject:[controller substringWithRange:[match rangeAtIndex:1]]];
    }
    if ([strings count] > 0) {
        return [strings componentsJoinedByString:@"."];
    }
    return controller;
}

@end
