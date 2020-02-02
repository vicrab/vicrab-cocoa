//
//  VicrabOptions.h
//  Vicrab
//
//  Created by Daniel Griesser on 12.03.19.
//  Copyright © 2019 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Vicrab/Vicrab.h>)
#import <Vicrab/VicrabDefines.h>
#else
#import "VicrabDefines.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class VicrabDsn;

NS_SWIFT_NAME(Options)
@interface VicrabOptions : NSObject
VICRAB_NO_INIT

    
/**
 * Init VicrabOptions.
 * @param options Options dictionary
 * @return VicrabOptions
 */
- (_Nullable instancetype)initWithOptions:(NSDictionary<NSString *, id> *)options
                         didFailWithError:(NSError *_Nullable *_Nullable)error;
    
/**
 * The Dsn passed in the options.
 */
@property(nonatomic, strong) VicrabDsn *dsn;

/**
 * This property will be filled before the event is sent.
 */
@property(nonatomic, copy) NSString *_Nullable releaseName;

/**
 * This property will be filled before the event is sent.
 */
@property(nonatomic, copy) NSString *_Nullable dist;

/**
 * The environment used for this event
 */
@property(nonatomic, copy) NSString *_Nullable environment;
    
/**
 * Is the client enabled?. Default is @YES, if set @NO sending of events will be prevented.
 */
@property(nonatomic, copy) NSNumber *enabled;

@end

NS_ASSUME_NONNULL_END
