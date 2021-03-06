//
//  VicrabClient.m
//  Vicrab
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Vicrab. All rights reserved.
//

#if __has_include(<Vicrab/Vicrab.h>)

#import <Vicrab/VicrabClient.h>
#import <Vicrab/VicrabClient+Internal.h>
#import <Vicrab/VicrabLog.h>
#import <Vicrab/VicrabDsn.h>
#import <Vicrab/VicrabError.h>
#import <Vicrab/VicrabUser.h>
#import <Vicrab/VicrabQueueableRequestManager.h>
#import <Vicrab/VicrabEvent.h>
#import <Vicrab/VicrabNSURLRequest.h>
#import <Vicrab/VicrabInstallation.h>
#import <Vicrab/VicrabBreadcrumbStore.h>
#import <Vicrab/VicrabFileManager.h>
#import <Vicrab/VicrabBreadcrumbTracker.h>
#import <Vicrab/VicrabCrash.h>
#import <Vicrab/VicrabOptions.h>
#else
#import "VicrabClient.h"
#import "VicrabClient+Internal.h"
#import "VicrabLog.h"
#import "VicrabDsn.h"
#import "VicrabError.h"
#import "VicrabUser.h"
#import "VicrabQueueableRequestManager.h"
#import "VicrabEvent.h"
#import "VicrabNSURLRequest.h"
#import "VicrabInstallation.h"
#import "VicrabBreadcrumbStore.h"
#import "VicrabFileManager.h"
#import "VicrabBreadcrumbTracker.h"
#import "VicrabCrash.h"
#import "VicrabOptions.h"
#endif

#if VICRAB_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

NSString *const VicrabClientVersionString = @"0.4.1";//配置vicrab_secret值
NSString *const VicrabClientSdkName = @"vicrab-cocoa";

static VicrabClient *sharedClient = nil;
static VicrabLogLevel logLevel = kVicrabLogLevelError;

static VicrabInstallation *installation = nil;

@interface VicrabClient ()

@property(nonatomic, strong) VicrabDsn *dsn;
@property(nonatomic, strong) VicrabFileManager *fileManager;
@property(nonatomic, strong) id <VicrabRequestManager> requestManager;

@end

@implementation VicrabClient

@synthesize environment = _environment;
@synthesize releaseName = _releaseName;
@synthesize dist = _dist;
@synthesize tags = _tags;
@synthesize extra = _extra;
@synthesize user = _user;
@synthesize sampleRate = _sampleRate;
@synthesize maxEvents = _maxEvents;
@synthesize maxBreadcrumbs = _maxBreadcrumbs;
@dynamic logLevel;

#pragma mark Initializer

- (_Nullable instancetype)initWithOptions:(NSDictionary<NSString *, id> *)options
                         didFailWithError:(NSError *_Nullable *_Nullable)error {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    return [self initWithOptions:options
                  requestManager:[[VicrabQueueableRequestManager alloc] initWithSession:session]
                didFailWithError:error];
}
    
    
- (_Nullable instancetype)initWithDsn:(NSString *)dsn
                     didFailWithError:(NSError *_Nullable *_Nullable)error {
    return [self initWithOptions:@{@"dsn": dsn}
                didFailWithError:error];
}

- (_Nullable instancetype)initWithOptions:(NSDictionary<NSString *, id> *)options
                           requestManager:(id <VicrabRequestManager>)requestManager
                         didFailWithError:(NSError *_Nullable *_Nullable)error {
    self = [super init];
    if (self) {
        [self restoreContextBeforeCrash];
        [self setupQueueing];
        _extra = [NSDictionary new];
        _tags = [NSDictionary new];
        
        VicrabOptions *vicrabOptions = [[VicrabOptions alloc] initWithOptions:options didFailWithError:error];
        if (nil != error && nil != *error) {
            [VicrabLog logWithMessage:(*error).localizedDescription andLevel:kVicrabLogLevelError];
            return nil;
        }
        
        if (nil == vicrabOptions.enabled) {
            self.enabled = @YES;
        } else {
            self.enabled = vicrabOptions.enabled;
        }
        self.dsn = vicrabOptions.dsn;
        self.environment = vicrabOptions.environment;
        self.releaseName = vicrabOptions.releaseName;
        self.dist = vicrabOptions.dist;
        
        self.requestManager = requestManager;
        if (logLevel > 1) { // If loglevel is set > None
            NSLog(@"Vicrab Started -- Version: %@", self.class.versionString);
        }
        self.fileManager = [[VicrabFileManager alloc] initWithDsn:self.dsn didFailWithError:error];
        self.breadcrumbs = [[VicrabBreadcrumbStore alloc] initWithFileManager:self.fileManager];
        if (nil != error && nil != *error) {
            [VicrabLog logWithMessage:(*error).localizedDescription andLevel:kVicrabLogLevelError];
            return nil;
        }
        
        // We want to send all stored events on start up
        if ([self.enabled boolValue] && [self.requestManager isReady]) {
            [self sendAllStoredEvents];
        }
    }
    return self;
}

