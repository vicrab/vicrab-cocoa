//
//  VicrabCrashReportConverter.h
//  Vicrab
//
//  Created by Daniel Griesser on 10/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

@class VicrabEvent;

NS_ASSUME_NONNULL_BEGIN

@interface VicrabCrashReportConverter : NSObject

@property(nonatomic, strong) NSDictionary *userContext;

- (instancetype)initWithReport:(NSDictionary *)report;

- (VicrabEvent *)convertReportToEvent;

@end

NS_ASSUME_NONNULL_END
