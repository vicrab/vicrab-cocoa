//
//  VicrabCrashReport.m
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


#include "VicrabCrashReport.h"

#include "VicrabCrashReportFields.h"
#include "VicrabCrashReportWriter.h"
#include "VicrabCrashDynamicLinker.h"
#include "VicrabCrashFileUtils.h"
#include "VicrabCrashJSONCodec.h"
#include "VicrabCrashCPU.h"
#include "VicrabCrashMemory.h"
#include "VicrabCrashMach.h"
#include "VicrabCrashThread.h"
#include "VicrabCrashObjC.h"
#include "VicrabCrashSignalInfo.h"
#include "VicrabCrashMonitor_Zombie.h"
#include "VicrabCrashString.h"
#include "VicrabCrashReportVersion.h"
#include "VicrabCrashStackCursor_Backtrace.h"
#include "VicrabCrashStackCursor_MachineContext.h"
#include "VicrabCrashSystemCapabilities.h"
#include "VicrabCrashCachedData.h"

//#define VicrabCrashLogger_LocalLevel TRACE
#include "VicrabCrashLogger.h"

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>


// ============================================================================
#pragma mark - Constants -
// ============================================================================

/** Default number of objects, subobjects, and ivars to record from a memory loc */
#define kDefaultMemorySearchDepth 15

/** How far to search the stack (in pointer sized jumps) for notable data. */
#define kStackNotableSearchBackDistance 20
#define kStackNotableSearchForwardDistance 10

/** How much of the stack to dump (in pointer sized jumps). */
#define kStackContentsPushedDistance 20
#define kStackContentsPoppedDistance 10
#define kStackContentsTotalDistance (kStackContentsPushedDistance + kStackContentsPoppedDistance)

/** The minimum length for a valid string. */
#define kMinStringLength 4


// ============================================================================
#pragma mark - JSON Encoding -
// ============================================================================

#define getJsonContext(REPORT_WRITER) ((VicrabCrashJSONEncodeContext*)((REPORT_WRITER)->context))

/** Used for writing hex string values. */
static const char g_hexNybbles[] =
{
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
};

// ============================================================================
#pragma mark - Runtime Config -
// ============================================================================

typedef struct
{
    /** If YES, introspect memory contents during a crash.
     * Any Objective-C objects or C strings near the stack pointer or referenced by
     * cpu registers or exceptions will be recorded in the crash report, along with
     * their contents.
     */
    bool enabled;

    /** List of classes that should never be introspected.
     * Whenever a class in this list is encountered, only the class name will be recorded.
     */
    const char** restrictedClasses;
    int restrictedClassesCount;
} VicrabCrash_IntrospectionRules;

static const char* g_userInfoJSON;
static VicrabCrash_IntrospectionRules g_introspectionRules;
static VicrabCrashReportWriteCallback g_userSectionWriteCallback;


#pragma mark Callbacks

static void addBooleanElement(const VicrabCrashReportWriter* const writer, const char* const key, const bool value)
{
    vicrabcrashjson_addBooleanElement(getJsonContext(writer), key, value);
}

static void addFloatingPointElement(const VicrabCrashReportWriter* const writer, const char* const key, const double value)
{
    vicrabcrashjson_addFloatingPointElement(getJsonContext(writer), key, value);
}

static void addIntegerElement(const VicrabCrashReportWriter* const writer, const char* const key, const int64_t value)
{
    vicrabcrashjson_addIntegerElement(getJsonContext(writer), key, value);
}

static void addUIntegerElement(const VicrabCrashReportWriter* const writer, const char* const key, const uint64_t value)
{
    vicrabcrashjson_addIntegerElement(getJsonContext(writer), key, (int64_t)value);
}

static void addStringElement(const VicrabCrashReportWriter* const writer, const char* const key, const char* const value)
{
    vicrabcrashjson_addStringElement(getJsonContext(writer), key, value, VicrabCrashJSON_SIZE_AUTOMATIC);
}

static void addTextFileElement(const VicrabCrashReportWriter* const writer, const char* const key, const char* const filePath)
{
    const int fd = open(filePath, O_RDONLY);
    if(fd < 0)
    {
        VicrabCrashLOG_ERROR("Could not open file %s: %s", filePath, strerror(errno));
        return;
    }

    if(vicrabcrashjson_beginStringElement(getJsonContext(writer), key) != VicrabCrashJSON_OK)
    {
        VicrabCrashLOG_ERROR("Could not start string element");
        goto done;
    }

    char buffer[512];
    int bytesRead;
    for(bytesRead = (int)read(fd, buffer, sizeof(buffer));
        bytesRead > 0;
        bytesRead = (int)read(fd, buffer, sizeof(buffer)))
    {
        if(vicrabcrashjson_appendStringElement(getJsonContext(writer), buffer, bytesRead) != VicrabCrashJSON_OK)
        {
            VicrabCrashLOG_ERROR("Could not append string element");
            goto done;
        }
    }

done:
    vicrabcrashjson_endStringElement(getJsonContext(writer));
    close(fd);
}

static void addDataElement(const VicrabCrashReportWriter* const writer,
                           const char* const key,
                           const char* const value,
                           const int length)
{
    vicrabcrashjson_addDataElement(getJsonContext(writer), key, value, length);
}

static void beginDataElement(const VicrabCrashReportWriter* const writer, const char* const key)
{
    vicrabcrashjson_beginDataElement(getJsonContext(writer), key);
}

static void appendDataElement(const VicrabCrashReportWriter* const writer, const char* const value, const int length)
{
    vicrabcrashjson_appendDataElement(getJsonContext(writer), value, length);
}

static void endDataElement(const VicrabCrashReportWriter* const writer)
{
    vicrabcrashjson_endDataElement(getJsonContext(writer));
}

static void addUUIDElement(const VicrabCrashReportWriter* const writer, const char* const key, const unsigned char* const value)
{
    if(value == NULL)
    {
        vicrabcrashjson_addNullElement(getJsonContext(writer), key);
    }
    else
    {
        char uuidBuffer[37];
        const unsigned char* src = value;
        char* dst = uuidBuffer;
        for(int i = 0; i < 4; i++)
        {
            *dst++ = g_hexNybbles[(*src>>4)&15];
            *dst++ = g_hexNybbles[(*src++)&15];
        }
        *dst++ = '-';
        for(int i = 0; i < 2; i++)
        {
            *dst++ = g_hexNybbles[(*src>>4)&15];
            *dst++ = g_hexNybbles[(*src++)&15];
        }
        *dst++ = '-';
        for(int i = 0; i < 2; i++)
        {
            *dst++ = g_hexNybbles[(*src>>4)&15];
            *dst++ = g_hexNybbles[(*src++)&15];
        }
        *dst++ = '-';
        for(int i = 0; i < 2; i++)
        {
            *dst++ = g_hexNybbles[(*src>>4)&15];
            *dst++ = g_hexNybbles[(*src++)&15];
        }
        *dst++ = '-';
        for(int i = 0; i < 6; i++)
        {
            *dst++ = g_hexNybbles[(*src>>4)&15];
            *dst++ = g_hexNybbles[(*src++)&15];
        }

        vicrabcrashjson_addStringElement(getJsonContext(writer), key, uuidBuffer, (int)(dst - uuidBuffer));
    }
}

