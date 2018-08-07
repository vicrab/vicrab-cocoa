//
//  VicrabFileManager.h
//  Vicrab
//
//  Created by Daniel Griesser on 23/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Vicrab/Vicrab.h>)
#import <Vicrab/VicrabDefines.h>
#else
#import "VicrabDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class VicrabEvent, VicrabBreadcrumb, VicrabDsn;

@interface VicrabFileManager : NSObject
VICRAB_NO_INIT

- (_Nullable instancetype)initWithDsn:(VicrabDsn *)dsn didFailWithError:(NSError **)error;

- (NSString *)storeEvent:(VicrabEvent *)event;
- (NSString *)storeEvent:(VicrabEvent *)event maxCount:(NSUInteger)maxCount;

- (NSString *)storeBreadcrumb:(VicrabBreadcrumb *)crumb;
- (NSString *)storeBreadcrumb:(VicrabBreadcrumb *)crumb maxCount:(NSUInteger)maxCount;

+ (BOOL)createDirectoryAtPath:(NSString *)path withError:(NSError **)error;

- (void)deleteAllStoredEvents;

- (void)deleteAllStoredBreadcrumbs;

- (void)deleteAllFolders;

- (NSArray<NSDictionary<NSString *, id> *> *)getAllStoredEvents;

- (NSArray<NSDictionary<NSString *, id> *> *)getAllStoredBreadcrumbs;

- (BOOL)removeFileAtPath:(NSString *)path;

- (NSArray<NSString *> *)allFilesInFolder:(NSString *)path;

- (NSString *)storeDictionary:(NSDictionary *)dictionary toPath:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