- (void)setupQueueing {
    self.shouldQueueEvent = ^BOOL(VicrabEvent *_Nonnull event, NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
        // Taken from Apple Docs:
        // If a response from the server is received, regardless of whether the request completes successfully or fails,
        // the response parameter contains that information.
        if (response == nil) {
            // In case response is nil, we want to queue the event locally since this
            // indicates no internet connection
            return YES;
        } else if ([response statusCode] == 429) {
            [VicrabLog logWithMessage:@"Rate limit reached, event will be stored and sent later" andLevel:kVicrabLogLevelError];
            return YES;
        }
        // In all other cases we don't want to retry sending it and just discard the event
        return NO;
    };
}

- (void)enableAutomaticBreadcrumbTracking {
    [[VicrabBreadcrumbTracker alloc] start];
}

- (void)trackMemoryPressureAsEvent {
    #if VICRAB_HAS_UIKIT
    __weak VicrabClient *weakSelf = self;
    VicrabEvent *event = [[VicrabEvent alloc] initWithLevel:kVicrabSeverityWarning];
    event.message = @"Memory Warning";
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    [weakSelf storeEvent:event];
                                                }];
    #endif
}

#pragma mark Static Getter/Setter

+ (_Nullable instancetype)sharedClient {
    return sharedClient;
}

+ (void)setSharedClient:(VicrabClient *_Nullable)client {
    sharedClient = client;
}

+ (NSString *)versionString {
    return VicrabClientVersionString;
}

+ (NSString *)sdkName {
    return VicrabClientSdkName;
}

+ (void)setLogLevel:(VicrabLogLevel)level {
    NSParameterAssert(level);
    logLevel = level;
}

+ (VicrabLogLevel)logLevel {
    return logLevel;
}

#pragma mark Event

- (void)sendEvent:(VicrabEvent *)event withCompletionHandler:(_Nullable VicrabRequestFinished)completionHandler {
    [self sendEvent:event useClientProperties:YES withCompletionHandler:completionHandler];
}

- (void)prepareEvent:(VicrabEvent *)event
 useClientProperties:(BOOL)useClientProperties {
    NSParameterAssert(event);
    if (useClientProperties) {
        [self setSharedPropertiesOnEvent:event];
    }

    if (nil != self.beforeSerializeEvent) {
        self.beforeSerializeEvent(event);
    }
}

- (void)storeEvent:(VicrabEvent *)event {
    [self prepareEvent:event useClientProperties:YES];
    [self.fileManager storeEvent:event];
}

- (void)    sendEvent:(VicrabEvent *)event
  useClientProperties:(BOOL)useClientProperties
withCompletionHandler:(_Nullable VicrabRequestFinished)completionHandler {
    [self prepareEvent:event useClientProperties:useClientProperties];

    if (nil != self.shouldSendEvent && !self.shouldSendEvent(event)) {
        NSString *message = @"VicrabClient shouldSendEvent returned NO so we will not send the event";
        [VicrabLog logWithMessage:message andLevel:kVicrabLogLevelDebug];
        if (completionHandler) {
            completionHandler(NSErrorFromVicrabError(kVicrabErrorEventNotSent, message));
        }
        return;
    }

    NSError *requestError = nil;
    VicrabNSURLRequest *request = [[VicrabNSURLRequest alloc] initStoreRequestWithDsn:self.dsn
                                                                             andEvent:event
                                                                     didFailWithError:&requestError];
    if (nil != requestError) {
        [VicrabLog logWithMessage:requestError.localizedDescription andLevel:kVicrabLogLevelError];
        if (completionHandler) {
            completionHandler(requestError);
        }
        return;
    }

    NSString *storedEventPath = [self.fileManager storeEvent:event];
    
    if (![self.enabled boolValue]) {
        [VicrabLog logWithMessage:@"VicrabClient is disabled, event will be stored to send later." andLevel:kVicrabLogLevelDebug];
        return;
    }
    
    __block VicrabClient *_self = self;
    [self sendRequest:request withCompletionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
        // We check if we should leave the event locally stored and try to send it again later
        if (self.shouldQueueEvent == nil || self.shouldQueueEvent(event, response, error) == NO) {
            [_self.fileManager removeFileAtPath:storedEventPath];
        }
        if (nil == error) {
            _self.lastEvent = event;
            [NSNotificationCenter.defaultCenter postNotificationName:@"Vicrab/eventSentSuccessfully"
                                                              object:nil
                                                            userInfo:[event serialize]];
            // Send all stored events in background if the queue is ready
            if ([_self.enabled boolValue] && [_self.requestManager isReady]) {
                [_self sendAllStoredEvents];
            }
        }
        if (completionHandler) {
            completionHandler(error);
        }
    }];
}

