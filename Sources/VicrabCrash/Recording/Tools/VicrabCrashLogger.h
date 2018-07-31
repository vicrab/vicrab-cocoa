//
//  VicrabCrashLogger.h
//
//  Created by Karl Stenerud on 11-06-25.
//
//  Copyright (c) 2011 Karl Stenerud. All rights reserved.
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


/**
 * VicrabCrashLogger
 * ========
 *
 * Prints log entries to the console consisting of:
 * - Level (Error, Warn, Info, Debug, Trace)
 * - File
 * - Line
 * - Function
 * - Message
 *
 * Allows setting the minimum logging level in the preprocessor.
 *
 * Works in C or Objective-C contexts, with or without ARC, using CLANG or GCC.
 *
 *
 * =====
 * USAGE
 * =====
 *
 * Set the log level in your "Preprocessor Macros" build setting. You may choose
 * TRACE, DEBUG, INFO, WARN, ERROR. If nothing is set, it defaults to ERROR.
 *
 * Example: VicrabCrashLogger_Level=WARN
 *
 * Anything below the level specified for VicrabCrashLogger_Level will not be compiled
 * or printed.
 *
 *
 * Next, include the header file:
 *
 * #include "VicrabCrashLogger.h"
 *
 *
 * Next, call the logger functions from your code (using objective-c strings
 * in objective-C files and regular strings in regular C files):
 *
 * Code:
 *    VicrabCrashLOG_ERROR(@"Some error message");
 *
 * Prints:
 *    2011-07-16 05:41:01.379 TestApp[4439:f803] ERROR: SomeClass.m (21): -[SomeFunction]: Some error message
 *
 * Code:
 *    VicrabCrashLOG_INFO(@"Info about %@", someObject);
 *
 * Prints:
 *    2011-07-16 05:44:05.239 TestApp[4473:f803] INFO : SomeClass.m (20): -[SomeFunction]: Info about <NSObject: 0xb622840>
 *
 *
 * The "BASIC" versions of the macros behave exactly like NSLog() or printf(),
 * except they respect the VicrabCrashLogger_Level setting:
 *
 * Code:
 *    VicrabCrashLOGBASIC_ERROR(@"A basic log entry");
 *
 * Prints:
 *    2011-07-16 05:44:05.916 TestApp[4473:f803] A basic log entry
 *
 *
 * NOTE: In C files, use "" instead of @"" in the format field. Logging calls
 *       in C files do not print the NSLog preamble:
 *
 * Objective-C version:
 *    VicrabCrashLOG_ERROR(@"Some error message");
 *
 *    2011-07-16 05:41:01.379 TestApp[4439:f803] ERROR: SomeClass.m (21): -[SomeFunction]: Some error message
 *
 * C version:
 *    VicrabCrashLOG_ERROR("Some error message");
 *
 *    ERROR: SomeClass.c (21): SomeFunction(): Some error message
 *
 *
 * =============
 * LOCAL LOGGING
 * =============
 *
 * You can control logging messages at the local file level using the
 * "VicrabCrashLogger_LocalLevel" define. Note that it must be defined BEFORE
 * including VicrabCrashLogger.h
 *
 * The VicrabCrashLOG_XX() and VicrabCrashLOGBASIC_XX() macros will print out based on the LOWER
 * of VicrabCrashLogger_Level and VicrabCrashLogger_LocalLevel, so if VicrabCrashLogger_Level is DEBUG
 * and VicrabCrashLogger_LocalLevel is TRACE, it will print all the way down to the trace
 * level for the local file where VicrabCrashLogger_LocalLevel was defined, and to the
 * debug level everywhere else.
 *
 * Example:
 *
 * // VicrabCrashLogger_LocalLevel, if defined, MUST come BEFORE including VicrabCrashLogger.h
 * #define VicrabCrashLogger_LocalLevel TRACE
 * #import "VicrabCrashLogger.h"
 *
 *
 * ===============
 * IMPORTANT NOTES
 * ===============
 *
 * The C logger changes its behavior depending on the value of the preprocessor
 * define VicrabCrashLogger_CBufferSize.
 *
 * If VicrabCrashLogger_CBufferSize is > 0, the C logger will behave in an async-safe
 * manner, calling write() instead of printf(). Any log messages that exceed the
 * length specified by VicrabCrashLogger_CBufferSize will be truncated.
 *
 * If VicrabCrashLogger_CBufferSize == 0, the C logger will use printf(), and there will
 * be no limit on the log message length.
 *
 * VicrabCrashLogger_CBufferSize can only be set as a preprocessor define, and will
 * default to 1024 if not specified during compilation.
 */


// ============================================================================
#pragma mark - (internal) -
// ============================================================================


