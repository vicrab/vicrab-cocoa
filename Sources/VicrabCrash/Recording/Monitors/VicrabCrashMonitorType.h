//
//  VicrabCrashMonitorType.h
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


#ifndef HDR_VicrabCrashMonitorType_h
#define HDR_VicrabCrashMonitorType_h

#ifdef __cplusplus
extern "C" {
#endif


/** Various aspects of the system that can be monitored:
 * - Mach kernel exception
 * - Fatal signal
 * - Uncaught C++ exception
 * - Uncaught Objective-C NSException
 * - Deadlock on the main thread
 * - User reported custom exception
 */
typedef enum
{
    /* Captures and reports Mach exceptions. */
    VicrabCrashMonitorTypeMachException      = 0x01,

    /* Captures and reports POSIX signals. */
    VicrabCrashMonitorTypeSignal             = 0x02,

    /* Captures and reports C++ exceptions.
     * Note: This will slightly slow down exception processing.
     */
    VicrabCrashMonitorTypeCPPException       = 0x04,

    /* Captures and reports NSExceptions. */
    VicrabCrashMonitorTypeNSException        = 0x08,

    /* Detects and reports a deadlock in the main thread. */
    VicrabCrashMonitorTypeMainThreadDeadlock = 0x10,

    /* Accepts and reports user-generated exceptions. */
    VicrabCrashMonitorTypeUserReported       = 0x20,

    /* Keeps track of and injects system information. */
    VicrabCrashMonitorTypeSystem             = 0x40,

    /* Keeps track of and injects application state. */
    VicrabCrashMonitorTypeApplicationState   = 0x80,

    /* Keeps track of zombies, and injects the last zombie NSException. */
    VicrabCrashMonitorTypeZombie             = 0x100,
} VicrabCrashMonitorType;

#define VicrabCrashMonitorTypeAll              \
(                                          \
    VicrabCrashMonitorTypeMachException      | \
    VicrabCrashMonitorTypeSignal             | \
    VicrabCrashMonitorTypeCPPException       | \
    VicrabCrashMonitorTypeNSException        | \
    VicrabCrashMonitorTypeMainThreadDeadlock | \
    VicrabCrashMonitorTypeUserReported       | \
    VicrabCrashMonitorTypeSystem             | \
    VicrabCrashMonitorTypeApplicationState   | \
    VicrabCrashMonitorTypeZombie               \
)

#define VicrabCrashMonitorTypeExperimental     \
(                                          \
    VicrabCrashMonitorTypeMainThreadDeadlock   \
)

#define VicrabCrashMonitorTypeDebuggerUnsafe   \
(                                          \
    VicrabCrashMonitorTypeMachException      | \
    VicrabCrashMonitorTypeSignal             | \
    VicrabCrashMonitorTypeCPPException       | \
    VicrabCrashMonitorTypeNSException          \
)

#define VicrabCrashMonitorTypeAsyncSafe        \
(                                          \
    VicrabCrashMonitorTypeMachException      | \
    VicrabCrashMonitorTypeSignal               \
)

#define VicrabCrashMonitorTypeOptional         \
(                                          \
    VicrabCrashMonitorTypeZombie               \
)

#define VicrabCrashMonitorTypeAsyncUnsafe (VicrabCrashMonitorTypeAll & (~VicrabCrashMonitorTypeAsyncSafe))

/** Monitors that are safe to enable in a debugger. */
#define VicrabCrashMonitorTypeDebuggerSafe (VicrabCrashMonitorTypeAll & (~VicrabCrashMonitorTypeDebuggerUnsafe))

/** Monitors that are safe to use in a production environment.
 * All other monitors should be considered experimental.
 */
#define VicrabCrashMonitorTypeProductionSafe (VicrabCrashMonitorTypeAll & (~VicrabCrashMonitorTypeExperimental))

/** Production safe monitors, minus the optional ones. */
#define VicrabCrashMonitorTypeProductionSafeMinimal (VicrabCrashMonitorTypeProductionSafe & (~VicrabCrashMonitorTypeOptional))

/** Monitors that are required for proper operation.
 * These add essential information to the reports, but do not trigger reporting.
 */
#define VicrabCrashMonitorTypeRequired (VicrabCrashMonitorTypeSystem | VicrabCrashMonitorTypeApplicationState)

/** Effectively disables automatica reporting. The only way to generate a report
 * in this mode is by manually calling vicrabcrash_reportUserException().
 */
#define VicrabCrashMonitorTypeManual (VicrabCrashMonitorTypeRequired | VicrabCrashMonitorTypeUserReported)

#define VicrabCrashMonitorTypeNone 0

const char* vicrabcrashmonitortype_name(VicrabCrashMonitorType monitorType);


#ifdef __cplusplus
}
#endif

#endif // HDR_VicrabCrashMonitorType_h
