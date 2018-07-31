//
//  VicrabCrashC.c
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


#include "VicrabCrashC.h"

#include "VicrabCrashCachedData.h"
#include "VicrabCrashReport.h"
#include "VicrabCrashReportFixer.h"
#include "VicrabCrashReportStore.h"
#include "VicrabCrashMonitor_Deadlock.h"
#include "VicrabCrashMonitor_User.h"
#include "VicrabCrashFileUtils.h"
#include "VicrabCrashObjC.h"
#include "VicrabCrashString.h"
#include "VicrabCrashMonitor_System.h"
#include "VicrabCrashMonitor_Zombie.h"
#include "VicrabCrashMonitor_AppState.h"
#include "VicrabCrashMonitorContext.h"
#include "VicrabCrashSystemCapabilities.h"

//#define VicrabCrashLogger_LocalLevel TRACE
#include "VicrabCrashLogger.h"

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** True if VicrabCrash has been installed. */
static volatile bool g_installed = 0;

static bool g_shouldAddConsoleLogToReport = false;
static bool g_shouldPrintPreviousLog = false;
static char g_consoleLogPath[VicrabCrashFU_MAX_PATH_LENGTH];
static VicrabCrashMonitorType g_monitoring = VicrabCrashMonitorTypeProductionSafeMinimal;
static char g_lastCrashReportFilePath[VicrabCrashFU_MAX_PATH_LENGTH];


// ============================================================================
#pragma mark - Utility -
// ============================================================================

static void printPreviousLog(const char* filePath)
{
    char* data;
    int length;
    if(vicrabcrashfu_readEntireFile(filePath, &data, &length, 0))
    {
        printf("\nvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv Previous Log vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n\n");
        printf("%s\n", data);
        printf("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n\n");
        fflush(stdout);
    }
}


// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

/** Called when a crash occurs.
 *
 * This function gets passed as a callback to a crash handler.
 */
static void onCrash(struct VicrabCrash_MonitorContext* monitorContext)
{
    if (monitorContext->currentSnapshotUserReported == false) {
        VicrabCrashLOG_DEBUG("Updating application state to note crash.");
        vicrabcrashstate_notifyAppCrash();
    }
    monitorContext->consoleLogPath = g_shouldAddConsoleLogToReport ? g_consoleLogPath : NULL;

    if(monitorContext->crashedDuringCrashHandling)
    {
        vicrabcrashreport_writeRecrashReport(monitorContext, g_lastCrashReportFilePath);
    }
    else
    {
        char crashReportFilePath[VicrabCrashFU_MAX_PATH_LENGTH];
        vicrabcrashcrs_getNextCrashReportPath(crashReportFilePath);
        strncpy(g_lastCrashReportFilePath, crashReportFilePath, sizeof(g_lastCrashReportFilePath));
        vicrabcrashreport_writeStandardReport(monitorContext, crashReportFilePath);
    }
}


// ============================================================================
#pragma mark - API -
// ============================================================================

VicrabCrashMonitorType vicrabcrash_install(const char* appName, const char* const installPath)
{
    VicrabCrashLOG_DEBUG("Installing crash reporter.");

    if(g_installed)
    {
        VicrabCrashLOG_DEBUG("Crash reporter already installed.");
        return g_monitoring;
    }
    g_installed = 1;

    char path[VicrabCrashFU_MAX_PATH_LENGTH];
    snprintf(path, sizeof(path), "%s/Reports", installPath);
    vicrabcrashfu_makePath(path);
    vicrabcrashcrs_initialize(appName, path);

    snprintf(path, sizeof(path), "%s/Data", installPath);
    vicrabcrashfu_makePath(path);
    snprintf(path, sizeof(path), "%s/Data/CrashState.json", installPath);
    vicrabcrashstate_initialize(path);

    snprintf(g_consoleLogPath, sizeof(g_consoleLogPath), "%s/Data/ConsoleLog.txt", installPath);
    if(g_shouldPrintPreviousLog)
    {
        printPreviousLog(g_consoleLogPath);
    }
    vicrabcrashlog_setLogFilename(g_consoleLogPath, true);

    vicrabcrashccd_init(60);

    vicrabcrashcm_setEventCallback(onCrash);
    VicrabCrashMonitorType monitors = vicrabcrash_setMonitoring(g_monitoring);

    VicrabCrashLOG_DEBUG("Installation complete.");
    return monitors;
}

