//
//  VicrabCrashMonitor.c
//
//  Created by Karl Stenerud on 2012-02-12.
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


#include "VicrabCrashMonitor.h"
#include "VicrabCrashMonitorContext.h"
#include "VicrabCrashMonitorType.h"

#include "VicrabCrashMonitor_Deadlock.h"
#include "VicrabCrashMonitor_MachException.h"
#include "VicrabCrashMonitor_CPPException.h"
#include "VicrabCrashMonitor_NSException.h"
#include "VicrabCrashMonitor_Signal.h"
#include "VicrabCrashMonitor_System.h"
#include "VicrabCrashMonitor_User.h"
#include "VicrabCrashMonitor_AppState.h"
#include "VicrabCrashMonitor_Zombie.h"
#include "VicrabCrashDebug.h"
#include "VicrabCrashThread.h"
#include "VicrabCrashSystemCapabilities.h"

#include <memory.h>

//#define VicrabCrashLogger_LocalLevel TRACE
#include "VicrabCrashLogger.h"


// ============================================================================
#pragma mark - Globals -
// ============================================================================

typedef struct
{
    VicrabCrashMonitorType monitorType;
    VicrabCrashMonitorAPI* (*getAPI)(void);
} Monitor;

static Monitor g_monitors[] =
{
#if VicrabCrashCRASH_HAS_MACH
    {
        .monitorType = VicrabCrashMonitorTypeMachException,
        .getAPI = vicrabcrashcm_machexception_getAPI,
    },
#endif
#if VicrabCrashCRASH_HAS_SIGNAL
    {
        .monitorType = VicrabCrashMonitorTypeSignal,
        .getAPI = vicrabcrashcm_signal_getAPI,
    },
#endif
#if VicrabCrashCRASH_HAS_OBJC
    {
        .monitorType = VicrabCrashMonitorTypeNSException,
        .getAPI = vicrabcrashcm_nsexception_getAPI,
    },
    {
        .monitorType = VicrabCrashMonitorTypeMainThreadDeadlock,
        .getAPI = vicrabcrashcm_deadlock_getAPI,
    },
    {
        .monitorType = VicrabCrashMonitorTypeZombie,
        .getAPI = vicrabcrashcm_zombie_getAPI,
    },
#endif
    {
        .monitorType = VicrabCrashMonitorTypeCPPException,
        .getAPI = vicrabcrashcm_cppexception_getAPI,
    },
    {
        .monitorType = VicrabCrashMonitorTypeUserReported,
        .getAPI = vicrabcrashcm_user_getAPI,
    },
    {
        .monitorType = VicrabCrashMonitorTypeSystem,
        .getAPI = vicrabcrashcm_system_getAPI,
    },
    {
        .monitorType = VicrabCrashMonitorTypeApplicationState,
        .getAPI = vicrabcrashcm_appstate_getAPI,
    },
};
static int g_monitorsCount = sizeof(g_monitors) / sizeof(*g_monitors);

static VicrabCrashMonitorType g_activeMonitors = VicrabCrashMonitorTypeNone;

static bool g_handlingFatalException = false;
static bool g_crashedDuringExceptionHandling = false;
static bool g_requiresAsyncSafety = false;

static void (*g_onExceptionEvent)(struct VicrabCrash_MonitorContext* monitorContext);

// ============================================================================
#pragma mark - API -
// ============================================================================

static inline VicrabCrashMonitorAPI* getAPI(Monitor* monitor)
{
    if(monitor != NULL && monitor->getAPI != NULL)
    {
        return monitor->getAPI();
    }
    return NULL;
}

static inline void setMonitorEnabled(Monitor* monitor, bool isEnabled)
{
    VicrabCrashMonitorAPI* api = getAPI(monitor);
    if(api != NULL && api->setEnabled != NULL)
    {
        api->setEnabled(isEnabled);
    }
}

static inline bool isMonitorEnabled(Monitor* monitor)
{
    VicrabCrashMonitorAPI* api = getAPI(monitor);
    if(api != NULL && api->isEnabled != NULL)
    {
        return api->isEnabled();
    }
    return false;
}

