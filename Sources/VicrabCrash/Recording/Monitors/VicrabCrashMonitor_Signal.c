//
//  VicrabCrashMonitor_Signal.c
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

#include "VicrabCrashMonitor_Signal.h"
#include "VicrabCrashMonitorContext.h"
#include "VicrabCrashID.h"
#include "VicrabCrashSignalInfo.h"
#include "VicrabCrashMachineContext.h"
#include "VicrabCrashSystemCapabilities.h"
#include "VicrabCrashStackCursor_MachineContext.h"

//#define VicrabCrashLogger_LocalLevel TRACE
#include "VicrabCrashLogger.h"

#if VicrabCrashCRASH_HAS_SIGNAL

#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


// ============================================================================
#pragma mark - Globals -
// ============================================================================

static volatile bool g_isEnabled = false;

static VicrabCrash_MonitorContext g_monitorContext;
static VicrabCrashStackCursor g_stackCursor;

#if VicrabCrashCRASH_HAS_SIGNAL_STACK
/** Our custom signal stack. The signal handler will use this as its stack. */
static stack_t g_signalStack = {0};
#endif

/** Signal handlers that were installed before we installed ours. */
static struct sigaction* g_previousSignalHandlers = NULL;

static char g_eventID[37];

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

/** Our custom signal handler.
 * Restore the default signal handlers, record the signal information, and
 * write a crash report.
 * Once we're done, re-raise the signal and let the default handlers deal with
 * it.
 *
 * @param sigNum The signal that was raised.
 *
 * @param signalInfo Information about the signal.
 *
 * @param userContext Other contextual information.
 */
static void handleSignal(int sigNum, siginfo_t* signalInfo, void* userContext)
{
    VicrabCrashLOG_DEBUG("Trapped signal %d", sigNum);
    if(g_isEnabled)
    {
        vicrabcrashmc_suspendEnvironment();
        vicrabcrashcm_notifyFatalExceptionCaptured(false);

        VicrabCrashLOG_DEBUG("Filling out context.");
        VicrabCrashMC_NEW_CONTEXT(machineContext);
        vicrabcrashmc_getContextForSignal(userContext, machineContext);
        vicrabcrashsc_initWithMachineContext(&g_stackCursor, 100, machineContext);

        VicrabCrash_MonitorContext* crashContext = &g_monitorContext;
        memset(crashContext, 0, sizeof(*crashContext));
        crashContext->crashType = VicrabCrashMonitorTypeSignal;
        crashContext->eventID = g_eventID;
        crashContext->offendingMachineContext = machineContext;
        crashContext->registersAreValid = true;
        crashContext->faultAddress = (uintptr_t)signalInfo->si_addr;
        crashContext->signal.userContext = userContext;
        crashContext->signal.signum = signalInfo->si_signo;
        crashContext->signal.sigcode = signalInfo->si_code;
        crashContext->stackCursor = &g_stackCursor;

        vicrabcrashcm_handleException(crashContext);
        vicrabcrashmc_resumeEnvironment();
    }

    VicrabCrashLOG_DEBUG("Re-raising signal for regular handlers to catch.");
    // This is technically not allowed, but it works in OSX and iOS.
    raise(sigNum);
}


// ============================================================================
#pragma mark - API -
// ============================================================================

