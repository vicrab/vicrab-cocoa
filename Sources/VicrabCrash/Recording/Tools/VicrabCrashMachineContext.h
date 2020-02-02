//
//  VicrabCrashMachineContext.h
//
//  Created by Karl Stenerud on 2016-12-02.
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


#ifndef HDR_VicrabCrashMachineContext_h
#define HDR_VicrabCrashMachineContext_h

#ifdef __cplusplus
extern "C" {
#endif

#include "VicrabCrashThread.h"
#include <stdbool.h>

/** Suspend the runtime environment.
 */
void vicrabcrashmc_suspendEnvironment(void);

/** Resume the runtime environment.
 */
void vicrabcrashmc_resumeEnvironment(void);

/** Create a new machine context on the stack.
 * This macro creates a storage object on the stack, as well as a pointer of type
 * struct VicrabCrashMachineContext* in the current scope, which points to the storage object.
 *
 * Example usage: VicrabCrashMC_NEW_CONTEXT(a_context);
 * This creates a new pointer at the current scope that behaves as if:
 *     struct VicrabCrashMachineContext* a_context = some_storage_location;
 *
 * @param NAME The C identifier to give the pointer.
 */
#define VicrabCrashMC_NEW_CONTEXT(NAME) \
    char vicrabcrashmc_##NAME##_storage[vicrabcrashmc_contextSize()]; \
    struct VicrabCrashMachineContext* NAME = (struct VicrabCrashMachineContext*)vicrabcrashmc_##NAME##_storage

struct VicrabCrashMachineContext;

/** Get the internal size of a machine context.
 */
int vicrabcrashmc_contextSize(void);

/** Fill in a machine context from a thread.
 *
 * @param thread The thread to get information from.
 * @param destinationContext The context to fill.
 * @param isCrashedContext Used to indicate that this is the thread that crashed,
 *
 * @return true if successful.
 */
bool vicrabcrashmc_getContextForThread(VicrabCrashThread thread, struct VicrabCrashMachineContext* destinationContext, bool isCrashedContext);

/** Fill in a machine context from a signal handler.
 * A signal handler context is always assumed to be a crashed context.
 *
 * @param signalUserContext The signal context to get information from.
 * @param destinationContext The context to fill.
 *
 * @return true if successful.
 */
bool vicrabcrashmc_getContextForSignal(void* signalUserContext, struct VicrabCrashMachineContext* destinationContext);

/** Get the thread associated with a machine context.
 *
 * @param context The machine context.
 *
 * @return The associated thread.
 */
VicrabCrashThread vicrabcrashmc_getThreadFromContext(const struct VicrabCrashMachineContext* const context);

/** Get the number of threads stored in a machine context.
 *
 * @param context The machine context.
 *
 * @return The number of threads.
 */
int vicrabcrashmc_getThreadCount(const struct VicrabCrashMachineContext* const context);

/** Get a thread from a machine context.
 *
 * @param context The machine context.
 * @param index The index of the thread to retrieve.
 *
 * @return The thread.
 */
VicrabCrashThread vicrabcrashmc_getThreadAtIndex(const struct VicrabCrashMachineContext* const context, int index);

/** Get the index of a thread.
 *
 * @param context The machine context.
 * @param thread The thread.
 *
 * @return The thread's index, or -1 if it couldn't be determined.
 */
int vicrabcrashmc_indexOfThread(const struct VicrabCrashMachineContext* const context, VicrabCrashThread thread);

/** Check if this is a crashed context.
 */
bool vicrabcrashmc_isCrashedContext(const struct VicrabCrashMachineContext* const context);

/** Check if this context can have stored CPU state.
 */
bool vicrabcrashmc_canHaveCPUState(const struct VicrabCrashMachineContext* const context);

/** Check if this context has valid exception registers.
 */
bool vicrabcrashmc_hasValidExceptionRegisters(const struct VicrabCrashMachineContext* const context);

/** Add a thread to the reserved threads list.
 *
 * @param thread The thread to add to the list.
 */
void vicrabcrashmc_addReservedThread(VicrabCrashThread thread);


#ifdef __cplusplus
}
#endif

#endif // HDR_VicrabCrashMachineContext_h
