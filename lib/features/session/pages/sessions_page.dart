import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/audio/audio_director.dart';
import 'package:quiz_show/features/audio/audioplayers_backend.dart';
import 'package:quiz_show/features/buzzers/buzzers_page.dart';
import 'package:quiz_show/features/buzzers/serial_buzzers.dart';
import 'package:quiz_show/game/game.dart';
import 'dart:async';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/player/pages/join_session_page.dart';
import 'package:quiz_show/features/session/pages/connect_devices_page.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/features/session/session_repository.dart';

/// The shows the user hosts: start a new one, or present or control one.
class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  late final Stream<List<SessionSummary>> _sessions = SessionRepository.instance.watchMySessions();

  SessionRepository get _repo => SessionRepository.instance;

  Future<void> _create() async {
    final name = await promptText(context, title: "New session", label: "Name", initial: "Quiz night");
    if (name == null || !mounted) return;
    await guarded(context, () => _repo.createSession(name: name), failure: "Could not create the session.");
  }

  Future<void> _present(SessionSummary session) async {
    final deviceId = await _repo.deviceId();
    if (!mounted) return;
    if (session.hostDevice != null && session.hostDevice != deviceId) {
      final sure = await confirm(
        context,
        title: "Present here",
        message: "Another of your devices was presenting this session last. It stops if it is still running.",
        action: "Present here",
      );
      if (!sure || !mounted) return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PresentPage(sessionId: session.id)));
  }

  void _control(SessionSummary session) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ControlPage(sessionId: session.id, title: session.name)));
  }

  Future<void> _delete(SessionSummary session) async {
    final sure = await confirm(
      context,
      title: "Delete session",
      message: "\"${session.name}\" with its teams and points will be deleted.",
      action: "Delete",
    );
    if (!sure || !mounted) return;
    await guarded(context, () => _repo.deleteSession(session.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'joinSession',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinSessionPage())),
            tooltip: "Join a session with a code",
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'createSession',
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text("New session"),
          ),
        ],
      ),
      body: StreamBuilder<List<SessionSummary>>(
        stream: _sessions,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Could not load your sessions."));
          final sessions = snapshot.data;
          if (sessions == null) return const Center(child: CupertinoActivityIndicator());
          if (sessions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "A session is one evening's show: its teams, points and progress. "
                  "Create one, present it on the big screen and control it from your phone.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final session in sessions)
                ListTile(
                  leading: const Icon(Icons.live_tv_outlined),
                  title: Text(session.name.isEmpty ? "Unnamed" : session.name),
                  subtitle: Text(session.gameId == null ? "No game picked yet" : "Tap to control"),
                  onTap: () => _control(session),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _present(session),
                        icon: const Icon(Icons.tv),
                        label: const Text("Present"),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: "Delete",
                        onPressed: () => _delete(session),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Controls a session that another device presents.
class ControlPage extends StatefulWidget {
  const ControlPage({super.key, required this.sessionId, required this.title, this.asMember = false});

  final String sessionId;
  final String title;

  /// Joined with a code rather than hosting: no join codes to hand out.
  final bool asMember;

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  late final SessionConnection _connection = SessionConnection.control(
    widget.sessionId,
    onSendError: (_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text("That did not reach the presenter.")));
    },
  );
  late final Stream<SessionSummary?> _session = SessionRepository.instance.watchSession(widget.sessionId);

  @override
  void dispose() {
    _connection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          // Commands only take effect on the presenting device.
          StreamBuilder<SessionSummary?>(
            stream: _session,
            builder: (context, snapshot) => snapshot.hasData && snapshot.data!.hostDevice == null
                ? MaterialBanner(
                    content: const Text("No device is presenting this session yet. Nothing happens until one does."),
                    leading: const Icon(Icons.tv_off),
                    actions: const [SizedBox()],
                  )
                : const SizedBox(),
          ),
          Expanded(
            child: ControllerView(
              connection: _connection,
              onConnectDevices: widget.asMember ? null : () => openConnectDevices(context, _connection),
            ),
          ),
        ],
      ),
    );
  }
}