static void addJSONElement(const VicrabCrashReportWriter* const writer,
                           const char* const key,
                           const char* const jsonElement,
                           bool closeLastContainer)
{
    int jsonResult = vicrabcrashjson_addJSONElement(getJsonContext(writer),
                                           key,
                                           jsonElement,
                                           (int)strlen(jsonElement),
                                           closeLastContainer);
    if(jsonResult != VicrabCrashJSON_OK)
    {
        char errorBuff[100];
        snprintf(errorBuff,
                 sizeof(errorBuff),
                 "Invalid JSON data: %s",
                 vicrabcrashjson_stringForError(jsonResult));
        vicrabcrashjson_beginObject(getJsonContext(writer), key);
        vicrabcrashjson_addStringElement(getJsonContext(writer),
                                VicrabCrashField_Error,
                                errorBuff,
                                VicrabCrashJSON_SIZE_AUTOMATIC);
        vicrabcrashjson_addStringElement(getJsonContext(writer),
                                VicrabCrashField_JSONData,
                                jsonElement,
                                VicrabCrashJSON_SIZE_AUTOMATIC);
        vicrabcrashjson_endContainer(getJsonContext(writer));
    }
}

static void addJSONElementFromFile(const VicrabCrashReportWriter* const writer,
                                   const char* const key,
                                   const char* const filePath,
                                   bool closeLastContainer)
{
    vicrabcrashjson_addJSONFromFile(getJsonContext(writer), key, filePath, closeLastContainer);
}

static void beginObject(const VicrabCrashReportWriter* const writer, const char* const key)
{
    vicrabcrashjson_beginObject(getJsonContext(writer), key);
}

static void beginArray(const VicrabCrashReportWriter* const writer, const char* const key)
{
    vicrabcrashjson_beginArray(getJsonContext(writer), key);
}

static void endContainer(const VicrabCrashReportWriter* const writer)
{
    vicrabcrashjson_endContainer(getJsonContext(writer));
}


static void addTextLinesFromFile(const VicrabCrashReportWriter* const writer, const char* const key, const char* const filePath)
{
    char readBuffer[1024];
    VicrabCrashBufferedReader reader;
    if(!vicrabcrashfu_openBufferedReader(&reader, filePath, readBuffer, sizeof(readBuffer)))
    {
        return;
    }
    char buffer[1024];
    beginArray(writer, key);
    {
        for(;;)
        {
            int length = sizeof(buffer);
            vicrabcrashfu_readBufferedReaderUntilChar(&reader, '\n', buffer, &length);
            if(length <= 0)
            {
                break;
            }
            buffer[length - 1] = '\0';
            vicrabcrashjson_addStringElement(getJsonContext(writer), NULL, buffer, VicrabCrashJSON_SIZE_AUTOMATIC);
        }
    }
    endContainer(writer);
    vicrabcrashfu_closeBufferedReader(&reader);
}

static int addJSONData(const char* restrict const data, const int length, void* restrict userData)
{
    VicrabCrashBufferedWriter* writer = (VicrabCrashBufferedWriter*)userData;
    const bool success = vicrabcrashfu_writeBufferedWriter(writer, data, length);
    return success ? VicrabCrashJSON_OK : VicrabCrashJSON_ERROR_CANNOT_ADD_DATA;
}


// ============================================================================
#pragma mark - Utility -
// ============================================================================

/** Check if a memory address points to a valid null terminated UTF-8 string.
 *
 * @param address The address to check.
 *
 * @return true if the address points to a string.
 */
static bool isValidString(const void* const address)
{
    if((void*)address == NULL)
    {
        return false;
    }

    char buffer[500];
    if((uintptr_t)address+sizeof(buffer) < (uintptr_t)address)
    {
        // Wrapped around the address range.
        return false;
    }
    if(!vicrabcrashmem_copySafely(address, buffer, sizeof(buffer)))
    {
        return false;
    }
    return vicrabcrashstring_isNullTerminatedUTF8String(buffer, kMinStringLength, sizeof(buffer));
}

/** Get the backtrace for the specified machine context.
 *
 * This function will choose how to fetch the backtrace based on the crash and
 * machine context. It may store the backtrace in backtraceBuffer unless it can
 * be fetched directly from memory. Do not count on backtraceBuffer containing
 * anything. Always use the return value.
 *
 * @param crash The crash handler context.
 *
 * @param machineContext The machine context.
 *
 * @param cursor The stack cursor to fill.
 *
 * @return True if the cursor was filled.
 */
static bool getStackCursor(const VicrabCrash_MonitorContext* const crash,
                           const struct VicrabCrashMachineContext* const machineContext,
                           VicrabCrashStackCursor *cursor)
{
    if(vicrabcrashmc_getThreadFromContext(machineContext) == vicrabcrashmc_getThreadFromContext(crash->offendingMachineContext))
    {
        *cursor = *((VicrabCrashStackCursor*)crash->stackCursor);
        return true;
    }

    vicrabcrashsc_initWithMachineContext(cursor, VicrabCrashSC_STACK_OVERFLOW_THRESHOLD, machineContext);
    return true;
}


// ============================================================================
#pragma mark - Report Writing -
// ============================================================================

