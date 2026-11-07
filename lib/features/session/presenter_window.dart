import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'package:quiz_show/core/crash_log.dart';
import 'package:quiz_show/core/theme.dart';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_client.dart';
import 'package:quiz_show/features/session/session_connection.dart';

/// What a presenter window is started with: which session, and how to reach
/// the main window that runs it.
class PresenterWindowArgs {
  const PresenterWindowArgs({required this.sessionId, required this.endpoint, required this.token});

  static const String flag = '--presenter-window';

  final String sessionId;

  /// `127.0.0.1:port` of the main window's local network server.
  final String endpoint;
  final String token;

  List<String> toArgs() => [flag, 'session=$sessionId', 'endpoint=$endpoint', 'token=$token'];

  /// Null unless [args] start a presenter window.
  static PresenterWindowArgs? tryParse(List<String> args) {
    if (!args.contains(flag)) return null;
    String? value(String key) => args.where((a) => a.startsWith('$key=')).map((a) => a.substring(key.length + 1)).firstOrNull;
    final session = value('session');
    final endpoint = value('endpoint');
    final token = value('token');
    if (session == null || endpoint == null || token == null || session.isEmpty || token.isEmpty) return null;
    // Only ever this computer: the window has no business elsewhere.
    if (!endpoint.startsWith('127.0.0.1:')) return null;
    return PresenterWindowArgs(sessionId: session, endpoint: endpoint, token: token);
  }
}

/// A presenter window started from the main window. It is a second copy of
/// the app showing nothing but the big screen, so it can sit on the
/// projector in full screen while this window is the controller.
class PresenterWindow {
  PresenterWindow._(this._process);

  final Process _process;

  /// Computers only; phones and tablets have one screen to show.
  static bool get supported => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Completes when the window is closed, by the user or by [close].
  Future<int> get closed => _process.exitCode;

  static Future<PresenterWindow> open(PresenterWindowArgs args) async {
    // Run from an IDE, this app gets the debugger's engine switches (such as
    // start-paused) through the environment. Passed on, the window would wait
    // for a debugger that never comes and never show up.
    final environment = Map.of(Platform.environment)
      ..removeWhere((key, _) => key.toUpperCase().startsWith('FLUTTER_ENGINE_SWITCH'));
    final process = await Process.start(
      Platform.resolvedExecutable,
      args.toArgs(),
      environment: environment,
      includeParentEnvironment: false,
    );
    // Nobody reads its output, but it must not block on a full pipe.
    process.stdout.drain<void>().ignore();
    process.stderr.drain<void>().ignore();
    return PresenterWindow._(process);
  }

  void close() => _process.kill();
}

/// Entry point of a presenter window: no sign-in and no cloud, only the
/// main window over the loopback.
Future<void> runPresenterWindow(PresenterWindowArgs args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await CrashLog.init(role: "presenter");
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(title: "Quiz Studio · Presenter", size: Size(1280, 720), center: true),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  // Video cards play in this window, on the big screen.
  MediaKit.ensureInitialized();
  await MediaService.instance.init();
  runApp(
    PresenterWindowApp(
      connection: SessionConnection.window(sessionId: args.sessionId, endpoint: args.endpoint, token: args.token),
    ),
  );
}

class PresenterWindowApp extends StatelessWidget {
  const PresenterWindowApp({
    super.key,
    required this.connection,
    this.onFullscreen,
    this.onQuit,
    this.orphanAfter = PresenterWindowView.orphaned,
  });

  final SessionConnection connection;
  final Duration orphanAfter;

  /// Toggles full screen; the window manager unless a test says otherwise.
  final Future<void> Function(bool on)? onFullscreen;

  /// Ends the window; the process unless a test says otherwise.
  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(Brightness.light),
    darkTheme: buildAppTheme(Brightness.dark),
    home: PresenterWindowView(connection: connection, onFullscreen: onFullscreen, onQuit: onQuit, orphanAfter: orphanAfter),
  );
}

/// The big screen and nothing else, with a hint how to put it on the
/// projector, and a faint button for full screen.
class PresenterWindowView extends StatefulWidget {
  const PresenterWindowView({
    super.key,
    required this.connection,
    this.onFullscreen,
    this.onQuit,
    this.orphanAfter = orphaned,
  });

  final SessionConnection connection;
  final Future<void> Function(bool on)? onFullscreen;
  final VoidCallback? onQuit;

  /// How long the main window may be out of reach before this one closes,
  /// because the main window is gone.
  final Duration orphanAfter;
  static const Duration orphaned = Duration(seconds: 10);

  @override
  State<PresenterWindowView> createState() => _PresenterWindowViewState();
}

class _PresenterWindowViewState extends State<PresenterWindowView> {
  bool _fullscreen = false;
  bool _hint = true;
  Timer? _hintTimer;
  Timer? _orphanTimer;
  bool _everConnected = false;

  ValueListenable<LinkStatus>? get _link => widget.connection.link;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _hint = false);
    });
    _link?.addListener(_onLink);
    _onLink();
  }

  void _onLink() {
    // Shown without a main window to follow, as in tests: nothing to lose.
    if (_link == null) return;
    final onLan = _link!.value == LinkStatus.lan;
    if (onLan) {
      _everConnected = true;
      _orphanTimer?.cancel();
      _orphanTimer = null;
      return;
    }
    // Lost the main window: it was closed or stopped presenting.
    _orphanTimer ??= Timer(widget.orphanAfter, _quit);
  }

  void _quit() {
    if (widget.onQuit != null) {
      widget.onQuit!();
      return;
    }
    exit(0);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _orphanTimer?.cancel();
    _link?.removeListener(_onLink);
    super.dispose();
  }

  Future<void> _toggleFullscreen() async {
    final on = !_fullscreen;
    setState(() {
      _fullscreen = on;
      _hint = false;
    });
    await (widget.onFullscreen ?? windowManager.setFullScreen)(on);
  }

  @override
  Widget build(BuildContext context) {
    final faint = Theme.of(context).colorScheme.outlineVariant;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f11): _toggleFullscreen,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_fullscreen) _toggleFullscreen();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: widget.connection.state,
            builder: (context, state, _) => Stack(
              children: [
                Positioned.fill(
                  // Only the show itself: a button on top answers at once.
                  child: GestureDetector(
                    onDoubleTap: _toggleFullscreen,
                    child: state == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CupertinoActivityIndicator(),
                                const SizedBox(height: 12),
                                Text(_everConnected ? "Reconnecting to the main window…" : "Connecting to the main window…"),
                              ],
                            ),
                          )
                        : PresenterView(connection: widget.connection, videoCards: true),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: Icon(_fullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: faint),
                    tooltip: _fullscreen ? "Leave full screen (Esc)" : "Full screen (F11)",
                    onPressed: _toggleFullscreen,
                  ),
                ),
                if (_hint && !_fullscreen)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 24,
                    child: Center(
                      child: Material(
                        color: Theme.of(context).colorScheme.inverseSurface,
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Text(
                            "Drag this window to the projector, then double-click it or press F11 for full screen.",
                            style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
