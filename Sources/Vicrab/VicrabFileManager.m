//
//  VicrabFileManager.m
//  Vicrab
//
//  Created by Daniel Griesser on 23/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabFileManager.h>
#import <Vicrab/VicrabError.h>
#import <Vicrab/VicrabLog.h>
#import <Vicrab/VicrabEvent.h>
#import <Vicrab/VicrabBreadcrumb.h>
#import <Vicrab/VicrabDsn.h>

#else
#import "VicrabFileManager.h"
#import "VicrabError.h"
#import "VicrabLog.h"
#import "VicrabEvent.h"
#import "VicrabBreadcrumb.h"
#import "VicrabDsn.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NSInteger const defaultMaxEvents = 10;
NSInteger const defaultMaxBreadcrumbs = 200;

@interface VicrabFileManager ()

@property(nonatomic, copy) NSString *vicrabPath;
@property(nonatomic, copy) NSString *breadcrumbsPath;
@property(nonatomic, copy) NSString *eventsPath;
@property(nonatomic, assign) NSUInteger currentFileCounter;

@end

@implementation VicrabFileManager

- (_Nullable instancetype)initWithDsn:(VicrabDsn *)dsn didFailWithError:(NSError **)error {
    self = [super init];
    if (self) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        
        self.vicrabPath = [cachePath stringByAppendingPathComponent:@"io.vicrab"];
        self.vicrabPath = [self.vicrabPath stringByAppendingPathComponent:[dsn getHash]];
        
        if (![fileManager fileExistsAtPath:self.vicrabPath]) {
            [self.class createDirectoryAtPath:self.vicrabPath withError:error];
        }

        self.breadcrumbsPath = [self.vicrabPath stringByAppendingPathComponent:@"breadcrumbs"];
        if (![fileManager fileExistsAtPath:self.breadcrumbsPath]) {
            [self.class createDirectoryAtPath:self.breadcrumbsPath withError:error];
        }

        self.eventsPath = [self.vicrabPath stringByAppendingPathComponent:@"events"];
        if (![fileManager fileExistsAtPath:self.eventsPath]) {
            [self.class createDirectoryAtPath:self.eventsPath withError:error];
        }

        self.currentFileCounter = 0;
        self.maxEvents = defaultMaxEvents;
        self.maxBreadcrumbs = defaultMaxBreadcrumbs;
    }
    return self;
}

- (void)deleteAllFolders {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:self.breadcrumbsPath error:nil];
    [fileManager removeItemAtPath:self.eventsPath error:nil];
    [fileManager removeItemAtPath:self.vicrabPath error:nil];
}

- (NSString *)uniqueAcendingJsonName {
    return [NSString stringWithFormat:@"%f-%lu-%@.json",
                                      [[NSDate date] timeIntervalSince1970],
                                      (unsigned long) self.currentFileCounter++,
                                      [NSUUID UUID].UUIDString];
}

- (NSArray<NSDictionary<NSString *, id> *> *)getAllStoredEvents {
    return [self allFilesContentInFolder:self.eventsPath];
}

- (NSArray<NSDictionary<NSString *, id> *> *)getAllStoredBreadcrumbs {
    return [self allFilesContentInFolder:self.breadcrumbsPath];
}

- (NSArray<NSDictionary<NSString *, id> *> *)allFilesContentInFolder:(NSString *)path {
    @synchronized (self) {
        NSMutableArray *contents = [NSMutableArray new];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        for (NSString *filePath in [self allFilesInFolder:path]) {
            NSString *finalPath = [path stringByAppendingPathComponent:filePath];
            NSData *content = [fileManager contentsAtPath:finalPath];
            if (nil != content) {
                [contents addObject:@{@"path": finalPath, @"data": content}];
            }
        }
        return contents;
    }
}

- (void)deleteAllStoredEvents {
    for (NSString *path in [self allFilesInFolder:self.eventsPath]) {
        [self removeFileAtPath:[self.eventsPath stringByAppendingPathComponent:path]];
    }
}

