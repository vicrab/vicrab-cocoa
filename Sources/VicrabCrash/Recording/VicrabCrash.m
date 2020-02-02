//
//  VicrabCrash.m
//
//  Created by Karl Stenerud on 2012-01-28.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//


#import "VicrabCrash.h"

#import "VicrabCrashC.h"
#import "VicrabCrashDoctor.h"
#import "VicrabCrashReportFields.h"
#import "VicrabCrashMonitor_AppState.h"
#import "VicrabCrashJSONCodecObjC.h"
#import "NSError+VicrabSimpleConstructor.h"
#import "VicrabCrashMonitorContext.h"
#import "VicrabCrashMonitor_System.h"
#import "VicrabCrashSystemCapabilities.h"

//#define VicrabCrashLogger_LocalLevel TRACE
#import "VicrabCrashLogger.h"

#include <inttypes.h>
#if VicrabCrashCRASH_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif


// ============================================================================
#pragma mark - Globals -
// ============================================================================

@interface VicrabCrash ()

@property(nonatomic,readwrite,retain) NSString* bundleName;
@property(nonatomic,readwrite,retain) NSString* basePath;

@end


static NSString* getBundleName()
{
    NSString* bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
    if(bundleName == nil)
    {
        bundleName = @"Unknown";
    }
    return bundleName;
}

static NSString* getBasePath()
{
    NSArray* directories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                               NSUserDomainMask,
                                                               YES);
    if([directories count] == 0)
    {
        VicrabCrashLOG_ERROR(@"Could not locate cache directory path.");
        return nil;
    }
    NSString* cachePath = [directories objectAtIndex:0];
    if([cachePath length] == 0)
    {
        VicrabCrashLOG_ERROR(@"Could not locate cache directory path.");
        return nil;
    }
    NSString* pathEnd = [@"VicrabCrash" stringByAppendingPathComponent:getBundleName()];
    return [cachePath stringByAppendingPathComponent:pathEnd];
}


@implementation VicrabCrash

// ============================================================================
#pragma mark - Properties -
// ============================================================================

@synthesize sink = _sink;
@synthesize userInfo = _userInfo;
@synthesize deleteBehaviorAfterSendAll = _deleteBehaviorAfterSendAll;
@synthesize monitoring = _monitoring;
@synthesize deadlockWatchdogInterval = _deadlockWatchdogInterval;
@synthesize onCrash = _onCrash;
@synthesize bundleName = _bundleName;
@synthesize basePath = _basePath;
@synthesize introspectMemory = _introspectMemory;
@synthesize catchZombies = _catchZombies;
@synthesize doNotIntrospectClasses = _doNotIntrospectClasses;
@synthesize demangleLanguages = _demangleLanguages;
@synthesize addConsoleLogToReport = _addConsoleLogToReport;
@synthesize printPreviousLog = _printPreviousLog;
@synthesize maxReportCount = _maxReportCount;
@synthesize uncaughtExceptionHandler = _uncaughtExceptionHandler;
@synthesize currentSnapshotUserReportedExceptionHandler = _currentSnapshotUserReportedExceptionHandler;

// ============================================================================
#pragma mark - Lifecycle -
// ============================================================================

+ (instancetype) sharedInstance
{
    static VicrabCrash *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[VicrabCrash alloc] init];
    });
    return sharedInstance;
}

- (id) init
{
    return [self initWithBasePath:getBasePath()];
}

- (id) initWithBasePath:(NSString *)basePath
{
    if((self = [super init]))
    {
        self.bundleName = getBundleName();
        self.basePath = basePath;
        if(self.basePath == nil)
        {
            VicrabCrashLOG_ERROR(@"Failed to initialize crash handler. Crash reporting disabled.");
            return nil;
        }
        self.deleteBehaviorAfterSendAll = VicrabCrashCDeleteAlways;
        self.introspectMemory = YES;
        self.catchZombies = NO;
        self.maxReportCount = 5;
        self.monitoring = VicrabCrashMonitorTypeProductionSafeMinimal;
    }
    return self;
}


// ============================================================================
#pragma mark - API -
// ============================================================================

- (NSDictionary*) userInfo
{
   return _userInfo;
}

- (void) setUserInfo:(NSDictionary*) userInfo
{
    @synchronized (self)
    {
        NSError* error = nil;
        NSData* userInfoJSON = nil;
        if(userInfo != nil)
        {
            userInfoJSON = [self nullTerminated:[VicrabCrashJSONCodec encode:userInfo
                                                            options:VicrabCrashJSONEncodeOptionSorted
                                                              error:&error]];
            if(error != NULL)
            {
                VicrabCrashLOG_ERROR(@"Could not serialize user info: %@", error);
                return;
            }
        }

        _userInfo = userInfo;
        vicrabcrash_setUserInfoJSON([userInfoJSON bytes]);
    }
}

