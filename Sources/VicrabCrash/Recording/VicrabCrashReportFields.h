//
//  VicrabCrashReportFields.h
//
//  Created by Karl Stenerud on 2012-10-07.
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


#ifndef HDR_VicrabCrashReportFields_h
#define HDR_VicrabCrashReportFields_h


#pragma mark - Report Types -

#define VicrabCrashReportType_Minimal          "minimal"
#define VicrabCrashReportType_Standard         "standard"
#define VicrabCrashReportType_Custom           "custom"


#pragma mark - Memory Types -

#define VicrabCrashMemType_Block               "objc_block"
#define VicrabCrashMemType_Class               "objc_class"
#define VicrabCrashMemType_NullPointer         "null_pointer"
#define VicrabCrashMemType_Object              "objc_object"
#define VicrabCrashMemType_String              "string"
#define VicrabCrashMemType_Unknown             "unknown"


#pragma mark - Exception Types -

#define VicrabCrashExcType_CPPException        "cpp_exception"
#define VicrabCrashExcType_Deadlock            "deadlock"
#define VicrabCrashExcType_Mach                "mach"
#define VicrabCrashExcType_NSException         "nsexception"
#define VicrabCrashExcType_Signal              "signal"
#define VicrabCrashExcType_User                "user"


#pragma mark - Common -

#define VicrabCrashField_Address               "address"
#define VicrabCrashField_Contents              "contents"
#define VicrabCrashField_Exception             "exception"
#define VicrabCrashField_FirstObject           "first_object"
#define VicrabCrashField_Index                 "index"
#define VicrabCrashField_Ivars                 "ivars"
#define VicrabCrashField_Language              "language"
#define VicrabCrashField_Name                  "name"
#define VicrabCrashField_UserInfo              "userInfo"
#define VicrabCrashField_ReferencedObject      "referenced_object"
#define VicrabCrashField_Type                  "type"
#define VicrabCrashField_UUID                  "uuid"
#define VicrabCrashField_Value                 "value"

#define VicrabCrashField_Error                 "error"
#define VicrabCrashField_JSONData              "json_data"


#pragma mark - Notable Address -

#define VicrabCrashField_Class                 "class"
#define VicrabCrashField_LastDeallocObject     "last_deallocated_obj"


#pragma mark - Backtrace -

#define VicrabCrashField_InstructionAddr       "instruction_addr"
#define VicrabCrashField_LineOfCode            "line_of_code"
#define VicrabCrashField_ObjectAddr            "object_addr"
#define VicrabCrashField_ObjectName            "object_name"
#define VicrabCrashField_SymbolAddr            "symbol_addr"
#define VicrabCrashField_SymbolName            "symbol_name"


#pragma mark - Stack Dump -

#define VicrabCrashField_DumpEnd               "dump_end"
#define VicrabCrashField_DumpStart             "dump_start"
#define VicrabCrashField_GrowDirection         "grow_direction"
#define VicrabCrashField_Overflow              "overflow"
#define VicrabCrashField_StackPtr              "stack_pointer"


#pragma mark - Thread Dump -

#define VicrabCrashField_Backtrace             "backtrace"
#define VicrabCrashField_Basic                 "basic"
#define VicrabCrashField_Crashed               "crashed"
#define VicrabCrashField_CurrentThread         "current_thread"
#define VicrabCrashField_DispatchQueue         "dispatch_queue"
#define VicrabCrashField_NotableAddresses      "notable_addresses"
#define VicrabCrashField_Registers             "registers"
#define VicrabCrashField_Skipped               "skipped"
#define VicrabCrashField_Stack                 "stack"


#pragma mark - Binary Image -

#define VicrabCrashField_CPUSubType            "cpu_subtype"
#define VicrabCrashField_CPUType               "cpu_type"
#define VicrabCrashField_ImageAddress          "image_addr"
#define VicrabCrashField_ImageVmAddress        "image_vmaddr"
#define VicrabCrashField_ImageSize             "image_size"
#define VicrabCrashField_ImageMajorVersion     "major_version"
#define VicrabCrashField_ImageMinorVersion     "minor_version"
#define VicrabCrashField_ImageRevisionVersion  "revision_version"


#pragma mark - Memory -

#define VicrabCrashField_Free                  "free"
#define VicrabCrashField_Usable                "usable"


#pragma mark - Error -

