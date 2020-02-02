//
//  VicrabSwizzleTests.m
//  Vicrab
//
//  Created by Daniel Griesser on 06/06/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Vicrab/Vicrab.h>
#import "VicrabSwizzle.h"

#pragma mark - HELPER CLASSES -

@interface VicrabTestsLog : NSObject
+ (void)log:(NSString *)string;

+ (void)clear;

+ (BOOL)is:(NSString *)compareString;

+ (NSString *)logString;
@end

@implementation VicrabTestsLog

static NSMutableString *_logString = nil;

+ (void)log:(NSString *)string {
    if (!_logString) {
        _logString = [NSMutableString new];
    }
    [_logString appendString:string];
    NSLog(@"%@", string);
}

+ (void)clear {
    _logString = [NSMutableString new];
}

+ (BOOL)is:(NSString *)compareString {
    return [compareString isEqualToString:_logString];
}

+ (NSString *)logString {
    return _logString;
}

@end

#define ASSERT_LOG_IS(STRING) XCTAssertTrue([VicrabTestsLog is:STRING], @"LOG IS @\"%@\" INSTEAD",[VicrabTestsLog logString])
#define CLEAR_LOG() ([VicrabTestsLog clear])
#define VicrabTestsLog(STRING) [VicrabTestsLog log:STRING]

@interface VicrabSwizzleTestClass_A : NSObject
@end

@implementation VicrabSwizzleTestClass_A
- (int)calc:(int)num {
    return num;
}

- (BOOL)methodReturningBOOL {
    return YES;
};
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
- (void)methodWithArgument:(id)arg {
};
#pragma GCC diagnostic pop
- (void)methodForAlwaysSwizzling {
};

- (void)methodForSwizzlingOncePerClass {
};

- (void)methodForSwizzlingOncePerClassOrSuperClasses {
};

- (NSString *)string {
    return @"ABC";
}

+ (NSNumber *)sumFloat:(float)floatSummand withDouble:(double)doubleSummand {
    return @(floatSummand + doubleSummand);
}
@end

@interface VicrabSwizzleTestClass_B : VicrabSwizzleTestClass_A
@end

@implementation VicrabSwizzleTestClass_B
@end

@interface VicrabSwizzleTestClass_C : VicrabSwizzleTestClass_B
@end

@implementation VicrabSwizzleTestClass_C

- (void)dealloc {
    VicrabTestsLog(@"C-");
};

- (int)calc:(int)num {
    return [super calc:num] * 3;
}
@end

@interface VicrabSwizzleTestClass_D : VicrabSwizzleTestClass_C
@end

@implementation VicrabSwizzleTestClass_D
@end

@interface VicrabSwizzleTestClass_D2 : VicrabSwizzleTestClass_C
@end

@implementation VicrabSwizzleTestClass_D2
@end

#pragma mark - HELPER FUNCTIONS -

static void swizzleVoidMethod(Class classToSwizzle,
        SEL selector,
        dispatch_block_t blockBefore,
        VicrabSwizzleMode mode,
        const void *key) {
    VicrabSwizzleInstanceMethod(classToSwizzle,
            selector,
            VicrabSWReturnType(
            void),
            VicrabSWArguments(),
            VicrabSWReplacement(
                    {
                            blockBefore();
                            VicrabSWCallOriginal();
                    }), mode, key);
}

static void swizzleDealloc(Class classToSwizzle, dispatch_block_t blockBefore) {
    SEL selector = NSSelectorFromString(@"dealloc");
    swizzleVoidMethod(classToSwizzle, selector, blockBefore, VicrabSwizzleModeAlways, NULL);
}

static void swizzleNumber(Class classToSwizzle, int(^transformationBlock)(int)) {
    VicrabSwizzleInstanceMethod(classToSwizzle,
            @selector(calc:),
            VicrabSWReturnType(
            int),
            VicrabSWArguments(
            int num),
            VicrabSWReplacement(
                    {
                            int res = VicrabSWCallOriginal(num);
                            return transformationBlock(res);
                    }), VicrabSwizzleModeAlways, NULL);
}