#ifndef HDR_VicrabCrashLogger_h
#define HDR_VicrabCrashLogger_h

#ifdef __cplusplus
extern "C" {
#endif


#include <stdbool.h>


#ifdef __OBJC__

#import <CoreFoundation/CoreFoundation.h>

void i_vicrabcrashlog_logObjC(const char* level,
                     const char* file,
                     int line,
                     const char* function,
                     CFStringRef fmt, ...);

void i_vicrabcrashlog_logObjCBasic(CFStringRef fmt, ...);

#define i_VicrabCrashLOG_FULL(LEVEL,FILE,LINE,FUNCTION,FMT,...) i_vicrabcrashlog_logObjC(LEVEL,FILE,LINE,FUNCTION,(__bridge CFStringRef)FMT,##__VA_ARGS__)
#define i_VicrabCrashLOG_BASIC(FMT, ...) i_vicrabcrashlog_logObjCBasic((__bridge CFStringRef)FMT,##__VA_ARGS__)

#else // __OBJC__

void i_vicrabcrashlog_logC(const char* level,
                  const char* file,
                  int line,
                  const char* function,
                  const char* fmt, ...);

void i_vicrabcrashlog_logCBasic(const char* fmt, ...);

#define i_VicrabCrashLOG_FULL i_vicrabcrashlog_logC
#define i_VicrabCrashLOG_BASIC i_vicrabcrashlog_logCBasic

#endif // __OBJC__


/* Back up any existing defines by the same name */
#ifdef VicrabCrash_NONE
    #define VicrabCrashLOG_BAK_NONE VicrabCrash_NONE
    #undef VicrabCrash_NONE
#endif
#ifdef ERROR
    #define VicrabCrashLOG_BAK_ERROR ERROR
    #undef ERROR
#endif
#ifdef WARN
    #define VicrabCrashLOG_BAK_WARN WARN
    #undef WARN
#endif
#ifdef INFO
    #define VicrabCrashLOG_BAK_INFO INFO
    #undef INFO
#endif
#ifdef DEBUG
    #define VicrabCrashLOG_BAK_DEBUG DEBUG
    #undef DEBUG
#endif
#ifdef TRACE
    #define VicrabCrashLOG_BAK_TRACE TRACE
    #undef TRACE
#endif


#define VicrabCrashLogger_Level_None   0
#define VicrabCrashLogger_Level_Error 10
#define VicrabCrashLogger_Level_Warn  20
#define VicrabCrashLogger_Level_Info  30
#define VicrabCrashLogger_Level_Debug 40
#define VicrabCrashLogger_Level_Trace 50

#define VicrabCrash_NONE  VicrabCrashLogger_Level_None
#define ERROR VicrabCrashLogger_Level_Error
#define WARN  VicrabCrashLogger_Level_Warn
#define INFO  VicrabCrashLogger_Level_Info
#define DEBUG VicrabCrashLogger_Level_Debug
#define TRACE VicrabCrashLogger_Level_Trace


#ifndef VicrabCrashLogger_Level
    #define VicrabCrashLogger_Level VicrabCrashLogger_Level_Error
#endif

#ifndef VicrabCrashLogger_LocalLevel
    #define VicrabCrashLogger_LocalLevel VicrabCrashLogger_Level_None
#endif

#define a_VicrabCrashLOG_FULL(LEVEL, FMT, ...) \
    i_VicrabCrashLOG_FULL(LEVEL, \
                 __FILE__, \
                 __LINE__, \
                 __PRETTY_FUNCTION__, \
                 FMT, \
                 ##__VA_ARGS__)



// ============================================================================
#pragma mark - API -
// ============================================================================

/** Set the filename to log to.
 *
 * @param filename The file to write to (NULL = write to stdout).
 *
 * @param overwrite If true, overwrite the log file.
 */
bool vicrabcrashlog_setLogFilename(const char* filename, bool overwrite);

/** Clear the log file. */
bool vicrabcrashlog_clearLogFile(void);

/** Tests if the logger would print at the specified level.
 *
 * @param LEVEL The level to test for. One of:
 *            VicrabCrashLogger_Level_Error,
 *            VicrabCrashLogger_Level_Warn,
 *            VicrabCrashLogger_Level_Info,
 *            VicrabCrashLogger_Level_Debug,
 *            VicrabCrashLogger_Level_Trace,
 *
 * @return TRUE if the logger would print at the specified level.
 */
#define VicrabCrashLOG_PRINTS_AT_LEVEL(LEVEL) \
    (VicrabCrashLogger_Level >= LEVEL || VicrabCrashLogger_LocalLevel >= LEVEL)

/** Log a message regardless of the log settings.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#define VicrabCrashLOG_ALWAYS(FMT, ...) a_VicrabCrashLOG_FULL("FORCE", FMT, ##__VA_ARGS__)
#define VicrabCrashLOGBASIC_ALWAYS(FMT, ...) i_VicrabCrashLOG_BASIC(FMT, ##__VA_ARGS__)


/** Log an error.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if VicrabCrashLOG_PRINTS_AT_LEVEL(VicrabCrashLogger_Level_Error)
    #define VicrabCrashLOG_ERROR(FMT, ...) a_VicrabCrashLOG_FULL("ERROR", FMT, ##__VA_ARGS__)
    #define VicrabCrashLOGBASIC_ERROR(FMT, ...) i_VicrabCrashLOG_BASIC(FMT, ##__VA_ARGS__)
#else
    #define VicrabCrashLOG_ERROR(FMT, ...)
    #define VicrabCrashLOGBASIC_ERROR(FMT, ...)
#endif

/** Log a warning.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if VicrabCrashLOG_PRINTS_AT_LEVEL(VicrabCrashLogger_Level_Warn)
    #define VicrabCrashLOG_WARN(FMT, ...)  a_VicrabCrashLOG_FULL("WARN ", FMT, ##__VA_ARGS__)
    #define VicrabCrashLOGBASIC_WARN(FMT, ...) i_VicrabCrashLOG_BASIC(FMT, ##__VA_ARGS__)
#else
    #define VicrabCrashLOG_WARN(FMT, ...)
    #define VicrabCrashLOGBASIC_WARN(FMT, ...)
#endif

/** Log an info message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if VicrabCrashLOG_PRINTS_AT_LEVEL(VicrabCrashLogger_Level_Info)
    #define VicrabCrashLOG_INFO(FMT, ...)  a_VicrabCrashLOG_FULL("INFO ", FMT, ##__VA_ARGS__)
    #define VicrabCrashLOGBASIC_INFO(FMT, ...) i_VicrabCrashLOG_BASIC(FMT, ##__VA_ARGS__)
#else
    #define VicrabCrashLOG_INFO(FMT, ...)
    #define VicrabCrashLOGBASIC_INFO(FMT, ...)
#endif

/** Log a debug message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if VicrabCrashLOG_PRINTS_AT_LEVEL(VicrabCrashLogger_Level_Debug)
    #define VicrabCrashLOG_DEBUG(FMT, ...) a_VicrabCrashLOG_FULL("DEBUG", FMT, ##__VA_ARGS__)
    #define VicrabCrashLOGBASIC_DEBUG(FMT, ...) i_VicrabCrashLOG_BASIC(FMT, ##__VA_ARGS__)
#else
    #define VicrabCrashLOG_DEBUG(FMT, ...)
    #define VicrabCrashLOGBASIC_DEBUG(FMT, ...)
#endif

/** Log a trace message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if VicrabCrashLOG_PRINTS_AT_LEVEL(VicrabCrashLogger_Level_Trace)
    #define VicrabCrashLOG_TRACE(FMT, ...) a_VicrabCrashLOG_FULL("TRACE", FMT, ##__VA_ARGS__)
    #define VicrabCrashLOGBASIC_TRACE(FMT, ...) i_VicrabCrashLOG_BASIC(FMT, ##__VA_ARGS__)
#else
    #define VicrabCrashLOG_TRACE(FMT, ...)
    #define VicrabCrashLOGBASIC_TRACE(FMT, ...)
#endif



// ============================================================================
#pragma mark - (internal) -
// ============================================================================

/* Put everything back to the way we found it. */
#undef ERROR
#ifdef VicrabCrashLOG_BAK_ERROR
    #define ERROR VicrabCrashLOG_BAK_ERROR
    #undef VicrabCrashLOG_BAK_ERROR
#endif
#undef WARNING
#ifdef VicrabCrashLOG_BAK_WARN
    #define WARNING VicrabCrashLOG_BAK_WARN
    #undef VicrabCrashLOG_BAK_WARN
#endif
#undef INFO
#ifdef VicrabCrashLOG_BAK_INFO
    #define INFO VicrabCrashLOG_BAK_INFO
    #undef VicrabCrashLOG_BAK_INFO
#endif
#undef DEBUG
#ifdef VicrabCrashLOG_BAK_DEBUG
    #define DEBUG VicrabCrashLOG_BAK_DEBUG
    #undef VicrabCrashLOG_BAK_DEBUG
#endif
#undef TRACE
#ifdef VicrabCrashLOG_BAK_TRACE
    #define TRACE VicrabCrashLOG_BAK_TRACE
    #undef VicrabCrashLOG_BAK_TRACE
#endif


#ifdef __cplusplus
}
#endif

#endif // HDR_VicrabCrashLogger_h