#define VicrabCrashField_Backtrace             "backtrace"
#define VicrabCrashField_Code                  "code"
#define VicrabCrashField_CodeName              "code_name"
#define VicrabCrashField_CPPException          "cpp_exception"
#define VicrabCrashField_ExceptionName         "exception_name"
#define VicrabCrashField_Mach                  "mach"
#define VicrabCrashField_NSException           "nsexception"
#define VicrabCrashField_Reason                "reason"
#define VicrabCrashField_Signal                "signal"
#define VicrabCrashField_Subcode               "subcode"
#define VicrabCrashField_UserReported          "user_reported"


#pragma mark - Process State -

#define VicrabCrashField_LastDeallocedNSException "last_dealloced_nsexception"
#define VicrabCrashField_ProcessState             "process"


#pragma mark - App Stats -

#define VicrabCrashField_ActiveTimeSinceCrash  "active_time_since_last_crash"
#define VicrabCrashField_ActiveTimeSinceLaunch "active_time_since_launch"
#define VicrabCrashField_AppActive             "application_active"
#define VicrabCrashField_AppInFG               "application_in_foreground"
#define VicrabCrashField_BGTimeSinceCrash      "background_time_since_last_crash"
#define VicrabCrashField_BGTimeSinceLaunch     "background_time_since_launch"
#define VicrabCrashField_LaunchesSinceCrash    "launches_since_last_crash"
#define VicrabCrashField_SessionsSinceCrash    "sessions_since_last_crash"
#define VicrabCrashField_SessionsSinceLaunch   "sessions_since_launch"


#pragma mark - Report -

#define VicrabCrashField_Crash                 "crash"
#define VicrabCrashField_Debug                 "debug"
#define VicrabCrashField_Diagnosis             "diagnosis"
#define VicrabCrashField_ID                    "id"
#define VicrabCrashField_ProcessName           "process_name"
#define VicrabCrashField_Report                "report"
#define VicrabCrashField_Timestamp             "timestamp"
#define VicrabCrashField_Version               "version"

#pragma mark Minimal
#define VicrabCrashField_CrashedThread         "crashed_thread"

#pragma mark Standard
#define VicrabCrashField_AppStats              "application_stats"
#define VicrabCrashField_BinaryImages          "binary_images"
#define VicrabCrashField_System                "system"
#define VicrabCrashField_Memory                "memory"
#define VicrabCrashField_Threads               "threads"
#define VicrabCrashField_User                  "user"
#define VicrabCrashField_ConsoleLog            "console_log"

#pragma mark Incomplete
#define VicrabCrashField_Incomplete            "incomplete"
#define VicrabCrashField_RecrashReport         "recrash_report"

#pragma mark System
#define VicrabCrashField_AppStartTime          "app_start_time"
#define VicrabCrashField_AppUUID               "app_uuid"
#define VicrabCrashField_BootTime              "boot_time"
#define VicrabCrashField_BundleID              "CFBundleIdentifier"
#define VicrabCrashField_BundleName            "CFBundleName"
#define VicrabCrashField_BundleShortVersion    "CFBundleShortVersionString"
#define VicrabCrashField_BundleVersion         "CFBundleVersion"
#define VicrabCrashField_CPUArch               "cpu_arch"
#define VicrabCrashField_CPUType               "cpu_type"
#define VicrabCrashField_CPUSubType            "cpu_subtype"
#define VicrabCrashField_BinaryCPUType         "binary_cpu_type"
#define VicrabCrashField_BinaryCPUSubType      "binary_cpu_subtype"
#define VicrabCrashField_DeviceAppHash         "device_app_hash"
#define VicrabCrashField_Executable            "CFBundleExecutable"
#define VicrabCrashField_ExecutablePath        "CFBundleExecutablePath"
#define VicrabCrashField_Jailbroken            "jailbroken"
#define VicrabCrashField_KernelVersion         "kernel_version"
#define VicrabCrashField_Machine               "machine"
#define VicrabCrashField_Model                 "model"
#define VicrabCrashField_OSVersion             "os_version"
#define VicrabCrashField_ParentProcessID       "parent_process_id"
#define VicrabCrashField_ProcessID             "process_id"
#define VicrabCrashField_ProcessName           "process_name"
#define VicrabCrashField_Size                  "size"
#define VicrabCrashField_Storage               "storage"
#define VicrabCrashField_SystemName            "system_name"
#define VicrabCrashField_SystemVersion         "system_version"
#define VicrabCrashField_TimeZone              "time_zone"
#define VicrabCrashField_BuildType             "build_type"

#endif
