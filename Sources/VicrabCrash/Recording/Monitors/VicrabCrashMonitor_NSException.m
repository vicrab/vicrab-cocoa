//
//  VicrabCrashMonitor_NSException.m
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
#import "VicrabCrashMonitor_NSException.h"
#import "VicrabCrashStackCursor_Backtrace.h"
#include "VicrabCrashMonitorContext.h"
#include "VicrabCrashID.h"
#include "VicrabCrashThread.h"
#import <Foundation/Foundation.h>

//#define VicrabCrashLogger_LocalLevel TRACE
#import "VicrabCrashLogger.h"


// ============================================================================
#pragma mark - Globals -
// ============================================================================

static volatile bool g_isEnabled = 0;

static VicrabCrash_MonitorContext g_monitorContext;

/** The exception handler that was in place before we installed ours. */
static NSUncaughtExceptionHandler* g_previousUncaughtExceptionHandler;


// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

/** Our custom excepetion handler.
 * Fetch the stack trace from the exception and write a report.
 *
 * @param exception The exception that was raised.
 */

static void handleException(NSException* exception, BOOL currentSnapshotUserReported) {
    VicrabCrashLOG_DEBUG(@"Trapped exception %@", exception);
    if(g_isEnabled)
    {
        vicrabcrashmc_suspendEnvironment();
        vicrabcrashcm_notifyFatalExceptionCaptured(false);

        VicrabCrashLOG_DEBUG(@"Filling out context.");
        NSArray* addresses = [exception callStackReturnAddresses];
        NSUInteger numFrames = addresses.count;
        uintptr_t* callstack = malloc(numFrames * sizeof(*callstack));
        for(NSUInteger i = 0; i < numFrames; i++)
        {
            callstack[i] = (uintptr_t)[addresses[i] unsignedLongLongValue];
        }

        char eventID[37];
        vicrabcrashid_generate(eventID);
        VicrabCrashMC_NEW_CONTEXT(machineContext);
        vicrabcrashmc_getContextForThread(vicrabcrashthread_self(), machineContext, true);
        VicrabCrashStackCursor cursor;
        vicrabcrashsc_initWithBacktrace(&cursor, callstack, (int)numFrames, 0);

        VicrabCrash_MonitorContext* crashContext = &g_monitorContext;
        memset(crashContext, 0, sizeof(*crashContext));
        crashContext->crashType = VicrabCrashMonitorTypeNSException;
        crashContext->eventID = eventID;
        crashContext->offendingMachineContext = machineContext;
        crashContext->registersAreValid = false;
        crashContext->NSException.name = [[exception name] UTF8String];
        crashContext->NSException.userInfo = [[NSString stringWithFormat:@"%@", exception.userInfo] UTF8String];
        crashContext->exceptionName = crashContext->NSException.name;
        crashContext->crashReason = [[exception reason] UTF8String];
        crashContext->stackCursor = &cursor;
        crashContext->currentSnapshotUserReported = currentSnapshotUserReported;

        VicrabCrashLOG_DEBUG(@"Calling main crash handler.");
        vicrabcrashcm_handleException(crashContext);

        free(callstack);
        if (currentSnapshotUserReported) {
            vicrabcrashmc_resumeEnvironment();
        }
        if (g_previousUncaughtExceptionHandler != NULL)
        {
            VicrabCrashLOG_DEBUG(@"Calling original exception handler.");
            g_previousUncaughtExceptionHandler(exception);
        }
    }
}

static void handleCurrentSnapshotUserReportedException(NSException* exception) {
    handleException(exception, true);
}

static void handleUncaughtException(NSException* exception) {
    handleException(exception, false);
}

// ============================================================================
#pragma mark - API -
// ============================================================================

static void setEnabled(bool isEnabled)
{
    if(isEnabled != g_isEnabled)
    {
        g_isEnabled = isEnabled;
        if(isEnabled)
        {
            VicrabCrashLOG_DEBUG(@"Backing up original handler.");
            g_previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();

            VicrabCrashLOG_DEBUG(@"Setting new handler.");
            NSSetUncaughtExceptionHandler(&handleUncaughtException);
            VicrabCrash.sharedInstance.uncaughtExceptionHandler = &handleUncaughtException;
            VicrabCrash.sharedInstance.currentSnapshotUserReportedExceptionHandler = &handleCurrentSnapshotUserReportedException;
        }
        else
        {
            VicrabCrashLOG_DEBUG(@"Restoring original handler.");
            NSSetUncaughtExceptionHandler(g_previousUncaughtExceptionHandler);
        }
    }
}

static bool isEnabled()
{
    return g_isEnabled;
}

VicrabCrashMonitorAPI* vicrabcrashcm_nsexception_getAPI()
{
    static VicrabCrashMonitorAPI api =
    {
        .setEnabled = setEnabled,
        .isEnabled = isEnabled
    };
    return &api;
}
