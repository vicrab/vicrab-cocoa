//
//  VicrabCrashMonitor_Deadlock.m
//
//  Created by Karl Stenerud on 2012-12-09.
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

#import "VicrabCrashMonitor_Deadlock.h"
#import "VicrabCrashMonitorContext.h"
#import "VicrabCrashID.h"
#import "VicrabCrashThread.h"
#import "VicrabCrashStackCursor_MachineContext.h"
#import <Foundation/Foundation.h>

//#define VicrabCrashLogger_LocalLevel TRACE
#import "VicrabCrashLogger.h"


#define kIdleInterval 5.0f


@class VicrabCrashDeadlockMonitor;

// ============================================================================
#pragma mark - Globals -
// ============================================================================

static volatile bool g_isEnabled = false;

static VicrabCrash_MonitorContext g_monitorContext;

/** Thread which monitors other threads. */
static VicrabCrashDeadlockMonitor* g_monitor;

static VicrabCrashThread g_mainQueueThread;

/** Interval between watchdog pulses. */
static NSTimeInterval g_watchdogInterval = 0;


// ============================================================================
#pragma mark - X -
// ============================================================================

@interface VicrabCrashDeadlockMonitor: NSObject

@property(nonatomic, readwrite, retain) NSThread* monitorThread;
@property(atomic, readwrite, assign) BOOL awaitingResponse;

@end

@implementation VicrabCrashDeadlockMonitor

@synthesize monitorThread = _monitorThread;
@synthesize awaitingResponse = _awaitingResponse;

- (id) init
{
    if((self = [super init]))
    {
        // target (self) is retained until selector (runMonitor) exits.
        self.monitorThread = [[NSThread alloc] initWithTarget:self selector:@selector(runMonitor) object:nil];
        self.monitorThread.name = @"VicrabCrash Deadlock Detection Thread";
        [self.monitorThread start];
    }
    return self;
}

- (void) cancel
{
    [self.monitorThread cancel];
}

- (void) watchdogPulse
{
    __block id blockSelf = self;
    self.awaitingResponse = YES;
    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       [blockSelf watchdogAnswer];
                   });
}

- (void) watchdogAnswer
{
    self.awaitingResponse = NO;
}

- (void) handleDeadlock
{
    vicrabcrashmc_suspendEnvironment();
    vicrabcrashcm_notifyFatalExceptionCaptured(false);

    VicrabCrashMC_NEW_CONTEXT(machineContext);
    vicrabcrashmc_getContextForThread(g_mainQueueThread, machineContext, false);
    VicrabCrashStackCursor stackCursor;
    vicrabcrashsc_initWithMachineContext(&stackCursor, 100, machineContext);
    char eventID[37];
    vicrabcrashid_generate(eventID);

    VicrabCrashLOG_DEBUG(@"Filling out context.");
    VicrabCrash_MonitorContext* crashContext = &g_monitorContext;
    memset(crashContext, 0, sizeof(*crashContext));
    crashContext->crashType = VicrabCrashMonitorTypeMainThreadDeadlock;
    crashContext->eventID = eventID;
    crashContext->registersAreValid = false;
    crashContext->offendingMachineContext = machineContext;
    crashContext->stackCursor = &stackCursor;

    vicrabcrashcm_handleException(crashContext);
    vicrabcrashmc_resumeEnvironment();

    VicrabCrashLOG_DEBUG(@"Calling abort()");
    abort();
}

- (void) runMonitor
{
    BOOL cancelled = NO;
    do
    {
        // Only do a watchdog check if the watchdog interval is > 0.
        // If the interval is <= 0, just idle until the user changes it.
        @autoreleasepool {
            NSTimeInterval sleepInterval = g_watchdogInterval;
            BOOL runWatchdogCheck = sleepInterval > 0;
            if(!runWatchdogCheck)
            {
                sleepInterval = kIdleInterval;
            }
            [NSThread sleepForTimeInterval:sleepInterval];
            cancelled = self.monitorThread.isCancelled;
            if(!cancelled && runWatchdogCheck)
            {
                if(self.awaitingResponse)
                {
                    [self handleDeadlock];
                }
                else
                {
                    [self watchdogPulse];
                }
            }
        }
    } while (!cancelled);
}

@end

// ============================================================================
#pragma mark - API -
// ============================================================================

static void initialize()
{
    static bool isInitialized = false;
    if(!isInitialized)
    {
        isInitialized = true;
        dispatch_async(dispatch_get_main_queue(), ^{g_mainQueueThread = vicrabcrashthread_self();});
    }
}

static void setEnabled(bool isEnabled)
{
    if(isEnabled != g_isEnabled)
    {
        g_isEnabled = isEnabled;
        if(isEnabled)
        {
            VicrabCrashLOG_DEBUG(@"Creating new deadlock monitor.");
            initialize();
            g_monitor = [[VicrabCrashDeadlockMonitor alloc] init];
        }
        else
        {
            VicrabCrashLOG_DEBUG(@"Stopping deadlock monitor.");
            [g_monitor cancel];
            g_monitor = nil;
        }
    }
}

static bool isEnabled()
{
    return g_isEnabled;
}

VicrabCrashMonitorAPI* vicrabcrashcm_deadlock_getAPI()
{
    static VicrabCrashMonitorAPI api =
    {
        .setEnabled = setEnabled,
        .isEnabled = isEnabled
    };
    return &api;
}

void vicrabcrashcm_setDeadlockHandlerWatchdogInterval(double value)
{
    g_watchdogInterval = value;
}