- (void) setMonitoring:(VicrabCrashMonitorType)monitoring
{
    _monitoring = vicrabcrash_setMonitoring(monitoring);
}

- (void) setDeadlockWatchdogInterval:(double) deadlockWatchdogInterval
{
    _deadlockWatchdogInterval = deadlockWatchdogInterval;
    vicrabcrash_setDeadlockWatchdogInterval(deadlockWatchdogInterval);
}

- (void) setOnCrash:(VicrabCrashReportWriteCallback) onCrash
{
    _onCrash = onCrash;
    vicrabcrash_setCrashNotifyCallback(onCrash);
}

- (void) setIntrospectMemory:(BOOL) introspectMemory
{
    _introspectMemory = introspectMemory;
    vicrabcrash_setIntrospectMemory(introspectMemory);
}

- (void) setCatchZombies:(BOOL)catchZombies
{
    _catchZombies = catchZombies;
    self.monitoring |= VicrabCrashMonitorTypeZombie;
}

- (void) setDoNotIntrospectClasses:(NSArray *)doNotIntrospectClasses
{
    _doNotIntrospectClasses = doNotIntrospectClasses;
    NSUInteger count = [doNotIntrospectClasses count];
    if(count == 0)
    {
        vicrabcrash_setDoNotIntrospectClasses(nil, 0);
    }
    else
    {
        NSMutableData* data = [NSMutableData dataWithLength:count * sizeof(const char*)];
        const char** classes = data.mutableBytes;
        for(unsigned i = 0; i < count; i++)
        {
            classes[i] = [[doNotIntrospectClasses objectAtIndex:i] cStringUsingEncoding:NSUTF8StringEncoding];
        }
        vicrabcrash_setDoNotIntrospectClasses(classes, (int)count);
    }
}

- (void) setMaxReportCount:(int)maxReportCount
{
    _maxReportCount = maxReportCount;
    vicrabcrash_setMaxReportCount(maxReportCount);
}

- (NSDictionary*) systemInfo
{
    VicrabCrash_MonitorContext fakeEvent = {0};
    vicrabcrashcm_system_getAPI()->addContextualInfoToEvent(&fakeEvent);
    NSMutableDictionary* dict = [NSMutableDictionary new];

#define COPY_STRING(A) if (fakeEvent.System.A) dict[@#A] = [NSString stringWithUTF8String:fakeEvent.System.A]
#define COPY_PRIMITIVE(A) dict[@#A] = @(fakeEvent.System.A)
    COPY_STRING(systemName);
    COPY_STRING(systemVersion);
    COPY_STRING(machine);
    COPY_STRING(model);
    COPY_STRING(kernelVersion);
    COPY_STRING(osVersion);
    COPY_PRIMITIVE(isJailbroken);
    COPY_STRING(bootTime);
    COPY_STRING(appStartTime);
    COPY_STRING(executablePath);
    COPY_STRING(executableName);
    COPY_STRING(bundleID);
    COPY_STRING(bundleName);
    COPY_STRING(bundleVersion);
    COPY_STRING(bundleShortVersion);
    COPY_STRING(appID);
    COPY_STRING(cpuArchitecture);
    COPY_PRIMITIVE(cpuType);
    COPY_PRIMITIVE(cpuSubType);
    COPY_PRIMITIVE(binaryCPUType);
    COPY_PRIMITIVE(binaryCPUSubType);
    COPY_STRING(timezone);
    COPY_STRING(processName);
    COPY_PRIMITIVE(processID);
    COPY_PRIMITIVE(parentProcessID);
    COPY_STRING(deviceAppHash);
    COPY_STRING(buildType);
    COPY_PRIMITIVE(storageSize);
    COPY_PRIMITIVE(memorySize);
    COPY_PRIMITIVE(freeMemory);
    COPY_PRIMITIVE(usableMemory);

    return dict;
}

- (BOOL) install
{
    _monitoring = vicrabcrash_install(self.bundleName.UTF8String,
                                          self.basePath.UTF8String);
    if(self.monitoring == 0)
    {
        return false;
    }

#if VicrabCrashCRASH_HAS_UIAPPLICATION
    NSNotificationCenter* nCenter = [NSNotificationCenter defaultCenter];
    [nCenter addObserver:self
                selector:@selector(applicationDidBecomeActive)
                    name:UIApplicationDidBecomeActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillResignActive)
                    name:UIApplicationWillResignActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationDidEnterBackground)
                    name:UIApplicationDidEnterBackgroundNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillEnterForeground)
                    name:UIApplicationWillEnterForegroundNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillTerminate)
                    name:UIApplicationWillTerminateNotification
                  object:nil];