/** Write the contents of a memory location.
 * Also writes meta information about the data.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param address The memory address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeMemoryContents(const VicrabCrashReportWriter* const writer,
                                const char* const key,
                                const uintptr_t address,
                                int* limit);

/** Write a string to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeNSStringContents(const VicrabCrashReportWriter* const writer,
                                  const char* const key,
                                  const uintptr_t objectAddress,
                                  __unused int* limit)
{
    const void* object = (const void*)objectAddress;
    char buffer[200];
    if(vicrabcrashobjc_copyStringContents(object, buffer, sizeof(buffer)))
    {
        writer->addStringElement(writer, key, buffer);
    }
}

/** Write a URL to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeURLContents(const VicrabCrashReportWriter* const writer,
                             const char* const key,
                             const uintptr_t objectAddress,
                             __unused int* limit)
{
    const void* object = (const void*)objectAddress;
    char buffer[200];
    if(vicrabcrashobjc_copyStringContents(object, buffer, sizeof(buffer)))
    {
        writer->addStringElement(writer, key, buffer);
    }
}

/** Write a date to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeDateContents(const VicrabCrashReportWriter* const writer,
                              const char* const key,
                              const uintptr_t objectAddress,
                              __unused int* limit)
{
    const void* object = (const void*)objectAddress;
    writer->addFloatingPointElement(writer, key, vicrabcrashobjc_dateContents(object));
}

/** Write a number to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeNumberContents(const VicrabCrashReportWriter* const writer,
                                const char* const key,
                                const uintptr_t objectAddress,
                                __unused int* limit)
{
    const void* object = (const void*)objectAddress;
    writer->addFloatingPointElement(writer, key, vicrabcrashobjc_numberAsFloat(object));
}

/** Write an array to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeArrayContents(const VicrabCrashReportWriter* const writer,
                               const char* const key,
                               const uintptr_t objectAddress,
                               int* limit)
{
    const void* object = (const void*)objectAddress;
    uintptr_t firstObject;
    if(vicrabcrashobjc_arrayContents(object, &firstObject, 1) == 1)
    {
        writeMemoryContents(writer, key, firstObject, limit);
    }
}

/** Write out ivar information about an unknown object.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeUnknownObjectContents(const VicrabCrashReportWriter* const writer,
                                       const char* const key,
                                       const uintptr_t objectAddress,
                                       int* limit)
{
    (*limit)--;
    const void* object = (const void*)objectAddress;
    VicrabCrashObjCIvar ivars[10];
    int8_t s8;
    int16_t s16;
    int sInt;
    int32_t s32;
    int64_t s64;
    uint8_t u8;
    uint16_t u16;
    unsigned int uInt;
    uint32_t u32;
    uint64_t u64;
    float f32;
    double f64;
    bool b;
    void* pointer;


    writer->beginObject(writer, key);
    {
        if(vicrabcrashobjc_isTaggedPointer(object))
        {
            writer->addIntegerElement(writer, "tagged_payload", (int64_t)vicrabcrashobjc_taggedPointerPayload(object));
        }
        else
        {
            const void* class = vicrabcrashobjc_isaPointer(object);
            int ivarCount = vicrabcrashobjc_ivarList(class, ivars, sizeof(ivars)/sizeof(*ivars));
            *limit -= ivarCount;
            for(int i = 0; i < ivarCount; i++)
            {
                VicrabCrashObjCIvar* ivar = &ivars[i];
                switch(ivar->type[0])
                {
                    case 'c':
                        vicrabcrashobjc_ivarValue(object, ivar->index, &s8);
                        writer->addIntegerElement(writer, ivar->name, s8);
                        break;
                    case 'i':
                        vicrabcrashobjc_ivarValue(object, ivar->index, &sInt);
                        writer->addIntegerElement(writer, ivar->name, sInt);
                        break;
                    case 's':
                        vicrabcrashobjc_ivarValue(object, ivar->index, &s16);
                        writer->addIntegerElement(writer, ivar->name, s16);
                        break;
                    case 'l':
                        vicrabcrashobjc_ivarValue(object, ivar->index, &s32);
                        writer->addIntegerElement(writer, ivar->name, s32);
                        break;
                    case 'q':
                        vicrabcrashobjc_ivarValue(object, ivar->index, &s64);
                        writer->addIntegerElement(writer, ivar->name, s64);
                        break;
                    case 'C':
                        vicrabcrashobjc_ivarValue(object, ivar->index, &u8);
                        writer->addUIntegerElement(writer, ivar->name, u8);
                        break;
                    case 'I':
                        vicrabcrashobjc_ivarValue(object, ivar->index, &uInt);
                        writer->addUIntegerElement(writer, ivar->name, uInt);
                        break;
                    case 'S':
                        vicrabcrashobjc_ivarValue(object, ivar->index, &u16);
                        writer->addUIntegerElement(writer, ivar->name, u16);
                        break;
                    case 'L':
                        vicrabcrashobjc_ivarValue(object, ivar->index, &u32);
                        writer->addUIntegerElement(writer, ivar->name, u32);
                        break;
                    case 'Q':
                        vicrabcrashobjc_ivarValue(object, ivar->index, &u64);
                        writer->addUIntegerElement(writer, ivar->name, u64);
                        break;
                    case 'f':
                        vicrabcrashobjc_ivarValue(object, ivar->index, &f32);
                        writer->addFloatingPointElement(writer, ivar->name, f32);
                        break;
                    case 'd':
                        vicrabcrashobjc_ivarValue(object, ivar->index, &f64);
                        writer->addFloatingPointElement(writer, ivar->name, f64);
                        break;
                    case 'B':
                        vicrabcrashobjc_ivarValue(object, ivar->index, &b);
                        writer->addBooleanElement(writer, ivar->name, b);
                        break;
                    case '*':
                    case '@':
                    case '#':
                    case ':':
                        vicrabcrashobjc_ivarValue(object, ivar->index, &pointer);
                        writeMemoryContents(writer, ivar->name, (uintptr_t)pointer, limit);
                        break;
                    default:
                        VicrabCrashLOG_DEBUG("%s: Unknown ivar type [%s]", ivar->name, ivar->type);
                }
            }
        }
    }
    writer->endContainer(writer);
}

static bool isRestrictedClass(const char* name)
{
    if(g_introspectionRules.restrictedClasses != NULL)
    {
        for(int i = 0; i < g_introspectionRules.restrictedClassesCount; i++)
        {
            if(strcmp(name, g_introspectionRules.restrictedClasses[i]) == 0)
            {
                return true;
            }
        }
    }
    return false;
}

static void writeZombieIfPresent(const VicrabCrashReportWriter* const writer,
                                 const char* const key,
                                 const uintptr_t address)
{
#if VicrabCrashCRASH_HAS_OBJC
    const void* object = (const void*)address;
    const char* zombieClassName = vicrabcrashzombie_className(object);
    if(zombieClassName != NULL)
    {
        writer->addStringElement(writer, key, zombieClassName);
    }
#endif
}

static bool writeObjCObject(const VicrabCrashReportWriter* const writer,
                            const uintptr_t address,
                            int* limit)
{
#if VicrabCrashCRASH_HAS_OBJC
    const void* object = (const void*)address;
    switch(vicrabcrashobjc_objectType(object))
    {
        case VicrabCrashObjCTypeClass:
            writer->addStringElement(writer, VicrabCrashField_Type, VicrabCrashMemType_Class);
            writer->addStringElement(writer, VicrabCrashField_Class, vicrabcrashobjc_className(object));
            return true;
        case VicrabCrashObjCTypeObject:
        {
            writer->addStringElement(writer, VicrabCrashField_Type, VicrabCrashMemType_Object);
            const char* className = vicrabcrashobjc_objectClassName(object);
            writer->addStringElement(writer, VicrabCrashField_Class, className);
            if(!isRestrictedClass(className))
            {
                switch(vicrabcrashobjc_objectClassType(object))
                {
                    case VicrabCrashObjCClassTypeString:
                        writeNSStringContents(writer, VicrabCrashField_Value, address, limit);
                        return true;
                    case VicrabCrashObjCClassTypeURL:
                        writeURLContents(writer, VicrabCrashField_Value, address, limit);
                        return true;
                    case VicrabCrashObjCClassTypeDate:
                        writeDateContents(writer, VicrabCrashField_Value, address, limit);
                        return true;
                    case VicrabCrashObjCClassTypeArray:
                        if(*limit > 0)
                        {
                            writeArrayContents(writer, VicrabCrashField_FirstObject, address, limit);
                        }
                        return true;
                    case VicrabCrashObjCClassTypeNumber:
                        writeNumberContents(writer, VicrabCrashField_Value, address, limit);
                        return true;
                    case VicrabCrashObjCClassTypeDictionary:
                    case VicrabCrashObjCClassTypeException:
                        // TODO: Implement these.
                        if(*limit > 0)
                        {
                            writeUnknownObjectContents(writer, VicrabCrashField_Ivars, address, limit);
                        }
                        return true;
                    case VicrabCrashObjCClassTypeUnknown:
                        if(*limit > 0)
                        {
                            writeUnknownObjectContents(writer, VicrabCrashField_Ivars, address, limit);
                        }
                        return true;
                }
            }
            break;
        }
        case VicrabCrashObjCTypeBlock:
            writer->addStringElement(writer, VicrabCrashField_Type, VicrabCrashMemType_Block);
            const char* className = vicrabcrashobjc_objectClassName(object);
            writer->addStringElement(writer, VicrabCrashField_Class, className);
            return true;
        case VicrabCrashObjCTypeUnknown:
            break;
    }
#endif

    return false;
}

/** Write the contents of a memory location.
 * Also writes meta information about the data.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param address The memory address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeMemoryContents(const VicrabCrashReportWriter* const writer,
                                const char* const key,
                                const uintptr_t address,
                                int* limit)
{
    (*limit)--;
    const void* object = (const void*)address;
    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, VicrabCrashField_Address, address);
        writeZombieIfPresent(writer, VicrabCrashField_LastDeallocObject, address);
        if(!writeObjCObject(writer, address, limit))
        {
            if(object == NULL)
            {
                writer->addStringElement(writer, VicrabCrashField_Type, VicrabCrashMemType_NullPointer);
            }
            else if(isValidString(object))
            {
                writer->addStringElement(writer, VicrabCrashField_Type, VicrabCrashMemType_String);
                writer->addStringElement(writer, VicrabCrashField_Value, (const char*)object);
            }
            else
            {
                writer->addStringElement(writer, VicrabCrashField_Type, VicrabCrashMemType_Unknown);
            }
        }
    }
    writer->endContainer(writer);
}

static bool isValidPointer(const uintptr_t address)
{
    if(address == (uintptr_t)NULL)
    {
        return false;
    }

#if VicrabCrashCRASH_HAS_OBJC
    if(vicrabcrashobjc_isTaggedPointer((const void*)address))
    {
        if(!vicrabcrashobjc_isValidTaggedPointer((const void*)address))
        {
            return false;
        }
    }
#endif

    return true;
}

static bool isNotableAddress(const uintptr_t address)
{
    if(!isValidPointer(address))
    {
        return false;
    }

    const void* object = (const void*)address;

#if VicrabCrashCRASH_HAS_OBJC
    if(vicrabcrashzombie_className(object) != NULL)
    {
        return true;
    }

    if(vicrabcrashobjc_objectType(object) != VicrabCrashObjCTypeUnknown)
    {
        return true;
    }
#endif

    if(isValidString(object))
    {
        return true;
    }

    return false;
}

/** Write the contents of a memory location only if it contains notable data.
 * Also writes meta information about the data.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param address The memory address.
 */