static bool installSignalHandler()
{
    VicrabCrashLOG_DEBUG("Installing signal handler.");

#if VicrabCrashCRASH_HAS_SIGNAL_STACK

    if(g_signalStack.ss_size == 0)
    {
        VicrabCrashLOG_DEBUG("Allocating signal stack area.");
        g_signalStack.ss_size = SIGSTKSZ;
        g_signalStack.ss_sp = malloc(g_signalStack.ss_size);

        if(g_signalStack.ss_sp == NULL)
        {
            VicrabCrashLOG_ERROR("Failed to allocate signal stack area of size %ul", g_signalStack.ss_size);
            goto failed;
        }
    }

    VicrabCrashLOG_DEBUG("Setting signal stack area.");
    if(sigaltstack(&g_signalStack, NULL) != 0)
    {
        VicrabCrashLOG_ERROR("signalstack: %s", strerror(errno));
        goto failed;
    }
#endif

    const int* fatalSignals = vicrabcrashsignal_fatalSignals();
    int fatalSignalsCount = vicrabcrashsignal_numFatalSignals();

    if(g_previousSignalHandlers == NULL)
    {
        VicrabCrashLOG_DEBUG("Allocating memory to store previous signal handlers.");
        g_previousSignalHandlers = malloc(sizeof(*g_previousSignalHandlers)
                                          * (unsigned)fatalSignalsCount);
    }

    struct sigaction action = {{0}};
    action.sa_flags = SA_SIGINFO | SA_ONSTACK;
#if VicrabCrashCRASH_HOST_APPLE && defined(__LP64__)
    action.sa_flags |= SA_64REGSET;
#endif
    sigemptyset(&action.sa_mask);
    action.sa_sigaction = &handleSignal;

    for(int i = 0; i < fatalSignalsCount; i++)
    {
        VicrabCrashLOG_DEBUG("Assigning handler for signal %d", fatalSignals[i]);
        if(sigaction(fatalSignals[i], &action, &g_previousSignalHandlers[i]) != 0)
        {
            char sigNameBuff[30];
            const char* sigName = vicrabcrashsignal_signalName(fatalSignals[i]);
            if(sigName == NULL)
            {
                snprintf(sigNameBuff, sizeof(sigNameBuff), "%d", fatalSignals[i]);
                sigName = sigNameBuff;
            }
            VicrabCrashLOG_ERROR("sigaction (%s): %s", sigName, strerror(errno));
            // Try to reverse the damage
            for(i--;i >= 0; i--)
            {
                sigaction(fatalSignals[i], &g_previousSignalHandlers[i], NULL);
            }
            goto failed;
        }
    }
    VicrabCrashLOG_DEBUG("Signal handlers installed.");
    return true;

failed:
    VicrabCrashLOG_DEBUG("Failed to install signal handlers.");
    return false;
}

static void uninstallSignalHandler(void)
{
    VicrabCrashLOG_DEBUG("Uninstalling signal handlers.");

    const int* fatalSignals = vicrabcrashsignal_fatalSignals();
    int fatalSignalsCount = vicrabcrashsignal_numFatalSignals();

    for(int i = 0; i < fatalSignalsCount; i++)
    {
        VicrabCrashLOG_DEBUG("Restoring original handler for signal %d", fatalSignals[i]);
        sigaction(fatalSignals[i], &g_previousSignalHandlers[i], NULL);
    }

#if VicrabCrashCRASH_HAS_SIGNAL_STACK
    g_signalStack = (stack_t){0};
#endif
    VicrabCrashLOG_DEBUG("Signal handlers uninstalled.");
}

static void setEnabled(bool isEnabled)
{
    if(isEnabled != g_isEnabled)
    {
        g_isEnabled = isEnabled;
        if(isEnabled)
        {
            vicrabcrashid_generate(g_eventID);
            if(!installSignalHandler())
            {
                return;
            }
        }
        else
        {
            uninstallSignalHandler();
        }
    }
}

static bool isEnabled()
{
    return g_isEnabled;
}

static void addContextualInfoToEvent(struct VicrabCrash_MonitorContext* eventContext)
{
    if(!(eventContext->crashType & (VicrabCrashMonitorTypeSignal | VicrabCrashMonitorTypeMachException)))
    {
        eventContext->signal.signum = SIGABRT;
    }
}

#endif

VicrabCrashMonitorAPI* vicrabcrashcm_signal_getAPI()
{
    static VicrabCrashMonitorAPI api =
    {
#if VicrabCrashCRASH_HAS_SIGNAL
        .setEnabled = setEnabled,
        .isEnabled = isEnabled,
        .addContextualInfoToEvent = addContextualInfoToEvent
#endif
    };
    return &api;
}
