//
//  VicrabClient.h
//  Vicrab
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabDefines.h>

#else
#import "VicrabDefines.h"
#endif

@class VicrabEvent, VicrabBreadcrumbStore, VicrabUser, VicrabThread;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Client)
@interface VicrabClient : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 * Return a version string e.g: 1.2.3 (3)
 */
@property(nonatomic, class, readonly, copy) NSString *versionString;

/**
 * Return a string vicrab-cocoa
 */
@property(nonatomic, class, readonly, copy) NSString *sdkName;

/**
 * Set logLevel for the current client default kVicrabLogLevelError
 */
@property(nonatomic, class) VicrabLogLevel logLevel;

/**
 * Set global user -> thus will be sent with every event
 */
@property(nonatomic, strong) VicrabUser *_Nullable user;

/**
 * Set global tags -> these will be sent with every event
 */
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable tags;

/**
 * Set global extra -> these will be sent with every event
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable extra;

/**
 * This will be filled on every startup with a dictionary with extra, tags, user which will be used
 * when sending the crashreport
 */
@property(nonatomic, strong) NSDictionary<NSString *, id> *_Nullable lastContext;

/**
 * Contains the last successfully sent event
 */
@property(nonatomic, strong) VicrabEvent *_Nullable lastEvent;

/**
 * Contains the last successfully sent event
 */
@property(nonatomic, strong) VicrabBreadcrumbStore *breadcrumbs;

/**
 * This block can be used to modify the event before it will be serialized and sent
 */
@property(nonatomic, copy) VicrabBeforeSerializeEvent _Nullable beforeSerializeEvent;

/**
 * This block can be used to modify the request before its put on the request queue.
 * Can be used e.g. to set additional http headers before sending
 */
@property(nonatomic, copy) VicrabBeforeSendRequest _Nullable beforeSendRequest;

/**
 * This block can be used to prevent the event from being sent.
 * @return BOOL
 */
@property(nonatomic, copy) VicrabShouldSendEvent _Nullable shouldSendEvent;

/**
 * Returns the shared vicrab client
 * @return sharedClient if it was set before
 */
@property(nonatomic, class) VicrabClient *_Nullable sharedClient;

/**
 * Defines the sample rate of VicrabClient, should be a float between 0.0 and 1.0
 * Setting this property sets shouldSendEvent callback and applies a random event sampler.
 */
@property(nonatomic) float sampleRate;

/**
 * This block can be used to prevent the event from being deleted after a failed send attempt.
 * Default is it will only be stored once after you hit a rate limit or there is no internet connect/cannot connect.
 * Also note that if an event fails to be sent again after it was queued, it will be discarded regardless.
 * @return BOOL YES = store and try again later, NO = delete
 */
@property(nonatomic, copy) VicrabShouldQueueEvent _Nullable shouldQueueEvent;

/**
 * Initializes a VicrabClient. Pass your private DSN string.
 *
 * @param dsn DSN string of vicrab
 * @param error NSError reference object
 * @return VicrabClient
 */
- (_Nullable instancetype)initWithDsn:(NSString *)dsn
                     didFailWithError:(NSError *_Nullable *_Nullable)error;

/**
 * This automatically adds breadcrumbs for different user actions.
 */
- (void)enableAutomaticBreadcrumbTracking;

/**
 * Sends and event to vicrab. Internally calls @selector(sendEvent:useClientProperties:withCompletionHandler:) with
 * useClientProperties: YES. CompletionHandler will be called if set.
 * @param event VicrabEvent that should be sent
 * @param completionHandler VicrabRequestFinished
 */
- (void)sendEvent:(VicrabEvent *)event withCompletionHandler:(_Nullable VicrabRequestFinished)completionHandler
NS_SWIFT_NAME(send(event:completion:));

/**
 * This function stores an event to disk. It will be send with the next batch.
 * This function is mainly used for react native.
 * @param event VicrabEvent that should be sent
 */
- (void)storeEvent:(VicrabEvent *)event;

/**
 * Clears all context related variables tags, extra and user
 */
- (void)clearContext;

/// VicrabCrash
/// Functions below will only do something if VicrabCrash is linked

/**
 * This forces a crash, useful to test the VicrabCrash integration
 *
 */
- (void)crash;

/**
 * This function tries to start the VicrabCrash handler, return YES if successfully started
 * otherwise it will return false and set error
 *
 * @param error if VicrabCrash is not available error will be set
 * @return successful
 */
- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error;

/**
 * Report a custom, user defined exception. Only works if VicrabCrash is linked.
 * This can be useful when dealing with scripting languages.
 *
 * If terminateProgram is true, all sentries will be uninstalled and the application will
 * terminate with an abort().
 *
 * @param name The exception name (for namespacing exception types).
 * @param reason A description of why the exception occurred.
 * @param language A unique language identifier.
 * @param lineOfCode A copy of the offending line of code (nil = ignore).
 * @param stackTrace An array of frames (dictionaries or strings) representing the call stack leading to the exception (nil = ignore).
 * @param logAllThreads If YES, suspend all threads and log their state. Note that this incurs a
 *                      performance penalty, so it's best to use only on fatal errors.
 * @param terminateProgram If YES, do not return from this function call. Terminate the program instead.
 */
- (void)reportUserException:(NSString *)name
                     reason:(NSString *)reason
                   language:(NSString *)language
                 lineOfCode:(NSString *)lineOfCode
                 stackTrace:(NSArray *)stackTrace
              logAllThreads:(BOOL)logAllThreads
           terminateProgram:(BOOL)terminateProgram;

/**
 * Returns true if the app crashed before launching now
 */
- (BOOL)crashedLastLaunch;

/**
 * This will snapshot the whole stacktrace at the time when its called. This stacktrace will be attached with the next sent event.
 * Please note to also call appendStacktraceToEvent in the callback in order to send the stacktrace with the event.
 */
- (void)snapshotStacktrace:(void (^)(void))snapshotCompleted;

/**
 * This appends the stored stacktrace (if existant) to the event.
 *
 * @param event VicrabEvent event
 */
- (void)appendStacktraceToEvent:(VicrabEvent *)event;

@end

NS_ASSUME_NONNULL_END
