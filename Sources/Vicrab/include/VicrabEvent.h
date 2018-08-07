//
//  VicrabEvent.h
//  Vicrab
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Vicrab/Vicrab.h>)
#import <Vicrab/VicrabDefines.h>
#import <Vicrab/VicrabSerializable.h>
#else
#import "VicrabDefines.h"
#import "VicrabSerializable.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@class VicrabThread, VicrabException, VicrabStacktrace, VicrabUser, VicrabDebugMeta, VicrabContext;

NS_SWIFT_NAME(Event)
@interface VicrabEvent : NSObject <VicrabSerializable>
VICRAB_NO_INIT

/**
 * This will be set by the initializer. Should be an UUID with the "-".
 */
@property(nonatomic, copy) NSString *eventId;

/**
 * Message of the event
 */
@property(nonatomic, copy) NSString *message;

/**
 * NSDate of when the event occured
 */
@property(nonatomic, strong) NSDate *timestamp;

/**
 * VicrabSeverity of the event
 */
@property(nonatomic) enum VicrabSeverity level;

/**
 * Platform this will be used for symbolicating on the server should be "cocoa"
 */
@property(nonatomic, copy) NSString *platform;

/**
 * Define the logger name
 */
@property(nonatomic, copy) NSString *_Nullable logger;

/**
 * Define the server name
 */
@property(nonatomic, copy) NSString *_Nullable serverName;

/**
 * This property will be filled before the event is sent. Do not change it otherwise you know what you are doing.
 */
@property(nonatomic, copy) NSString *_Nullable releaseName;

/**
 * This property will be filled before the event is sent. Do not change it otherwise you know what you are doing.
 */
@property(nonatomic, copy) NSString *_Nullable dist;

/**
 * The environment used for this event
 */
@property(nonatomic, copy) NSString *_Nullable environment;

/**
 * The current transaction (state) on the crash
 */
@property(nonatomic, copy) NSString *_Nullable transaction;

/**
 * Arbitrary key:value (string:string ) data that will be shown with the event
 */
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable tags;

/**
 * Arbitrary additional information that will be sent with the event
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable extra;

/**
 * Information about the sdk can be something like this. This will be set for you
 * Don't touch it if you not know what you are doing.
 *
 * {
 *  version: "3.3.3",
 *  name: "vicrab-cocoa",
 *  integrations: [
 *      "react-native"
 *  ]
 * }
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable sdk;

/**
 * Modules of the event
 */
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable modules;

/**
 * Set the fingerprint of an event to determine the grouping
 */
@property(nonatomic, strong) NSArray<NSString *> *_Nullable fingerprint;

/**
 * Set the VicrabUser for the event
 */
@property(nonatomic, strong) VicrabUser *_Nullable user;

/**
 * This object contains meta information, will be set automatically overwrite only if you know what you are doing
 */
@property(nonatomic, strong) VicrabContext *_Nullable context;

/**
 * Contains VicrabThread if an crash occurred of it's an user reported exception
 */
@property(nonatomic, strong) NSArray<VicrabThread *> *_Nullable threads;

/**
 * General information about the VicrabException, usually there is only one exception in the array
 */
@property(nonatomic, strong) NSArray<VicrabException *> *_Nullable exceptions;

/**
 * Separate VicrabStacktrace that can be sent with the event, besides threads
 */
@property(nonatomic, strong) VicrabStacktrace *_Nullable stacktrace;

/**
 * Containing images loaded during runtime
 */
@property(nonatomic, strong) NSArray<VicrabDebugMeta *> *_Nullable debugMeta;

/**
 * This contains all breadcrumbs available at the time when the event occurred/will be sent
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable breadcrumbsSerialized;

/**
 * This property is there for setting main bundle of the app
 */
@property(nonatomic, strong) NSDictionary *infoDict;

/**
 * Init an VicrabEvent will set all needed fields by default
 * @param level VicrabSeverity
 * @return VicrabEvent
 */
- (instancetype)initWithLevel:(enum VicrabSeverity)level;

@end

NS_ASSUME_NONNULL_END
