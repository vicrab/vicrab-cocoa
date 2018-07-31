//
//  VicrabNSURLRequest.h
//  Vicrab
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class VicrabDsn, VicrabEvent;

@interface VicrabNSURLRequest : NSMutableURLRequest

- (_Nullable instancetype)initStoreRequestWithDsn:(VicrabDsn *)dsn
                                         andEvent:(VicrabEvent *)event
                                 didFailWithError:(NSError *_Nullable *_Nullable)error;

- (_Nullable instancetype)initStoreRequestWithDsn:(VicrabDsn *)dsn
                                          andData:(NSData *)data
                                 didFailWithError:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
