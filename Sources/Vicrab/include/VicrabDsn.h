//
//  VicrabDsn.h
//  Vicrab
//
//  Created by Daniel Griesser on 03/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VicrabDsn : NSObject

@property(nonatomic, strong) NSURL *url;

- (_Nullable instancetype)initWithString:(NSString *)dsnString didFailWithError:(NSError *_Nullable *_Nullable)error;

- (NSString *)getHash;

@end

NS_ASSUME_NONNULL_END