static void writeMemoryContentsIfNotable(const VicrabCrashReportWriter* const writer,
                                         const char* const key,
                                         const uintptr_t address)
{
    if(isNotableAddress(address))
    {
        int limit = kDefaultMemorySearchDepth;
        writeMemoryContents(writer, key, address, &limit);
    }
}

/** Look for a hex value in a string and try to write whatever it references.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param string The string to search.
 */
static void writeAddressReferencedByString(const VicrabCrashReportWriter* const writer,
                                           const char* const key,
                                           const char* string)
{
    uint64_t address = 0;
    if(string == NULL || !vicrabcrashstring_extractHexValue(string, (int)strlen(string), &address))
    {
        return;
    }

    int limit = kDefaultMemorySearchDepth;
    writeMemoryContents(writer, key, (uintptr_t)address, &limit);
}

#pragma mark Backtrace

/** Write a backtrace to the report.
 *
 * @param writer The writer to write the backtrace to.
 *
 * @param key The object key, if needed.
 *
 * @param stackCursor The stack cursor to read from.
 */
static void writeBacktrace(const VicrabCrashReportWriter* const writer,
                           const char* const key,
                           VicrabCrashStackCursor* stackCursor)
{
    writer->beginObject(writer, key);
    {
        writer->beginArray(writer, VicrabCrashField_Contents);
        {
            while(stackCursor->advanceCursor(stackCursor))
            {
                writer->beginObject(writer, NULL);
                {
                    if(stackCursor->symbolicate(stackCursor))
                    {
                        if(stackCursor->stackEntry.imageName != NULL)
                        {
                            writer->addStringElement(writer, VicrabCrashField_ObjectName, vicrabcrashfu_lastPathEntry(stackCursor->stackEntry.imageName));
                        }
                        writer->addUIntegerElement(writer, VicrabCrashField_ObjectAddr, stackCursor->stackEntry.imageAddress);
                        if(stackCursor->stackEntry.symbolName != NULL)
                        {
                            writer->addStringElement(writer, VicrabCrashField_SymbolName, stackCursor->stackEntry.symbolName);
                        }
                        writer->addUIntegerElement(writer, VicrabCrashField_SymbolAddr, stackCursor->stackEntry.symbolAddress);
                    }
                    writer->addUIntegerElement(writer, VicrabCrashField_InstructionAddr, stackCursor->stackEntry.address);
                }
                writer->endContainer(writer);
            }
        }
        writer->endContainer(writer);
        writer->addIntegerElement(writer, VicrabCrashField_Skipped, 0);
    }
    writer->endContainer(writer);
}


#pragma mark Stack

/** Write a dump of the stack contents to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the stack from.
 *
 * @param isStackOverflow If true, the stack has overflowed.
 */
static void writeStackContents(const VicrabCrashReportWriter* const writer,
                               const char* const key,
                               const struct VicrabCrashMachineContext* const machineContext,
                               const bool isStackOverflow)
{
    uintptr_t sp = vicrabcrashcpu_stackPointer(machineContext);
    if((void*)sp == NULL)
    {
        return;
    }

    uintptr_t lowAddress = sp + (uintptr_t)(kStackContentsPushedDistance * (int)sizeof(sp) * vicrabcrashcpu_stackGrowDirection() * -1);
    uintptr_t highAddress = sp + (uintptr_t)(kStackContentsPoppedDistance * (int)sizeof(sp) * vicrabcrashcpu_stackGrowDirection());
    if(highAddress < lowAddress)
    {
        uintptr_t tmp = lowAddress;
        lowAddress = highAddress;
        highAddress = tmp;
    }
    writer->beginObject(writer, key);
    {
        writer->addStringElement(writer, VicrabCrashField_GrowDirection, vicrabcrashcpu_stackGrowDirection() > 0 ? "+" : "-");
        writer->addUIntegerElement(writer, VicrabCrashField_DumpStart, lowAddress);
        writer->addUIntegerElement(writer, VicrabCrashField_DumpEnd, highAddress);
        writer->addUIntegerElement(writer, VicrabCrashField_StackPtr, sp);
        writer->addBooleanElement(writer, VicrabCrashField_Overflow, isStackOverflow);
        uint8_t stackBuffer[kStackContentsTotalDistance * sizeof(sp)];
        int copyLength = (int)(highAddress - lowAddress);
        if(vicrabcrashmem_copySafely((void*)lowAddress, stackBuffer, copyLength))
        {
            writer->addDataElement(writer, VicrabCrashField_Contents, (void*)stackBuffer, copyLength);
        }
        else
        {
            writer->addStringElement(writer, VicrabCrashField_Error, "Stack contents not accessible");
        }
    }
    writer->endContainer(writer);
}

/** Write any notable addresses near the stack pointer (above and below).
 *
 * @param writer The writer.
 *
 * @param machineContext The context to retrieve the stack from.
 *
 * @param backDistance The distance towards the beginning of the stack to check.
 *
 * @param forwardDistance The distance past the end of the stack to check.
 */
static void writeNotableStackContents(const VicrabCrashReportWriter* const writer,
                                      const struct VicrabCrashMachineContext* const machineContext,
                                      const int backDistance,
                                      const int forwardDistance)
{
    uintptr_t sp = vicrabcrashcpu_stackPointer(machineContext);
    if((void*)sp == NULL)
    {
        return;
    }

    uintptr_t lowAddress = sp + (uintptr_t)(backDistance * (int)sizeof(sp) * vicrabcrashcpu_stackGrowDirection() * -1);
    uintptr_t highAddress = sp + (uintptr_t)(forwardDistance * (int)sizeof(sp) * vicrabcrashcpu_stackGrowDirection());
    if(highAddress < lowAddress)
    {
        uintptr_t tmp = lowAddress;
        lowAddress = highAddress;
        highAddress = tmp;
    }
    uintptr_t contentsAsPointer;
    char nameBuffer[40];
    for(uintptr_t address = lowAddress; address < highAddress; address += sizeof(address))
    {
        if(vicrabcrashmem_copySafely((void*)address, &contentsAsPointer, sizeof(contentsAsPointer)))
        {
            sprintf(nameBuffer, "stack@%p", (void*)address);
            writeMemoryContentsIfNotable(writer, nameBuffer, contentsAsPointer);
        }
    }
}


#pragma mark Registers