- (void)deleteAllStoredBreadcrumbs {
    for (NSString *path in [self allFilesInFolder:self.breadcrumbsPath]) {
        [self removeFileAtPath:[self.breadcrumbsPath stringByAppendingPathComponent:path]];
    }
}

- (NSArray<NSString *> *)allFilesInFolder:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray <NSString *> *storedFiles = [fileManager contentsOfDirectoryAtPath:path error:&error];
    if (nil != error) {
        [VicrabLog logWithMessage:[NSString stringWithFormat:@"Couldn't load files in folder %@: %@", path, error] andLevel:kVicrabLogLevelError];
        return [NSArray new];
    }
    return [storedFiles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (BOOL)removeFileAtPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    @synchronized (self) {
        [fileManager removeItemAtPath:path error:&error];
        if (nil != error) {
            [VicrabLog logWithMessage:[NSString stringWithFormat:@"Couldn't delete file %@: %@", path, error] andLevel:kVicrabLogLevelError];
            return NO;
        }
    }
    return YES;
}

- (NSString *)storeEvent:(VicrabEvent *)event {
    return [self storeEvent:event maxCount:self.maxEvents];
}

- (NSString *)storeEvent:(VicrabEvent *)event maxCount:(NSUInteger)maxCount {
    @synchronized (self) {
        NSString *result;
        if (nil != event.json) {
            result = [self storeData:event.json toPath:self.eventsPath];
        } else {
            result = [self storeDictionary:[event serialize] toPath:self.eventsPath];
        }
        [self handleFileManagerLimit:self.eventsPath maxCount:maxCount];
        return result;
    }
}

- (NSString *)storeBreadcrumb:(VicrabBreadcrumb *)crumb {
    return [self storeBreadcrumb:crumb maxCount:self.maxBreadcrumbs];
}

- (NSString *)storeBreadcrumb:(VicrabBreadcrumb *)crumb maxCount:(NSUInteger)maxCount {
    @synchronized (self) {
        NSString *result = [self storeDictionary:[crumb serialize] toPath:self.breadcrumbsPath];
        [self handleFileManagerLimit:self.breadcrumbsPath maxCount:MIN(maxCount, self.maxBreadcrumbs)];
        return result;
    }
}

- (NSString *)storeData:(NSData *)data toPath:(NSString *)path {
    @synchronized (self) {
        NSString *finalPath = [path stringByAppendingPathComponent:[self uniqueAcendingJsonName]];
        [VicrabLog logWithMessage:[NSString stringWithFormat:@"Writing to file: %@", finalPath] andLevel:kVicrabLogLevelDebug];
        [data writeToFile:finalPath options:NSDataWritingAtomic error:nil];
        return finalPath;
    }
}

- (NSString *)storeDictionary:(NSDictionary *)dictionary toPath:(NSString *)path {
    if ([NSJSONSerialization isValidJSONObject:dictionary]) {
        NSData *saveData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil];
        return [self storeData:saveData toPath:path];
    } else {
        [VicrabLog logWithMessage:[NSString stringWithFormat:@"Invalid JSON, failed to write file %@", path]
                         andLevel:kVicrabLogLevelError];
    }
    return path;
}

- (void)handleFileManagerLimit:(NSString *)path maxCount:(NSUInteger)maxCount {
    NSArray<NSString *> *files = [self allFilesInFolder:path];
    NSInteger numbersOfFilesToRemove = ((NSInteger)files.count) - maxCount;
    if (numbersOfFilesToRemove > 0) {
        for (NSUInteger i = 0; i < numbersOfFilesToRemove; i++) {
            [self removeFileAtPath:[path stringByAppendingPathComponent:[files objectAtIndex:i]]];
        }
        [VicrabLog logWithMessage:[NSString stringWithFormat:@"Removed %ld file(s) from <%@>", (long)numbersOfFilesToRemove, [path lastPathComponent]]
                         andLevel:kVicrabLogLevelDebug];
    }
}

+ (BOOL)createDirectoryAtPath:(NSString *)path withError:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager createDirectoryAtPath:path
                  withIntermediateDirectories:YES
                                   attributes:nil
                                        error:error];
}

@end

NS_ASSUME_NONNULL_END
