#include "crash_handler.h"

#include <windows.h>

#include <dbghelp.h>
#include <shlobj.h>

#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <string>

namespace {

wchar_t g_dump_dir[MAX_PATH] = {};
volatile LONG g_dump_written = 0;

void WriteDump(EXCEPTION_POINTERS* info) {
  // One dump per process: abort() after a crash would otherwise write twice.
  if (InterlockedExchange(&g_dump_written, 1) != 0 || g_dump_dir[0] == 0) {
    return;
  }

  SYSTEMTIME now;
  GetLocalTime(&now);
  wchar_t path[MAX_PATH];
  swprintf_s(path, L"%s\\crash-%04d%02d%02d-%02d%02d%02d-%lu.dmp", g_dump_dir,
             now.wYear, now.wMonth, now.wDay, now.wHour, now.wMinute,
             now.wSecond, GetCurrentProcessId());

  HANDLE file = CreateFileW(path, GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                            FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return;
  }

  MINIDUMP_EXCEPTION_INFORMATION exception_info = {};
  exception_info.ThreadId = GetCurrentThreadId();
  exception_info.ExceptionPointers = info;
  exception_info.ClientPointers = FALSE;

  MiniDumpWriteDump(
      GetCurrentProcess(), GetCurrentProcessId(), file,
      static_cast<MINIDUMP_TYPE>(MiniDumpWithThreadInfo |
                                 MiniDumpWithIndirectlyReferencedMemory),
      info != nullptr ? &exception_info : nullptr, nullptr, nullptr);
  CloseHandle(file);
}

LONG WINAPI OnUnhandledException(EXCEPTION_POINTERS* info) {
  WriteDump(info);
  return EXCEPTION_CONTINUE_SEARCH;
}

void OnAbort(int) { WriteDump(nullptr); }

void OnTerminate() {
  WriteDump(nullptr);
  std::abort();
}

}  // namespace

void InstallCrashHandler() {
  PWSTR local_app_data = nullptr;
  if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr,
                                     &local_app_data))) {
    std::wstring dir = std::wstring(local_app_data) + L"\\QuizStudio";
    CreateDirectoryW(dir.c_str(), nullptr);
    dir += L"\\crashes";
    CreateDirectoryW(dir.c_str(), nullptr);
    wcsncpy_s(g_dump_dir, dir.c_str(), _TRUNCATE);
    CoTaskMemFree(local_app_data);
  }

  SetUnhandledExceptionFilter(OnUnhandledException);
  signal(SIGABRT, OnAbort);
  std::set_terminate(OnTerminate);
}