/** Write the contents of all regular registers to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeBasicRegisters(const VicrabCrashReportWriter* const writer,
                                const char* const key,
                                const struct VicrabCrashMachineContext* const machineContext)
{
    char registerNameBuff[30];
    const char* registerName;
    writer->beginObject(writer, key);
    {
        const int numRegisters = vicrabcrashcpu_numRegisters();
        for(int reg = 0; reg < numRegisters; reg++)
        {
            registerName = vicrabcrashcpu_registerName(reg);
            if(registerName == NULL)
            {
                snprintf(registerNameBuff, sizeof(registerNameBuff), "r%d", reg);
                registerName = registerNameBuff;
            }
            writer->addUIntegerElement(writer, registerName,
                                       vicrabcrashcpu_registerValue(machineContext, reg));
        }
    }
    writer->endContainer(writer);
}

/** Write the contents of all exception registers to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeExceptionRegisters(const VicrabCrashReportWriter* const writer,
                                    const char* const key,
                                    const struct VicrabCrashMachineContext* const machineContext)
{
    char registerNameBuff[30];
    const char* registerName;
    writer->beginObject(writer, key);
    {
        const int numRegisters = vicrabcrashcpu_numExceptionRegisters();
        for(int reg = 0; reg < numRegisters; reg++)
        {
            registerName = vicrabcrashcpu_exceptionRegisterName(reg);
            if(registerName == NULL)
            {
                snprintf(registerNameBuff, sizeof(registerNameBuff), "r%d", reg);
                registerName = registerNameBuff;
            }
            writer->addUIntegerElement(writer,registerName,
                                       vicrabcrashcpu_exceptionRegisterValue(machineContext, reg));
        }
    }
    writer->endContainer(writer);
}

/** Write all applicable registers.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeRegisters(const VicrabCrashReportWriter* const writer,
                           const char* const key,
                           const struct VicrabCrashMachineContext* const machineContext)
{
    writer->beginObject(writer, key);
    {
        writeBasicRegisters(writer, VicrabCrashField_Basic, machineContext);
        if(vicrabcrashmc_hasValidExceptionRegisters(machineContext))
        {
            writeExceptionRegisters(writer, VicrabCrashField_Exception, machineContext);
        }
    }
    writer->endContainer(writer);
}

/** Write any notable addresses contained in the CPU registers.
 *
 * @param writer The writer.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeNotableRegisters(const VicrabCrashReportWriter* const writer,
                                  const struct VicrabCrashMachineContext* const machineContext)
{
    char registerNameBuff[30];
    const char* registerName;
    const int numRegisters = vicrabcrashcpu_numRegisters();
    for(int reg = 0; reg < numRegisters; reg++)
    {
        registerName = vicrabcrashcpu_registerName(reg);
        if(registerName == NULL)
        {
            snprintf(registerNameBuff, sizeof(registerNameBuff), "r%d", reg);
            registerName = registerNameBuff;
        }
        writeMemoryContentsIfNotable(writer,
                                     registerName,
                                     (uintptr_t)vicrabcrashcpu_registerValue(machineContext, reg));
    }
}

#pragma mark Thread-specific

/** Write any notable addresses in the stack or registers to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeNotableAddresses(const VicrabCrashReportWriter* const writer,
                                  const char* const key,
                                  const struct VicrabCrashMachineContext* const machineContext)
{
    writer->beginObject(writer, key);
    {
        writeNotableRegisters(writer, machineContext);
        writeNotableStackContents(writer,
                                  machineContext,
                                  kStackNotableSearchBackDistance,
                                  kStackNotableSearchForwardDistance);
    }
    writer->endContainer(writer);
}

/** Write information about a thread to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param crash The crash handler context.
 *
 * @param machineContext The context whose thread to write about.
 *
 * @param shouldWriteNotableAddresses If true, write any notable addresses found.
 */
static void writeThread(const VicrabCrashReportWriter* const writer,
                        const char* const key,
                        const VicrabCrash_MonitorContext* const crash,
                        const struct VicrabCrashMachineContext* const machineContext,
                        const int threadIndex,
                        const bool shouldWriteNotableAddresses)
{
    bool isCrashedThread = vicrabcrashmc_isCrashedContext(machineContext);
    VicrabCrashThread thread = vicrabcrashmc_getThreadFromContext(machineContext);
    VicrabCrashLOG_DEBUG("Writing thread %x (index %d). is crashed: %d", thread, threadIndex, isCrashedThread);

    VicrabCrashStackCursor stackCursor;
    bool hasBacktrace = getStackCursor(crash, machineContext, &stackCursor);

    writer->beginObject(writer, key);
    {
        if(hasBacktrace)
        {
            writeBacktrace(writer, VicrabCrashField_Backtrace, &stackCursor);
        }
        if(vicrabcrashmc_canHaveCPUState(machineContext))
        {
            writeRegisters(writer, VicrabCrashField_Registers, machineContext);
        }
        writer->addIntegerElement(writer, VicrabCrashField_Index, threadIndex);
        const char* name = vicrabcrashccd_getThreadName(thread);
        if(name != NULL)
        {
            writer->addStringElement(writer, VicrabCrashField_Name, name);
        }
        name = vicrabcrashccd_getQueueName(thread);
        if(name != NULL)
        {
            writer->addStringElement(writer, VicrabCrashField_DispatchQueue, name);
        }
        writer->addBooleanElement(writer, VicrabCrashField_Crashed, isCrashedThread);
        writer->addBooleanElement(writer, VicrabCrashField_CurrentThread, thread == vicrabcrashthread_self());
        if(isCrashedThread)
        {
            writeStackContents(writer, VicrabCrashField_Stack, machineContext, stackCursor.state.hasGivenUp);
            if(shouldWriteNotableAddresses)
            {
                writeNotableAddresses(writer, VicrabCrashField_NotableAddresses, machineContext);
            }
        }
    }
    writer->endContainer(writer);
}

/** Write information about all threads to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param crash The crash handler context.
 */
static void writeAllThreads(const VicrabCrashReportWriter* const writer,
                            const char* const key,
                            const VicrabCrash_MonitorContext* const crash,
                            bool writeNotableAddresses)
{
    const struct VicrabCrashMachineContext* const context = crash->offendingMachineContext;
    VicrabCrashThread offendingThread = vicrabcrashmc_getThreadFromContext(context);
    int threadCount = vicrabcrashmc_getThreadCount(context);
    VicrabCrashMC_NEW_CONTEXT(machineContext);

    // Fetch info for all threads.
    writer->beginArray(writer, key);
    {
        VicrabCrashLOG_DEBUG("Writing %d threads.", threadCount);
        for(int i = 0; i < threadCount; i++)
        {
            VicrabCrashThread thread = vicrabcrashmc_getThreadAtIndex(context, i);
            if(thread == offendingThread)
            {
                writeThread(writer, NULL, crash, context, i, writeNotableAddresses);
            }
            else
            {
                vicrabcrashmc_getContextForThread(thread, machineContext, false);
                writeThread(writer, NULL, crash, machineContext, i, writeNotableAddresses);
            }
        }
    }
    writer->endContainer(writer);
}

#pragma mark Global Report Data

/** Write information about a binary image to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param index Which image to write about.
 */
static void writeBinaryImage(const VicrabCrashReportWriter* const writer,
                             const char* const key,
                             const int index)
{
    VicrabCrashBinaryImage image = {0};
    if(!vicrabcrashdl_getBinaryImage(index, &image))
    {
        return;
    }

    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, VicrabCrashField_ImageAddress, image.address);
        writer->addUIntegerElement(writer, VicrabCrashField_ImageVmAddress, image.vmAddress);
        writer->addUIntegerElement(writer, VicrabCrashField_ImageSize, image.size);
        writer->addStringElement(writer, VicrabCrashField_Name, image.name);
        writer->addUUIDElement(writer, VicrabCrashField_UUID, image.uuid);
        writer->addIntegerElement(writer, VicrabCrashField_CPUType, image.cpuType);
        writer->addIntegerElement(writer, VicrabCrashField_CPUSubType, image.cpuSubType);
        writer->addUIntegerElement(writer, VicrabCrashField_ImageMajorVersion, image.majorVersion);
        writer->addUIntegerElement(writer, VicrabCrashField_ImageMinorVersion, image.minorVersion);
        writer->addUIntegerElement(writer, VicrabCrashField_ImageRevisionVersion, image.revisionVersion);
    }
    writer->endContainer(writer);
}