@interface VicrabSwizzleTests : XCTestCase

@end

@implementation VicrabSwizzleTests

+ (void)setUp {
    [self swizzleDeallocs];
    [self swizzleCalc];
}

- (void)setUp {
    [super setUp];
    CLEAR_LOG();
}

+ (void)swizzleDeallocs {
    // 1) Swizzling a class that does not implement the method...
    swizzleDealloc([VicrabSwizzleTestClass_D class], ^{
        VicrabTestsLog(@"d-");
    });
    // ...should not break swizzling of its superclass.
    swizzleDealloc([VicrabSwizzleTestClass_C class], ^{
        VicrabTestsLog(@"c-");
    });
    // 2) Swizzling a class that does not implement the method
    // should not affect classes with the same superclass.
    swizzleDealloc([VicrabSwizzleTestClass_D2 class], ^{
        VicrabTestsLog(@"d2-");
    });

    // 3) We should be able to swizzle classes several times...
    swizzleDealloc([VicrabSwizzleTestClass_D class], ^{
        VicrabTestsLog(@"d'-");
    });
    // ...and nothing should be breaked up.
    swizzleDealloc([VicrabSwizzleTestClass_C class], ^{
        VicrabTestsLog(@"c'-");
    });

    // 4) Swizzling a class inherited from NSObject and does not
    // implementing the method.
    swizzleDealloc([VicrabSwizzleTestClass_A class], ^{
        VicrabTestsLog(@"a");
    });
}

- (void)testDeallocSwizzling {
    @autoreleasepool {
        id object = [VicrabSwizzleTestClass_D new];
        object = nil;
    }
    ASSERT_LOG_IS(@"d'-d-c'-c-C-a");
}

#pragma mark - Calc: Swizzling

+ (void)swizzleCalc {

    swizzleNumber([VicrabSwizzleTestClass_C class], ^int(int num) {
        return num + 17;
    });

    swizzleNumber([VicrabSwizzleTestClass_D class], ^int(int num) {
        return num * 11;
    });
    swizzleNumber([VicrabSwizzleTestClass_C class], ^int(int num) {
        return num * 5;
    });
    swizzleNumber([VicrabSwizzleTestClass_D class], ^int(int num) {
        return num - 20;
    });

    swizzleNumber([VicrabSwizzleTestClass_A class], ^int(int num) {
        return num * -1;
    });
}

- (void)testCalcSwizzling {
    VicrabSwizzleTestClass_D *object = [VicrabSwizzleTestClass_D new];
    int res = [object calc:2];
    XCTAssertTrue(res == ((2 * (-1) * 3) + 17) * 5 * 11 - 20, @"%d", res);
}

#pragma mark - String Swizzling

- (void)testStringSwizzling {
    SEL selector = @selector(string);
    VicrabSwizzleTestClass_A *a = [VicrabSwizzleTestClass_A new];

    VicrabSwizzleInstanceMethod([a class],
            selector,
            VicrabSWReturnType(NSString * ),
            VicrabSWArguments(),
            VicrabSWReplacement(
                    {
                            NSString * res = VicrabSWCallOriginal();
                            return[res stringByAppendingString:@"DEF"];
                    }), VicrabSwizzleModeAlways, NULL);

    XCTAssertTrue([[a string] isEqualToString:@"ABCDEF"]);
}

#pragma mark - Class Swizzling

- (void)testClassSwizzling {
    VicrabSwizzleClassMethod([VicrabSwizzleTestClass_B class],
            @selector(sumFloat:withDouble:),
            VicrabSWReturnType(NSNumber * ),
            VicrabSWArguments(
            float floatSummand,
            double doubleSummand),
            VicrabSWReplacement(
                    {
                            NSNumber * result = VicrabSWCallOriginal(floatSummand, doubleSummand);
                            return @([result doubleValue]* 2.);
                    }));
    
    XCTAssertEqualObjects(@(2.), [VicrabSwizzleTestClass_A sumFloat:0.5 withDouble:1.5]);
    XCTAssertEqualObjects(@(4.), [VicrabSwizzleTestClass_B sumFloat:0.5 withDouble:1.5]);
    XCTAssertEqualObjects(@(4.), [VicrabSwizzleTestClass_C sumFloat:0.5 withDouble:1.5]);
}

