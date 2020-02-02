//
//  VicrabCrashStackCursor_Backtrace.c
//
//  Copyright (c) 2016 Karl Stenerud. All rights reserved.
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


#include "VicrabCrashStackCursor_Backtrace.h"
#include "VicrabCrashCPU.h"

//#define VicrabCrashLogger_LocalLevel TRACE
#include "VicrabCrashLogger.h"

static bool advanceCursor(VicrabCrashStackCursor *cursor)
{
    VicrabCrashStackCursor_Backtrace_Context* context = (VicrabCrashStackCursor_Backtrace_Context*)cursor->context;
    int endDepth = context->backtraceLength - context->skippedEntries;
    if(cursor->state.currentDepth < endDepth)
    {
        int currentIndex = cursor->state.currentDepth + context->skippedEntries;
        uintptr_t nextAddress = context->backtrace[currentIndex];
        // Bug: The system sometimes gives a backtrace with an extra 0x00000001 at the end.
        if(nextAddress > 1)
        {
            cursor->stackEntry.address = vicrabcrashcpu_normaliseInstructionPointer(nextAddress);
            cursor->state.currentDepth++;
            return true;
        }
    }
    return false;
}

void vicrabcrashsc_initWithBacktrace(VicrabCrashStackCursor *cursor, const uintptr_t* backtrace, int backtraceLength, int skipEntries)
{
    vicrabcrashsc_initCursor(cursor, vicrabcrashsc_resetCursor, advanceCursor);
    VicrabCrashStackCursor_Backtrace_Context* context = (VicrabCrashStackCursor_Backtrace_Context*)cursor->context;
    context->skippedEntries = skipEntries;
    context->backtraceLength = backtraceLength;
    context->backtrace = backtrace;
}