/** Write information about all images to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
static void writeBinaryImages(const VicrabCrashReportWriter* const writer, const char* const key)
{
    const int imageCount = vicrabcrashdl_imageCount();

    writer->beginArray(writer, key);
    {
        for(int iImg = 0; iImg < imageCount; iImg++)
        {
            writeBinaryImage(writer, NULL, iImg);
        }
    }
    writer->endContainer(writer);
}

/** Write information about system memory to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
static void writeMemoryInfo(const VicrabCrashReportWriter* const writer,
                            const char* const key,
                            const VicrabCrash_MonitorContext* const monitorContext)
{
    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, VicrabCrashField_Size, monitorContext->System.memorySize);
        writer->addUIntegerElement(writer, VicrabCrashField_Usable, monitorContext->System.usableMemory);
        writer->addUIntegerElement(writer, VicrabCrashField_Free, monitorContext->System.freeMemory);
    }
    writer->endContainer(writer);
}

/** Write information about the error leading to the crash to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param crash The crash handler context.
 */
static void writeError(const VicrabCrashReportWriter* const writer,
                       const char* const key,
                       const VicrabCrash_MonitorContext* const crash)
{
    writer->beginObject(writer, key);
    {
#if VicrabCrashCRASH_HOST_APPLE
        writer->beginObject(writer, VicrabCrashField_Mach);
        {
            const char* machExceptionName = vicrabcrashmach_exceptionName(crash->mach.type);
            const char* machCodeName = crash->mach.code == 0 ? NULL : vicrabcrashmach_kernelReturnCodeName(crash->mach.code);
            writer->addUIntegerElement(writer, VicrabCrashField_Exception, (unsigned)crash->mach.type);
            if(machExceptionName != NULL)
            {
                writer->addStringElement(writer, VicrabCrashField_ExceptionName, machExceptionName);
            }
            writer->addUIntegerElement(writer, VicrabCrashField_Code, (unsigned)crash->mach.code);
            if(machCodeName != NULL)
            {
                writer->addStringElement(writer, VicrabCrashField_CodeName, machCodeName);
            }
            writer->addUIntegerElement(writer, VicrabCrashField_Subcode, (unsigned)crash->mach.subcode);
        }
        writer->endContainer(writer);
#endif
        writer->beginObject(writer, VicrabCrashField_Signal);
        {
            const char* sigName = vicrabcrashsignal_signalName(crash->signal.signum);
            const char* sigCodeName = vicrabcrashsignal_signalCodeName(crash->signal.signum, crash->signal.sigcode);
            writer->addUIntegerElement(writer, VicrabCrashField_Signal, (unsigned)crash->signal.signum);
            if(sigName != NULL)
            {
                writer->addStringElement(writer, VicrabCrashField_Name, sigName);
            }
            writer->addUIntegerElement(writer, VicrabCrashField_Code, (unsigned)crash->signal.sigcode);
            if(sigCodeName != NULL)
            {
                writer->addStringElement(writer, VicrabCrashField_CodeName, sigCodeName);
            }
        }
        writer->endContainer(writer);

        writer->addUIntegerElement(writer, VicrabCrashField_Address, crash->faultAddress);
        if(crash->crashReason != NULL)
        {
            writer->addStringElement(writer, VicrabCrashField_Reason, crash->crashReason);
        }

        // Gather specific info.
        switch(crash->crashType)
        {
            case VicrabCrashMonitorTypeMainThreadDeadlock:
                writer->addStringElement(writer, VicrabCrashField_Type, VicrabCrashExcType_Deadlock);
                break;

            case VicrabCrashMonitorTypeMachException:
                writer->addStringElement(writer, VicrabCrashField_Type, VicrabCrashExcType_Mach);
                break;

            case VicrabCrashMonitorTypeCPPException:
            {
                writer->addStringElement(writer, VicrabCrashField_Type, VicrabCrashExcType_CPPException);
                writer->beginObject(writer, VicrabCrashField_CPPException);
                {
                    writer->addStringElement(writer, VicrabCrashField_Name, crash->CPPException.name);
                }
                writer->endContainer(writer);
                break;
            }
            case VicrabCrashMonitorTypeNSException:
            {
                writer->addStringElement(writer, VicrabCrashField_Type, VicrabCrashExcType_NSException);
                writer->beginObject(writer, VicrabCrashField_NSException);
                {
                    writer->addStringElement(writer, VicrabCrashField_Name, crash->NSException.name);
                    writer->addStringElement(writer, VicrabCrashField_UserInfo, crash->NSException.userInfo);
                    writeAddressReferencedByString(writer, VicrabCrashField_ReferencedObject, crash->crashReason);
                }
                writer->endContainer(writer);
                break;
            }
            case VicrabCrashMonitorTypeSignal:
                writer->addStringElement(writer, VicrabCrashField_Type, VicrabCrashExcType_Signal);
                break;

            case VicrabCrashMonitorTypeUserReported:
            {
                writer->addStringElement(writer, VicrabCrashField_Type, VicrabCrashExcType_User);
                writer->beginObject(writer, VicrabCrashField_UserReported);
                {
                    writer->addStringElement(writer, VicrabCrashField_Name, crash->userException.name);
                    if(crash->userException.language != NULL)
                    {
                        writer->addStringElement(writer, VicrabCrashField_Language, crash->userException.language);
                    }
                    if(crash->userException.lineOfCode != NULL)
                    {
                        writer->addStringElement(writer, VicrabCrashField_LineOfCode, crash->userException.lineOfCode);
                    }
                    if(crash->userException.customStackTrace != NULL)
                    {
                        writer->addJSONElement(writer, VicrabCrashField_Backtrace, crash->userException.customStackTrace, true);
                    }
                }
                writer->endContainer(writer);
                break;
            }
            case VicrabCrashMonitorTypeSystem:
            case VicrabCrashMonitorTypeApplicationState:
            case VicrabCrashMonitorTypeZombie:
                VicrabCrashLOG_ERROR("Crash monitor type 0x%x shouldn't be able to cause events!", crash->crashType);
                break;
        }
    }
    writer->endContainer(writer);
}

/** Write information about app runtime, etc to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param monitorContext The event monitor context.
 */
static void writeAppStats(const VicrabCrashReportWriter* const writer,
                          const char* const key,
                          const VicrabCrash_MonitorContext* const monitorContext)
{
    writer->beginObject(writer, key);
    {
        writer->addBooleanElement(writer, VicrabCrashField_AppActive, monitorContext->AppState.applicationIsActive);
        writer->addBooleanElement(writer, VicrabCrashField_AppInFG, monitorContext->AppState.applicationIsInForeground);

        writer->addIntegerElement(writer, VicrabCrashField_LaunchesSinceCrash, monitorContext->AppState.launchesSinceLastCrash);
        writer->addIntegerElement(writer, VicrabCrashField_SessionsSinceCrash, monitorContext->AppState.sessionsSinceLastCrash);
        writer->addFloatingPointElement(writer, VicrabCrashField_ActiveTimeSinceCrash, monitorContext->AppState.activeDurationSinceLastCrash);
        writer->addFloatingPointElement(writer, VicrabCrashField_BGTimeSinceCrash, monitorContext->AppState.backgroundDurationSinceLastCrash);

        writer->addIntegerElement(writer, VicrabCrashField_SessionsSinceLaunch, monitorContext->AppState.sessionsSinceLaunch);
        writer->addFloatingPointElement(writer, VicrabCrashField_ActiveTimeSinceLaunch, monitorContext->AppState.activeDurationSinceLaunch);
        writer->addFloatingPointElement(writer, VicrabCrashField_BGTimeSinceLaunch, monitorContext->AppState.backgroundDurationSinceLaunch);
    }
    writer->endContainer(writer);
}