#endif
#if VicrabCrashCRASH_HAS_NSEXTENSION
    NSNotificationCenter* nCenter = [NSNotificationCenter defaultCenter];
    [nCenter addObserver:self
                selector:@selector(applicationDidBecomeActive)
                    name:NSExtensionHostDidBecomeActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillResignActive)
                    name:NSExtensionHostWillResignActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationDidEnterBackground)
                    name:NSExtensionHostDidEnterBackgroundNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillEnterForeground)
                    name:NSExtensionHostWillEnterForegroundNotification
                  object:nil];
#endif

    return true;
}

- (void) sendAllReportsWithCompletion:(VicrabCrashReportFilterCompletion) onCompletion
{
    NSArray* reports = [self allReports];

    VicrabCrashLOG_INFO(@"Sending %d crash reports", [reports count]);

    [self sendReports:reports
         onCompletion:^(NSArray* filteredReports, BOOL completed, NSError* error)
     {
         VicrabCrashLOG_DEBUG(@"Process finished with completion: %d", completed);
         if(error != nil)
         {
             VicrabCrashLOG_ERROR(@"Failed to send reports: %@", error);
         }
         if((self.deleteBehaviorAfterSendAll == VicrabCrashCDeleteOnSucess && completed) ||
            self.deleteBehaviorAfterSendAll == VicrabCrashCDeleteAlways)
         {
             vicrabcrash_deleteAllReports();
         }
         vicrabcrash_callCompletion(onCompletion, filteredReports, completed, error);
     }];
}

- (void) deleteAllReports
{
    vicrabcrash_deleteAllReports();
}

- (void) deleteReportWithID:(NSNumber*) reportID
{
    vicrabcrash_deleteReportWithID([reportID longValue]);
}

- (void) reportUserException:(NSString*) name
                      reason:(NSString*) reason
                    language:(NSString*) language
                  lineOfCode:(NSString*) lineOfCode
                  stackTrace:(NSArray*) stackTrace
               logAllThreads:(BOOL) logAllThreads
            terminateProgram:(BOOL) terminateProgram
{
    const char* cName = [name cStringUsingEncoding:NSUTF8StringEncoding];
    const char* cReason = [reason cStringUsingEncoding:NSUTF8StringEncoding];
    const char* cLanguage = [language cStringUsingEncoding:NSUTF8StringEncoding];
    const char* cLineOfCode = [lineOfCode cStringUsingEncoding:NSUTF8StringEncoding];
    NSError* error = nil;
    NSData* jsonData = [VicrabCrashJSONCodec encode:stackTrace options:0 error:&error];
    if(jsonData == nil || error != nil)
    {
        VicrabCrashLOG_ERROR(@"Error encoding stack trace to JSON: %@", error);
        // Don't return, since we can still record other useful information.
    }
    NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    const char* cStackTrace = [jsonString cStringUsingEncoding:NSUTF8StringEncoding];

    vicrabcrash_reportUserException(cName,
                                cReason,
                                cLanguage,
                                cLineOfCode,
                                cStackTrace,
                                logAllThreads,
                                terminateProgram);
}

// ============================================================================
#pragma mark - Advanced API -
// ============================================================================

#define SYNTHESIZE_CRASH_STATE_PROPERTY(TYPE, NAME) \
- (TYPE) NAME \
{ \
    return vicrabcrashstate_currentState()->NAME; \
}

SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval, activeDurationSinceLastCrash)
SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval, backgroundDurationSinceLastCrash)
SYNTHESIZE_CRASH_STATE_PROPERTY(int, launchesSinceLastCrash)
SYNTHESIZE_CRASH_STATE_PROPERTY(int, sessionsSinceLastCrash)
SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval, activeDurationSinceLaunch)
SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval, backgroundDurationSinceLaunch)
SYNTHESIZE_CRASH_STATE_PROPERTY(int, sessionsSinceLaunch)
SYNTHESIZE_CRASH_STATE_PROPERTY(BOOL, crashedLastLaunch)

- (int) reportCount
{
    return vicrabcrash_getReportCount();
}

- (void) sendReports:(NSArray*) reports onCompletion:(VicrabCrashReportFilterCompletion) onCompletion
{
    if([reports count] == 0)
    {
        vicrabcrash_callCompletion(onCompletion, reports, YES, nil);
        return;
    }

    if(self.sink == nil)
    {
        vicrabcrash_callCompletion(onCompletion, reports, NO,
                                 [NSError errorWithDomain:[[self class] description]
                                                     code:0
                                              description:@"No sink set. Crash reports not sent."]);
        return;
    }

    [self.sink filterReports:reports
                onCompletion:^(NSArray* filteredReports, BOOL completed, NSError* error)
     {
         vicrabcrash_callCompletion(onCompletion, filteredReports, completed, error);
     }];
}

