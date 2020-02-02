//
//  VicrabRequestOperation.h
//  Vicrab
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabQueueableRequestManager.h>
#import <Vicrab/VicrabAsynchronousOperation.h>

#else
#import "VicrabQueueableRequestManager.h"
#import "VicrabAsynchronousOperation.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface VicrabRequestOperation : VicrabAsynchronousOperation

- (instancetype)initWithSession:(NSURLSession *)session request:(NSURLRequest *)request
              completionHandler:(_Nullable VicrabRequestOperationFinished)completionHandler;

@end

NS_ASSUME_NONNULL_END