/** Write information about this process.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
static void writeProcessState(const VicrabCrashReportWriter* const writer,
                              const char* const key,
                              const VicrabCrash_MonitorContext* const monitorContext)
{
    writer->beginObject(writer, key);
    {
        if(monitorContext->ZombieException.address != 0)
        {
            writer->beginObject(writer, VicrabCrashField_LastDeallocedNSException);
            {
                writer->addUIntegerElement(writer, VicrabCrashField_Address, monitorContext->ZombieException.address);
                writer->addStringElement(writer, VicrabCrashField_Name, monitorContext->ZombieException.name);
                writer->addStringElement(writer, VicrabCrashField_Reason, monitorContext->ZombieException.reason);
                writeAddressReferencedByString(writer, VicrabCrashField_ReferencedObject, monitorContext->ZombieException.reason);
            }
            writer->endContainer(writer);
        }
    }
    writer->endContainer(writer);
}

/** Write basic report information.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param type The report type.
 *
 * @param reportID The report ID.
 */
static void writeReportInfo(const VicrabCrashReportWriter* const writer,
                            const char* const key,
                            const char* const type,
                            const char* const reportID,
                            const char* const processName)
{
    writer->beginObject(writer, key);
    {
        writer->addStringElement(writer, VicrabCrashField_Version, VicrabCrashCRASH_REPORT_VERSION);
        writer->addStringElement(writer, VicrabCrashField_ID, reportID);
        writer->addStringElement(writer, VicrabCrashField_ProcessName, processName);
        writer->addIntegerElement(writer, VicrabCrashField_Timestamp, time(NULL));
        writer->addStringElement(writer, VicrabCrashField_Type, type);
    }
    writer->endContainer(writer);
}

static void writeRecrash(const VicrabCrashReportWriter* const writer,
                         const char* const key,
                         const char* crashReportPath)
{
    writer->addJSONFileElement(writer, key, crashReportPath, true);
}


#pragma mark Setup

/** Prepare a report writer for use.
 *
 * @oaram writer The writer to prepare.
 *
 * @param context JSON writer contextual information.
 */
static void prepareReportWriter(VicrabCrashReportWriter* const writer, VicrabCrashJSONEncodeContext* const context)
{
    writer->addBooleanElement = addBooleanElement;
    writer->addFloatingPointElement = addFloatingPointElement;
    writer->addIntegerElement = addIntegerElement;
    writer->addUIntegerElement = addUIntegerElement;
    writer->addStringElement = addStringElement;
    writer->addTextFileElement = addTextFileElement;
    writer->addTextFileLinesElement = addTextLinesFromFile;
    writer->addJSONFileElement = addJSONElementFromFile;
    writer->addDataElement = addDataElement;
    writer->beginDataElement = beginDataElement;
    writer->appendDataElement = appendDataElement;
    writer->endDataElement = endDataElement;
    writer->addUUIDElement = addUUIDElement;
    writer->addJSONElement = addJSONElement;
    writer->beginObject = beginObject;
    writer->beginArray = beginArray;
    writer->endContainer = endContainer;
    writer->context = context;
}


// ============================================================================
#pragma mark - Main API -
// ============================================================================

void vicrabcrashreport_writeRecrashReport(const VicrabCrash_MonitorContext* const monitorContext, const char* const path)
{
    char writeBuffer[1024];
    VicrabCrashBufferedWriter bufferedWriter;
    static char tempPath[VicrabCrashFU_MAX_PATH_LENGTH];
    strncpy(tempPath, path, sizeof(tempPath) - 10);
    strncpy(tempPath + strlen(tempPath) - 5, ".old", 5);
    VicrabCrashLOG_INFO("Writing recrash report to %s", path);

    if(rename(path, tempPath) < 0)
    {
        VicrabCrashLOG_ERROR("Could not rename %s to %s: %s", path, tempPath, strerror(errno));
    }
    if(!vicrabcrashfu_openBufferedWriter(&bufferedWriter, path, writeBuffer, sizeof(writeBuffer)))
    {
        return;
    }

    vicrabcrashccd_freeze();

    VicrabCrashJSONEncodeContext jsonContext;
    jsonContext.userData = &bufferedWriter;
    VicrabCrashReportWriter concreteWriter;
    VicrabCrashReportWriter* writer = &concreteWriter;
    prepareReportWriter(writer, &jsonContext);

    vicrabcrashjson_beginEncode(getJsonContext(writer), true, addJSONData, &bufferedWriter);

    writer->beginObject(writer, VicrabCrashField_Report);
    {
        writeRecrash(writer, VicrabCrashField_RecrashReport, tempPath);
        vicrabcrashfu_flushBufferedWriter(&bufferedWriter);
        if(remove(tempPath) < 0)
        {
            VicrabCrashLOG_ERROR("Could not remove %s: %s", tempPath, strerror(errno));
        }
        writeReportInfo(writer,
                        VicrabCrashField_Report,
                        VicrabCrashReportType_Minimal,
                        monitorContext->eventID,
                        monitorContext->System.processName);
        vicrabcrashfu_flushBufferedWriter(&bufferedWriter);

        writer->beginObject(writer, VicrabCrashField_Crash);
        {
            writeError(writer, VicrabCrashField_Error, monitorContext);
            vicrabcrashfu_flushBufferedWriter(&bufferedWriter);
            int threadIndex = vicrabcrashmc_indexOfThread(monitorContext->offendingMachineContext,
                                                 vicrabcrashmc_getThreadFromContext(monitorContext->offendingMachineContext));
            writeThread(writer,
                        VicrabCrashField_CrashedThread,
                        monitorContext,
                        monitorContext->offendingMachineContext,
                        threadIndex,
                        false);
            vicrabcrashfu_flushBufferedWriter(&bufferedWriter);
        }
        writer->endContainer(writer);
    }
    writer->endContainer(writer);

    vicrabcrashjson_endEncode(getJsonContext(writer));
    vicrabcrashfu_closeBufferedWriter(&bufferedWriter);
    vicrabcrashccd_unfreeze();
}