void openConnectDevices(BuildContext context, SessionConnection connection) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ConnectDevicesPage(
      sessionId: connection.sessionId,
      teams: connection.state.value?.teams ?? const [],
    ),
  ));
}

/// Makes this device the presenter: it runs the show and displays it.
class PresentPage extends StatefulWidget {
  const PresentPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<PresentPage> createState() => _PresentPageState();
}

class _PresentPageState extends State<PresentPage> {
  SessionConnection? _connection;
  AudioDirector? _audio;
  StreamSubscription<int>? _buzzers;
  Object? _error;
  bool _fullscreen = false;

  bool get _canFullscreen => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    SessionConnection.present(widget.sessionId).then((connection) {
      if (!mounted) {
        connection.dispose();
        return;
      }
      connection.displaced!.addListener(_onDisplaced);
      // Sound comes out of the presenting device only.
      final audio = AudioDirector(
        host: connection.host!,
        backend: AudioplayersBackend(),
        resolve: (gameId, name) {
          final file = MediaService.instance.localFile(gameId, name);
          return file.existsSync() ? file.path : null;
        },
      );
      // Files still downloading when a sound was asked for start once they are in.
      connection.missingMedia.addListener(audio.sync);
      // The buzzer box is plugged into this device, so its presses go
      // straight into the host: no network in between.
      SerialBuzzers.instance.start();
      _buzzers = SerialBuzzers.instance.pressed.listen((id) {
        final team = connection.host!.state.teams.elementAtOrNull(SerialBuzzers.instance.teamIndexOf(id));
        if (team != null) connection.host!.dispatch(Buzz(team.id));
      });
      setState(() {
        _connection = connection;
        _audio = audio;
      });
    }, onError: (Object error) {
      if (mounted) setState(() => _error = error);
    });
  }

  void _onDisplaced() {
    if (!mounted || _connection?.displaced?.value != true) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Presenting elsewhere"),
        content: const Text("Another of your devices took over this session."),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context)
              ..pop()
              ..pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _connection?.displaced?.removeListener(_onDisplaced);
    _buzzers?.cancel();
    SerialBuzzers.instance.stop();
    final audio = _audio;
    if (audio != null) _connection?.missingMedia.removeListener(audio.sync);
    audio?.dispose();
    _connection?.dispose();
    if (_fullscreen) windowManager.setFullScreen(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = _connection;
    if (_error != null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text("Could not start presenting this session.")));
    }
    if (connection == null) return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    final faint = Theme.of(context).colorScheme.outlineVariant;
    return Scaffold(
      endDrawer: Drawer(
        width: 460,
        child: SafeArea(
          child: ControllerView(
            connection: connection,
            onConnectDevices: () => openConnectDevices(context, connection),
            onBuzzerSetup: SerialBuzzers.supported
                ? () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BuzzersPage(teams: connection.state.value?.teams ?? const []),
                    ))
                : null,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: PresenterView(connection: connection)),
          // Kept faint: the audience is looking at this screen.
          Positioned(
            top: 4,
            right: 4,
            child: Builder(
              builder: (context) => Column(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: faint),
                    tooltip: "Stop presenting",
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  if (_canFullscreen)
                    IconButton(
                      icon: Icon(_fullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: faint),
                      tooltip: "Fullscreen",
                      onPressed: () {
                        setState(() => _fullscreen = !_fullscreen);
                        windowManager.setFullScreen(_fullscreen);
                      },
                    ),
                  IconButton(
                    icon: Icon(Icons.tune, color: faint),
                    tooltip: "Controls",
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: connection.missingMedia,
              builder: (context, missing, _) => missing.isEmpty
                  ? const SizedBox()
                  : Chip(
                      avatar: const Icon(Icons.cloud_off, size: 18),
                      label: Text("${missing.length} media files could not be downloaded"),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