- (void)  sendRequest:(VicrabNSURLRequest *)request
withCompletionHandler:(_Nullable VicrabRequestOperationFinished)completionHandler {
    if (nil != self.beforeSendRequest) {
        self.beforeSendRequest(request);
    }
    [self.requestManager addRequest:request completionHandler:completionHandler];
}

- (void)sendAllStoredEvents {
    dispatch_group_t dispatchGroup = dispatch_group_create();

    for (NSDictionary<NSString *, id> *fileDictionary in [self.fileManager getAllStoredEvents]) {
        dispatch_group_enter(dispatchGroup);

        VicrabNSURLRequest *request = [[VicrabNSURLRequest alloc] initStoreRequestWithDsn:self.dsn
                                                                                  andData:fileDictionary[@"data"]
                                                                         didFailWithError:nil];
        [self sendRequest:request withCompletionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
            if (nil == error) {
                NSDictionary *serializedEvent = [NSJSONSerialization JSONObjectWithData:fileDictionary[@"data"]
                                                                                options:0
                                                                                  error:nil];
                if (nil != serializedEvent) {
                    [NSNotificationCenter.defaultCenter postNotificationName:@"Vicrab/eventSentSuccessfully"
                                                                      object:nil
                                                                    userInfo:serializedEvent];
                }
            }
            // We want to delete the event here no matter what (if we had an internet connection)
            // since it has been tried already
            if (response != nil) {
                [self.fileManager removeFileAtPath:fileDictionary[@"path"]];
            }

            dispatch_group_leave(dispatchGroup);
        }];
    }

    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:@"Vicrab/allStoredEventsSent"
                                                          object:nil
                                                        userInfo:nil];
    });
}

- (void)setSharedPropertiesOnEvent:(VicrabEvent *)event {
    if (nil != self.tags) {
        if (nil == event.tags) {
            event.tags = self.tags;
        } else {
            NSMutableDictionary *newTags = [NSMutableDictionary new];
            [newTags addEntriesFromDictionary:self.tags];
            [newTags addEntriesFromDictionary:event.tags];
            event.tags = newTags;
        }
    }

    if (nil != self.extra) {
        if (nil == event.extra) {
            event.extra = self.extra;
        } else {
            NSMutableDictionary *newExtra = [NSMutableDictionary new];
            [newExtra addEntriesFromDictionary:self.extra];
            [newExtra addEntriesFromDictionary:event.extra];
            event.extra = newExtra;
        }
    }

    if (nil != self.user && nil == event.user) {
        event.user = self.user;
    }

    if (nil == event.breadcrumbsSerialized) {
        event.breadcrumbsSerialized = [self.breadcrumbs serialize];
    }

    if (nil == event.infoDict) {
        event.infoDict = [[NSBundle mainBundle] infoDictionary];
    }
    
    if (nil != self.environment && nil == event.environment) {
        event.environment = self.environment;
    }
    
    if (nil != self.releaseName && nil == event.releaseName) {
        event.releaseName = self.releaseName;
    }
    
    if (nil != self.dist && nil == event.dist) {
        event.dist = self.dist;
    }
}

- (void)appendStacktraceToEvent:(VicrabEvent *)event {
    if (nil != self._snapshotThreads && nil != self._debugMeta) {
        event.threads = self._snapshotThreads;
        event.debugMeta = self._debugMeta;
    }
}

#pragma mark Global properties