#pragma mark - Test Assertions
#if !defined(NS_BLOCK_ASSERTIONS)

- (void)testThrowsOnSwizzlingNonexistentMethod {
    SEL selector = NSSelectorFromString(@"nonexistent");
    VicrabSwizzleImpFactoryBlock factoryBlock = ^id(VicrabSwizzleInfo *swizzleInfo) {
        return ^(__unsafe_unretained id self) {
            void (*originalIMP)(__unsafe_unretained id, SEL);
            originalIMP = (__typeof(originalIMP)) [swizzleInfo getOriginalImplementation];
            originalIMP(self, selector);
        };
    };
    XCTAssertThrows([VicrabSwizzle
            swizzleInstanceMethod:selector
                          inClass:[VicrabSwizzleTestClass_A class]
                    newImpFactory:factoryBlock
                             mode:VicrabSwizzleModeAlways
                              key:NULL]);
}

#endif

#pragma mark - Mode tests

- (void)testAlwaysSwizzlingMode {
    for (int i = 3; i > 0; --i) {
        swizzleVoidMethod([VicrabSwizzleTestClass_A class],
                @selector(methodForAlwaysSwizzling), ^{
                    VicrabTestsLog(@"A");
                },
                VicrabSwizzleModeAlways,
                NULL);
        swizzleVoidMethod([VicrabSwizzleTestClass_B class],
                @selector(methodForAlwaysSwizzling), ^{
                    VicrabTestsLog(@"B");
                },
                VicrabSwizzleModeAlways,
                NULL);
    }

    VicrabSwizzleTestClass_B *object = [VicrabSwizzleTestClass_B new];
    [object methodForAlwaysSwizzling];
    ASSERT_LOG_IS(@"BBBAAA");
}

- (void)testSwizzleOncePerClassMode {
    static void *key = &key;
    for (int i = 3; i > 0; --i) {
        swizzleVoidMethod([VicrabSwizzleTestClass_A class],
                @selector(methodForSwizzlingOncePerClass), ^{
                    VicrabTestsLog(@"A");
                },
                VicrabSwizzleModeOncePerClass,
                key);
        swizzleVoidMethod([VicrabSwizzleTestClass_B class],
                @selector(methodForSwizzlingOncePerClass), ^{
                    VicrabTestsLog(@"B");
                },
                VicrabSwizzleModeOncePerClass,
                key);
    }
    VicrabSwizzleTestClass_B *object = [VicrabSwizzleTestClass_B new];
    [object methodForSwizzlingOncePerClass];
    ASSERT_LOG_IS(@"BA");
}

- (void)testSwizzleOncePerClassOrSuperClassesMode {
    static void *key = &key;
    for (int i = 3; i > 0; --i) {
        swizzleVoidMethod([VicrabSwizzleTestClass_A class],
                @selector(methodForSwizzlingOncePerClassOrSuperClasses), ^{
                    VicrabTestsLog(@"A");
                },
                VicrabSwizzleModeOncePerClassAndSuperclasses,
                key);
        swizzleVoidMethod([VicrabSwizzleTestClass_B class],
                @selector(methodForSwizzlingOncePerClassOrSuperClasses), ^{
                    VicrabTestsLog(@"B");
                },
                VicrabSwizzleModeOncePerClassAndSuperclasses,
                key);
    }
    VicrabSwizzleTestClass_B *object = [VicrabSwizzleTestClass_B new];
    [object methodForSwizzlingOncePerClassOrSuperClasses];
    ASSERT_LOG_IS(@"A");
}

@end