VicrabCrashMonitorType vicrabcrash_setMonitoring(VicrabCrashMonitorType monitors)
{
    g_monitoring = monitors;

    if(g_installed)
    {
        vicrabcrashcm_setActiveMonitors(monitors);
        return vicrabcrashcm_getActiveMonitors();
    }
    // Return what we will be monitoring in future.
    return g_monitoring;
}

void vicrabcrash_setUserInfoJSON(const char* const userInfoJSON)
{
    vicrabcrashreport_setUserInfoJSON(userInfoJSON);
}

void vicrabcrash_setDeadlockWatchdogInterval(double deadlockWatchdogInterval)
{
#if VicrabCrashCRASH_HAS_OBJC
    vicrabcrashcm_setDeadlockHandlerWatchdogInterval(deadlockWatchdogInterval);
#endif
}

void vicrabcrash_setIntrospectMemory(bool introspectMemory)
{
    vicrabcrashreport_setIntrospectMemory(introspectMemory);
}

void vicrabcrash_setDoNotIntrospectClasses(const char** doNotIntrospectClasses, int length)
{
    vicrabcrashreport_setDoNotIntrospectClasses(doNotIntrospectClasses, length);
}

void vicrabcrash_setCrashNotifyCallback(const VicrabCrashReportWriteCallback onCrashNotify)
{
    vicrabcrashreport_setUserSectionWriteCallback(onCrashNotify);
}

void vicrabcrash_setAddConsoleLogToReport(bool shouldAddConsoleLogToReport)
{
    g_shouldAddConsoleLogToReport = shouldAddConsoleLogToReport;
}

void vicrabcrash_setPrintPreviousLog(bool shouldPrintPreviousLog)
{
    g_shouldPrintPreviousLog = shouldPrintPreviousLog;
}

void vicrabcrash_setMaxReportCount(int maxReportCount)
{
    vicrabcrashcrs_setMaxReportCount(maxReportCount);
}

void vicrabcrash_reportUserException(const char* name,
                                 const char* reason,
                                 const char* language,
                                 const char* lineOfCode,
                                 const char* stackTrace,
                                 bool logAllThreads,
                                 bool terminateProgram)
{
    vicrabcrashcm_reportUserException(name,
                             reason,
                             language,
                             lineOfCode,
                             stackTrace,
                             logAllThreads,
                             terminateProgram);
    if(g_shouldAddConsoleLogToReport)
    {
        vicrabcrashlog_clearLogFile();
    }
}

void vicrabcrash_notifyAppActive(bool isActive)
{
    vicrabcrashstate_notifyAppActive(isActive);
}

void vicrabcrash_notifyAppInForeground(bool isInForeground)
{
    vicrabcrashstate_notifyAppInForeground(isInForeground);
}

void vicrabcrash_notifyAppTerminate(void)
{
    vicrabcrashstate_notifyAppTerminate();
}

void vicrabcrash_notifyAppCrash(void)
{
    vicrabcrashstate_notifyAppCrash();
}

int vicrabcrash_getReportCount()
{
    return vicrabcrashcrs_getReportCount();
}

int vicrabcrash_getReportIDs(int64_t* reportIDs, int count)
{
    return vicrabcrashcrs_getReportIDs(reportIDs, count);
}

char* vicrabcrash_readReport(int64_t reportID)
{
    if(reportID <= 0)
    {
        VicrabCrashLOG_ERROR("Report ID was %" PRIx64, reportID);
        return NULL;
    }

    char* rawReport = vicrabcrashcrs_readReport(reportID);
    if(rawReport == NULL)
    {
        VicrabCrashLOG_ERROR("Failed to load report ID %" PRIx64, reportID);
        return NULL;
    }

    char* fixedReport = vicrabcrashcrf_fixupCrashReport(rawReport);
    if(fixedReport == NULL)
    {
        VicrabCrashLOG_ERROR("Failed to fixup report ID %" PRIx64, reportID);
    }

    free(rawReport);
    return fixedReport;
}

int64_t vicrabcrash_addUserReport(const char* report, int reportLength)
{
    return vicrabcrashcrs_addUserReport(report, reportLength);
}

void vicrabcrash_deleteAllReports()
{
    vicrabcrashcrs_deleteAllReports();
}

void vicrabcrash_deleteReportWithID(int64_t reportID)
{
    vicrabcrashcrs_deleteReportWithID(reportID);
}