- (void)setTags:(NSDictionary<NSString *, NSString *> *_Nullable)tags {
    [[NSUserDefaults standardUserDefaults] setObject:tags forKey:@"vicrab.io.tags"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _tags = tags;
}

- (void)setExtra:(NSDictionary<NSString *, id> *_Nullable)extra {
    [[NSUserDefaults standardUserDefaults] setObject:extra forKey:@"vicrab.io.extra"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _extra = extra;
}

- (void)setUser:(VicrabUser *_Nullable)user {
    [[NSUserDefaults standardUserDefaults] setObject:[user serialize] forKey:@"vicrab.io.user"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _user = user;
}
    
- (void)setReleaseName:(NSString *_Nullable)releaseName {
    [[NSUserDefaults standardUserDefaults] setObject:releaseName forKey:@"vicrab.io.releaseName"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _releaseName = releaseName;
}
    
- (void)setDist:(NSString *_Nullable)dist {
    [[NSUserDefaults standardUserDefaults] setObject:dist forKey:@"vicrab.io.dist"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _dist = dist;
}
    
- (void)setEnvironment:(NSString *_Nullable)environment {
    [[NSUserDefaults standardUserDefaults] setObject:environment forKey:@"vicrab.io.environment"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _environment = environment;
}

- (void)clearContext {
    [self setReleaseName:nil];
    [self setDist:nil];
    [self setEnvironment:nil];
    [self setUser:nil];
    [self setExtra:[NSDictionary new]];
    [self setTags:[NSDictionary new]];
}

- (void)restoreContextBeforeCrash {
    NSMutableDictionary *context = [[NSMutableDictionary alloc] init];
    [context setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"vicrab.io.tags"] forKey:@"tags"];
    [context setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"vicrab.io.extra"] forKey:@"extra"];
    [context setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"vicrab.io.user"] forKey:@"user"];
    [context setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"vicrab.io.releaseName"] forKey:@"releaseName"];
    [context setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"vicrab.io.dist"] forKey:@"dist"];
    [context setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"vicrab.io.environment"] forKey:@"environment"];
    self.lastContext = context;
}

- (void)setSampleRate:(float)sampleRate {
    if (sampleRate < 0 || sampleRate > 1) {
        [VicrabLog logWithMessage:@"sampleRate must be between 0.0 and 1.0" andLevel:kVicrabLogLevelError];
        return;
    }
    _sampleRate = sampleRate;
    self.shouldSendEvent = ^BOOL(VicrabEvent *_Nonnull event) {
        return (sampleRate >= ((double)arc4random() / 0x100000000));
    };
}

- (void)setMaxEvents:(NSUInteger)maxEvents {
    self.fileManager.maxEvents = maxEvents;
}

- (void)setMaxBreadcrumbs:(NSUInteger)maxBreadcrumbs {
    self.fileManager.maxBreadcrumbs = maxBreadcrumbs;
}

#pragma mark VicrabCrash

- (BOOL)crashedLastLaunch {
    return VicrabCrash.sharedInstance.crashedLastLaunch;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error {
    [VicrabLog logWithMessage:@"VicrabCrashHandler started" andLevel:kVicrabLogLevelDebug];
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        installation = [[VicrabInstallation alloc] init];
        [installation install];
        [installation sendAllReports];
    });
    return YES;
}
#pragma GCC diagnostic pop

- (void)crash {
    int* p = 0;
    *p = 0;
}

- (void)reportUserException:(NSString *)name
                     reason:(NSString *)reason
                   language:(NSString *)language
                 lineOfCode:(NSString *)lineOfCode
                 stackTrace:(NSArray *)stackTrace
              logAllThreads:(BOOL)logAllThreads
           terminateProgram:(BOOL)terminateProgram {
    if (nil == installation) {
        [VicrabLog logWithMessage:@"VicrabCrash has not been initialized, call startCrashHandlerWithError" andLevel:kVicrabLogLevelError];
        return;
    }
    [VicrabCrash.sharedInstance reportUserException:name
                                         reason:reason
                                       language:language
                                     lineOfCode:lineOfCode
                                     stackTrace:stackTrace
                                  logAllThreads:logAllThreads
                               terminateProgram:terminateProgram];
    [installation sendAllReports];
}

- (void)snapshotStacktrace:(void (^)(void))snapshotCompleted {
    if (nil == installation) {
        [VicrabLog logWithMessage:@"VicrabCrash has not been initialized, call startCrashHandlerWithError" andLevel:kVicrabLogLevelError];
        return;
    }
    [VicrabCrash.sharedInstance reportUserException:@"VICRAB_SNAPSHOT"
                                         reason:@"VICRAB_SNAPSHOT"
                                       language:@""
                                     lineOfCode:@""
                                     stackTrace:[[NSArray alloc] init]
                                  logAllThreads:NO
                               terminateProgram:NO];
    [installation sendAllReportsWithCompletion:^(NSArray *filteredReports, BOOL completed, NSError *error) {
        snapshotCompleted();
    }];
}

@end

NS_ASSUME_NONNULL_END
