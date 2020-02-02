//
//  VicrabBreadcrumbStore.m
//  Vicrab
//
//  Created by Daniel Griesser on 22/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabBreadcrumbStore.h>
#import <Vicrab/VicrabBreadcrumb.h>
#import <Vicrab/VicrabLog.h>
#import <Vicrab/VicrabFileManager.h>

#else
#import "VicrabBreadcrumbStore.h"
#import "VicrabBreadcrumb.h"
#import "VicrabLog.h"
#import "VicrabFileManager.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface VicrabBreadcrumbStore ()

@property(nonatomic, strong) VicrabFileManager *fileManager;

@end

@implementation VicrabBreadcrumbStore

- (instancetype)initWithFileManager:(VicrabFileManager *)fileManager {
    self = [super init];
    if (self) {
        self.maxBreadcrumbs = 50;
        self.fileManager = fileManager;
    }
    return self;
}

- (void)addBreadcrumb:(VicrabBreadcrumb *)crumb {
    [VicrabLog logWithMessage:[NSString stringWithFormat:@"Add breadcrumb: %@", crumb] andLevel:kVicrabLogLevelDebug];
    [self.fileManager storeBreadcrumb:crumb maxCount:self.maxBreadcrumbs];
}

- (NSUInteger)count {
    return [[self.fileManager getAllStoredBreadcrumbs] count];
}

- (void)clear {
    [self.fileManager deleteAllStoredBreadcrumbs];
}

- (NSDictionary<NSString *, id> *)serialize {
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    
    NSArray<NSDictionary<NSString *, id> *> *breadCrumbs = [self.fileManager getAllStoredBreadcrumbs];
    
    NSMutableArray *crumbs = [NSMutableArray new];
    for (NSDictionary<NSString *, id> *crumb in breadCrumbs) {
        id serializedCrumb = [NSJSONSerialization JSONObjectWithData:crumb[@"data"] options:0 error:nil];
        if (serializedCrumb != nil) {
            [crumbs addObject:serializedCrumb];
        }
    }
    if (crumbs.count > 0) {
        [serializedData setValue:crumbs forKey:@"breadcrumbs"];
    }
    
    return serializedData;
}

@end

NS_ASSUME_NONNULL_END

