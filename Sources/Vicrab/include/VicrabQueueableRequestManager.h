//
//  VicrabQueueableRequestManager.h
//  Vicrab
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabDefines.h>

#else
#import "VicrabDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@protocol VicrabRequestManager

@property(nonatomic, readonly, getter = isReady) BOOL ready;

- (instancetype)initWithSession:(NSURLSession *)session;

- (void)addRequest:(NSURLRequest *)request completionHandler:(_Nullable VicrabRequestOperationFinished)completionHandler;

- (void)cancelAllOperations;

@end

@interface VicrabQueueableRequestManager : NSObject <VicrabRequestManager>

@end

NS_ASSUME_NONNULL_END