- (NSData*) loadCrashReportJSONWithID:(int64_t) reportID
{
    char* report = vicrabcrash_readReport(reportID);
    if(report != NULL)
    {
        return [NSData dataWithBytesNoCopy:report length:strlen(report) freeWhenDone:YES];
    }
    return nil;
}

- (void) doctorReport:(NSMutableDictionary*) report
{
    NSMutableDictionary* crashReport = report[@VicrabCrashField_Crash];
    if(crashReport != nil)
    {
        crashReport[@VicrabCrashField_Diagnosis] = [[VicrabCrashDoctor doctor] diagnoseCrash:report];
    }
    crashReport = report[@VicrabCrashField_RecrashReport][@VicrabCrashField_Crash];
    if(crashReport != nil)
    {
        crashReport[@VicrabCrashField_Diagnosis] = [[VicrabCrashDoctor doctor] diagnoseCrash:report];
    }
}

- (NSArray*)reportIDs
{
    int reportCount = vicrabcrash_getReportCount();
    int64_t reportIDsC[reportCount];
    reportCount = vicrabcrash_getReportIDs(reportIDsC, reportCount);
    NSMutableArray* reportIDs = [NSMutableArray arrayWithCapacity:(NSUInteger)reportCount];
    for(int i = 0; i < reportCount; i++)
    {
        [reportIDs addObject:@(reportIDsC[i])];
    }
    return reportIDs;
}

- (NSDictionary*) reportWithID:(NSNumber*) reportID
{
    return [self reportWithIntID:[reportID longValue]];
}

- (NSDictionary*) reportWithIntID:(int64_t) reportID
{
    NSData* jsonData = [self loadCrashReportJSONWithID:reportID];
    if(jsonData == nil)
    {
        return nil;
    }

    NSError* error = nil;
    NSMutableDictionary* crashReport = [VicrabCrashJSONCodec decode:jsonData
                                                   options:VicrabCrashJSONDecodeOptionIgnoreNullInArray |
                                                           VicrabCrashJSONDecodeOptionIgnoreNullInObject |
                                                           VicrabCrashJSONDecodeOptionKeepPartialObject
                                                     error:&error];
    if(error != nil)
    {
        VicrabCrashLOG_ERROR(@"Encountered error loading crash report %" PRIx64 ": %@", reportID, error);
    }
    if(crashReport == nil)
    {
        VicrabCrashLOG_ERROR(@"Could not load crash report");
        return nil;
    }
    [self doctorReport:crashReport];

    return crashReport;
}

- (NSArray*) allReports
{
    NSMutableArray* reports = [NSMutableArray array];
    int reportCount = vicrabcrash_getReportCount();
    if (reportCount > 0) {
        int64_t reportIDs[reportCount];
        reportCount = vicrabcrash_getReportIDs(reportIDs, reportCount);
        for(int i = 0; i < reportCount; i++)
        {
            NSDictionary* report = [self reportWithIntID:reportIDs[i]];
            if(report != nil)
            {
                [reports addObject:report];
            }
        }
    }
    return reports;
}

- (void) setAddConsoleLogToReport:(BOOL) shouldAddConsoleLogToReport
{
    _addConsoleLogToReport = shouldAddConsoleLogToReport;
    vicrabcrash_setAddConsoleLogToReport(shouldAddConsoleLogToReport);
}

- (void) setPrintPreviousLog:(BOOL) shouldPrintPreviousLog
{
    _printPreviousLog = shouldPrintPreviousLog;
    vicrabcrash_setPrintPreviousLog(shouldPrintPreviousLog);
}


// ============================================================================
#pragma mark - Utility -
// ============================================================================

- (NSMutableData*) nullTerminated:(NSData*) data
{
    if(data == nil)
    {
        return NULL;
    }
    NSMutableData* mutable = [NSMutableData dataWithData:data];
    [mutable appendBytes:"\0" length:1];
    return mutable;
}


// ============================================================================
#pragma mark - Notifications -
// ============================================================================

- (void) applicationDidBecomeActive
{
    vicrabcrash_notifyAppActive(true);
}

- (void) applicationWillResignActive
{
    vicrabcrash_notifyAppActive(false);
}

- (void) applicationDidEnterBackground
{
    vicrabcrash_notifyAppInForeground(false);
}

- (void) applicationWillEnterForeground
{
    vicrabcrash_notifyAppInForeground(true);
}

- (void) applicationWillTerminate
{
    vicrabcrash_notifyAppTerminate();
}

@end


//! Project version number for VicrabCrashFramework.
const double VicrabCrashFrameworkVersionNumber = 1.1518;

//! Project version string for VicrabCrashFramework.
const unsigned char VicrabCrashFrameworkVersionString[] = "1.15.18";
