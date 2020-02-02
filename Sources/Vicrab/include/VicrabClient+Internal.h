//
//  VicrabClient+Internal.h
//  Vicrab
//
//  Created by Daniel Griesser on 01/06/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//


#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabClient.h>
#import <Vicrab/VicrabDebugMeta.h>

#else
#import "VicrabClient.h"
#import "VicrabDebugMeta.h"
#endif

@interface VicrabClient ()

@property(nonatomic, strong) NSArray<VicrabThread *> *_Nullable _snapshotThreads;
@property(nonatomic, strong) NSArray<VicrabDebugMeta *> *_Nullable _debugMeta;

@end