static inline void addContextualInfoToEvent(Monitor* monitor, struct VicrabCrash_MonitorContext* eventContext)
{
    VicrabCrashMonitorAPI* api = getAPI(monitor);
    if(api != NULL && api->addContextualInfoToEvent != NULL)
    {
        api->addContextualInfoToEvent(eventContext);
    }
}

void vicrabcrashcm_setEventCallback(void (*onEvent)(struct VicrabCrash_MonitorContext* monitorContext))
{
    g_onExceptionEvent = onEvent;
}

void vicrabcrashcm_setActiveMonitors(VicrabCrashMonitorType monitorTypes)
{
    if(vicrabcrashdebug_isBeingTraced() && (monitorTypes & VicrabCrashMonitorTypeDebuggerUnsafe))
    {
        static bool hasWarned = false;
        if(!hasWarned)
        {
            hasWarned = true;
            VicrabCrashLOGBASIC_WARN("    ************************ Crash Handler Notice ************************");
            VicrabCrashLOGBASIC_WARN("    *     App is running in a debugger. Masking out unsafe monitors.     *");
            VicrabCrashLOGBASIC_WARN("    * This means that most crashes WILL NOT BE RECORDED while debugging! *");
            VicrabCrashLOGBASIC_WARN("    **********************************************************************");
        }
        monitorTypes &= VicrabCrashMonitorTypeDebuggerSafe;
    }
    if(g_requiresAsyncSafety && (monitorTypes & VicrabCrashMonitorTypeAsyncUnsafe))
    {
        VicrabCrashLOG_DEBUG("Async-safe environment detected. Masking out unsafe monitors.");
        monitorTypes &= VicrabCrashMonitorTypeAsyncSafe;
    }

    VicrabCrashLOG_DEBUG("Changing active monitors from 0x%x tp 0x%x.", g_activeMonitors, monitorTypes);

    VicrabCrashMonitorType activeMonitors = VicrabCrashMonitorTypeNone;
    for(int i = 0; i < g_monitorsCount; i++)
    {
        Monitor* monitor = &g_monitors[i];
        bool isEnabled = monitor->monitorType & monitorTypes;
        setMonitorEnabled(monitor, isEnabled);
        if(isMonitorEnabled(monitor))
        {
            activeMonitors |= monitor->monitorType;
        }
        else
        {
            activeMonitors &= ~monitor->monitorType;
        }
    }

    VicrabCrashLOG_DEBUG("Active monitors are now 0x%x.", activeMonitors);
    g_activeMonitors = activeMonitors;
}

VicrabCrashMonitorType vicrabcrashcm_getActiveMonitors()
{
    return g_activeMonitors;
}


// ============================================================================
#pragma mark - Private API -
// ============================================================================

bool vicrabcrashcm_notifyFatalExceptionCaptured(bool isAsyncSafeEnvironment)
{
    g_requiresAsyncSafety |= isAsyncSafeEnvironment; // Don't let it be unset.
    if(g_handlingFatalException)
    {
        g_crashedDuringExceptionHandling = true;
    }
    g_handlingFatalException = true;
    if(g_crashedDuringExceptionHandling)
    {
        VicrabCrashLOG_INFO("Detected crash in the crash reporter. Uninstalling VicrabCrash.");
        vicrabcrashcm_setActiveMonitors(VicrabCrashMonitorTypeNone);
    }
    return g_crashedDuringExceptionHandling;
}

void vicrabcrashcm_handleException(struct VicrabCrash_MonitorContext* context)
{
    context->requiresAsyncSafety = g_requiresAsyncSafety;
    if(g_crashedDuringExceptionHandling)
    {
        context->crashedDuringCrashHandling = true;
    }
    for(int i = 0; i < g_monitorsCount; i++)
    {
        Monitor* monitor = &g_monitors[i];
        if(isMonitorEnabled(monitor))
        {
            addContextualInfoToEvent(monitor, context);
        }
    }

    g_onExceptionEvent(context);

    if (context->currentSnapshotUserReported) {
        g_handlingFatalException = false;
    } else {
        if(g_handlingFatalException && !g_crashedDuringExceptionHandling) {
            VicrabCrashLOG_DEBUG("Exception is fatal. Restoring original handlers.");
            vicrabcrashcm_setActiveMonitors(VicrabCrashMonitorTypeNone);
        }
    }
}
