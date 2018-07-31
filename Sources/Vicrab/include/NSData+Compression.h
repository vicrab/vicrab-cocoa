//
//  NSData+Compression.h
//  Vicrab
//
//  Created by Daniel Griesser on 08/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (Compression)

- (NSData *_Nullable)vicrab_gzippedWithCompressionLevel:(NSInteger)compressionLevel
                                           error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
