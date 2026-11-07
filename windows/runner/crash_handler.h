#ifndef RUNNER_CRASH_HANDLER_H_
#define RUNNER_CRASH_HANDLER_H_

// Writes a minidump to %LOCALAPPDATA%\QuizStudio\crashes when the process
// dies from a native crash, abort() or std::terminate. Native crashes (for
// example inside the Firebase C++ SDK) end the app without any Dart error, so
// this is the only trace they leave. Open a dump in Visual Studio or WinDbg.
void InstallCrashHandler();

#endif  // RUNNER_CRASH_HANDLER_H_