static void writeSystemInfo(const VicrabCrashReportWriter* const writer,
                            const char* const key,
                            const VicrabCrash_MonitorContext* const monitorContext)
{
    writer->beginObject(writer, key);
    {
        writer->addStringElement(writer, VicrabCrashField_SystemName, monitorContext->System.systemName);
        writer->addStringElement(writer, VicrabCrashField_SystemVersion, monitorContext->System.systemVersion);
        writer->addStringElement(writer, VicrabCrashField_Machine, monitorContext->System.machine);
        writer->addStringElement(writer, VicrabCrashField_Model, monitorContext->System.model);
        writer->addStringElement(writer, VicrabCrashField_KernelVersion, monitorContext->System.kernelVersion);
        writer->addStringElement(writer, VicrabCrashField_OSVersion, monitorContext->System.osVersion);
        writer->addBooleanElement(writer, VicrabCrashField_Jailbroken, monitorContext->System.isJailbroken);
        writer->addStringElement(writer, VicrabCrashField_BootTime, monitorContext->System.bootTime);
        writer->addStringElement(writer, VicrabCrashField_AppStartTime, monitorContext->System.appStartTime);
        writer->addStringElement(writer, VicrabCrashField_ExecutablePath, monitorContext->System.executablePath);
        writer->addStringElement(writer, VicrabCrashField_Executable, monitorContext->System.executableName);
        writer->addStringElement(writer, VicrabCrashField_BundleID, monitorContext->System.bundleID);
        writer->addStringElement(writer, VicrabCrashField_BundleName, monitorContext->System.bundleName);
        writer->addStringElement(writer, VicrabCrashField_BundleVersion, monitorContext->System.bundleVersion);
        writer->addStringElement(writer, VicrabCrashField_BundleShortVersion, monitorContext->System.bundleShortVersion);
        writer->addStringElement(writer, VicrabCrashField_AppUUID, monitorContext->System.appID);
        writer->addStringElement(writer, VicrabCrashField_CPUArch, monitorContext->System.cpuArchitecture);
        writer->addIntegerElement(writer, VicrabCrashField_CPUType, monitorContext->System.cpuType);
        writer->addIntegerElement(writer, VicrabCrashField_CPUSubType, monitorContext->System.cpuSubType);
        writer->addIntegerElement(writer, VicrabCrashField_BinaryCPUType, monitorContext->System.binaryCPUType);
        writer->addIntegerElement(writer, VicrabCrashField_BinaryCPUSubType, monitorContext->System.binaryCPUSubType);
        writer->addStringElement(writer, VicrabCrashField_TimeZone, monitorContext->System.timezone);
        writer->addStringElement(writer, VicrabCrashField_ProcessName, monitorContext->System.processName);
        writer->addIntegerElement(writer, VicrabCrashField_ProcessID, monitorContext->System.processID);
        writer->addIntegerElement(writer, VicrabCrashField_ParentProcessID, monitorContext->System.parentProcessID);
        writer->addStringElement(writer, VicrabCrashField_DeviceAppHash, monitorContext->System.deviceAppHash);
        writer->addStringElement(writer, VicrabCrashField_BuildType, monitorContext->System.buildType);
        writer->addIntegerElement(writer, VicrabCrashField_Storage, (int64_t)monitorContext->System.storageSize);

        writeMemoryInfo(writer, VicrabCrashField_Memory, monitorContext);
        writeAppStats(writer, VicrabCrashField_AppStats, monitorContext);
    }
    writer->endContainer(writer);

}

static void writeDebugInfo(const VicrabCrashReportWriter* const writer,
                            const char* const key,
                            const VicrabCrash_MonitorContext* const monitorContext)
{
    writer->beginObject(writer, key);
    {
        if(monitorContext->consoleLogPath != NULL)
        {
            addTextLinesFromFile(writer, VicrabCrashField_ConsoleLog, monitorContext->consoleLogPath);
        }
    }
    writer->endContainer(writer);

}

void vicrabcrashreport_writeStandardReport(const VicrabCrash_MonitorContext* const monitorContext, const char* const path)
{
    VicrabCrashLOG_INFO("Writing crash report to %s", path);
    char writeBuffer[1024];
    VicrabCrashBufferedWriter bufferedWriter;

    if(!vicrabcrashfu_openBufferedWriter(&bufferedWriter, path, writeBuffer, sizeof(writeBuffer)))
    {
        return;
    }

    vicrabcrashccd_freeze();

    VicrabCrashJSONEncodeContext jsonContext;
    jsonContext.userData = &bufferedWriter;
    VicrabCrashReportWriter concreteWriter;
    VicrabCrashReportWriter* writer = &concreteWriter;
    prepareReportWriter(writer, &jsonContext);

    vicrabcrashjson_beginEncode(getJsonContext(writer), true, addJSONData, &bufferedWriter);

    writer->beginObject(writer, VicrabCrashField_Report);
    {
        writeReportInfo(writer,
                        VicrabCrashField_Report,
                        VicrabCrashReportType_Standard,
                        monitorContext->eventID,
                        monitorContext->System.processName);
        vicrabcrashfu_flushBufferedWriter(&bufferedWriter);

        writeBinaryImages(writer, VicrabCrashField_BinaryImages);
        vicrabcrashfu_flushBufferedWriter(&bufferedWriter);

        writeProcessState(writer, VicrabCrashField_ProcessState, monitorContext);
        vicrabcrashfu_flushBufferedWriter(&bufferedWriter);

        writeSystemInfo(writer, VicrabCrashField_System, monitorContext);
        vicrabcrashfu_flushBufferedWriter(&bufferedWriter);

        writer->beginObject(writer, VicrabCrashField_Crash);
        {
            writeError(writer, VicrabCrashField_Error, monitorContext);
            vicrabcrashfu_flushBufferedWriter(&bufferedWriter);
            writeAllThreads(writer,
                            VicrabCrashField_Threads,
                            monitorContext,
                            g_introspectionRules.enabled);
            vicrabcrashfu_flushBufferedWriter(&bufferedWriter);
        }
        writer->endContainer(writer);

        if(g_userInfoJSON != NULL)
        {
            addJSONElement(writer, VicrabCrashField_User, g_userInfoJSON, false);
            vicrabcrashfu_flushBufferedWriter(&bufferedWriter);
        }
        else
        {
            writer->beginObject(writer, VicrabCrashField_User);
        }
        if(g_userSectionWriteCallback != NULL)
        {
            vicrabcrashfu_flushBufferedWriter(&bufferedWriter);
            if (monitorContext->currentSnapshotUserReported == false) {
                g_userSectionWriteCallback(writer);
            }
        }
        writer->endContainer(writer);
        vicrabcrashfu_flushBufferedWriter(&bufferedWriter);

        writeDebugInfo(writer, VicrabCrashField_Debug, monitorContext);
    }
    writer->endContainer(writer);

    vicrabcrashjson_endEncode(getJsonContext(writer));
    vicrabcrashfu_closeBufferedWriter(&bufferedWriter);
    vicrabcrashccd_unfreeze();
}



void vicrabcrashreport_setUserInfoJSON(const char* const userInfoJSON)
{
    static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
    VicrabCrashLOG_TRACE("set userInfoJSON to %p", userInfoJSON);

    pthread_mutex_lock(&mutex);
    if(g_userInfoJSON != NULL)
    {
        free((void*)g_userInfoJSON);
    }
    if(userInfoJSON == NULL)
    {
        g_userInfoJSON = NULL;
    }
    else
    {
        g_userInfoJSON = strdup(userInfoJSON);
    }
    pthread_mutex_unlock(&mutex);
}

void vicrabcrashreport_setIntrospectMemory(bool shouldIntrospectMemory)
{
    g_introspectionRules.enabled = shouldIntrospectMemory;
}

void vicrabcrashreport_setDoNotIntrospectClasses(const char** doNotIntrospectClasses, int length)
{
    const char** oldClasses = g_introspectionRules.restrictedClasses;
    int oldClassesLength = g_introspectionRules.restrictedClassesCount;
    const char** newClasses = NULL;
    int newClassesLength = 0;

    if(doNotIntrospectClasses != NULL && length > 0)
    {
        newClassesLength = length;
        newClasses = malloc(sizeof(*newClasses) * (unsigned)newClassesLength);
        if(newClasses == NULL)
        {
            VicrabCrashLOG_ERROR("Could not allocate memory");
            return;
        }

        for(int i = 0; i < newClassesLength; i++)
        {
            newClasses[i] = strdup(doNotIntrospectClasses[i]);
        }
    }

    g_introspectionRules.restrictedClasses = newClasses;
    g_introspectionRules.restrictedClassesCount = newClassesLength;

    if(oldClasses != NULL)
    {
        for(int i = 0; i < oldClassesLength; i++)
        {
            free((void*)oldClasses[i]);
        }
        free(oldClasses);
    }
}

void vicrabcrashreport_setUserSectionWriteCallback(const VicrabCrashReportWriteCallback userSectionWriteCallback)
{
    VicrabCrashLOG_TRACE("Set userSectionWriteCallback to %p", userSectionWriteCallback);
    g_userSectionWriteCallback = userSectionWriteCallback;
}
