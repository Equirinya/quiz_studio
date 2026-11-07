import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Leaves a trace when something goes wrong, because on Windows a crash inside
/// the Firebase plugins ends the app without any error on screen.
///
/// Uncaught Dart errors and every start go to `app.log`. On Windows the runner
/// writes native crash dumps to `crashes/` in the same folder
/// (`%LOCALAPPDATA%\QuizStudio`, see windows/runner/crash_handler.cpp).
class CrashLog {
  CrashLog._();

  static const _maxLogBytes = 1024 * 1024;
  static const _keptDumps = 10;

  static Directory? _directory;
  static File? _file;

  /// Where the log (and on Windows the crash dumps) live, once [init] ran.
  static Directory? get directory => _directory;

  static Future<void> init({String role = "main"}) async {
    try {
      final localAppData = Platform.isWindows ? Platform.environment["LOCALAPPDATA"] : null;
      final directory = localAppData != null
          ? Directory("$localAppData\\QuizStudio")
          : Directory("${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}logs");
      directory.createSync(recursive: true);
      _directory = directory;

      final file = File("${directory.path}${Platform.pathSeparator}app.log");
      if (file.existsSync() && file.lengthSync() > _maxLogBytes) {
        file.renameSync("${directory.path}${Platform.pathSeparator}app.old.log");
      }
      _file = file;
      _pruneDumps(directory);
      _write("start ($role window, pid $pid)");
    } catch (error) {
      if (kDebugMode) print('Crash log: not available: $error');
    }

    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      record("Flutter error", details.exception, details.stack);
      previousFlutterHandler?.call(details);
    };
    final previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      record("Uncaught error", error, stack);
      return previousPlatformHandler?.call(error, stack) ?? false;
    };
  }

  static void record(String what, Object error, StackTrace? stack) {
    _write("$what: $error${stack == null ? "" : "\n$stack"}");
  }

  static void _write(String message) {
    final file = _file;
    if (file == null) return;
    try {
      file.writeAsStringSync("${DateTime.now().toIso8601String()} $message\n", mode: FileMode.append, flush: true);
    } catch (_) {
      // Logging must never be the thing that breaks the app.
    }
  }

  static void _pruneDumps(Directory directory) {
    final crashes = Directory("${directory.path}${Platform.pathSeparator}crashes");
    if (!crashes.existsSync()) return;
    final dumps = crashes.listSync().whereType<File>().where((f) => f.path.endsWith(".dmp")).toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final old in dumps.skip(_keptDumps)) {
      try {
        old.deleteSync();
      } catch (_) {}
    }
  }
}
