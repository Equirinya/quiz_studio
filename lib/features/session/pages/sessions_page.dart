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
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/player/pages/join_session_page.dart';
import 'package:quiz_show/features/player/pages/player_page.dart' show LinkStatusIcon;
import 'package:quiz_show/features/session/session_client.dart';
import 'package:quiz_show/features/session/session_links.dart';
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
  late final Stream<List<GameSummary>> _games = GameRepository.instance.watchMyGames().asBroadcastStream();
  List<GameSummary> _playable = const [];
  StreamSubscription<List<GameSummary>>? _gamesSub;

  SessionRepository get _repo => SessionRepository.instance;

  @override
  void initState() {
    super.initState();
    // A session can only play games its host may read in full.
    _gamesSub = _games.listen((games) {
      if (mounted) setState(() => _playable = games.where((g) => g.role.seesEverything).toList());
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _gamesSub?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    final result = await showNewSessionSheet(context, games: _playable);
    if (result == null || !mounted) return;
    await guarded(
      context,
      () => _repo.createSession(name: result.name, gameId: result.gameId),
      failure: "Could not create the session.",
    );
  }

  Future<void> _changeGame(SessionSummary session) async {
    final gameId = await showGamePicker(context, games: _playable, selected: session.gameId);
    if (gameId == null || gameId == session.gameId || !mounted) return;
    await guarded(context, () => _repo.setGame(session.id, gameId));
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
          return SessionsList(
            sessions: sessions,
            gameNames: {for (final game in _playable) game.id: game.name},
            onControl: _control,
            onPresent: _present,
            onChangeGame: _changeGame,
            onDelete: _delete,
          );
        },
      ),
    );
  }
}

/// The session cards. Takes plain data so it can be shown without a backend.
class SessionsList extends StatelessWidget {
  const SessionsList({
    super.key,
    required this.sessions,
    required this.gameNames,
    required this.onControl,
    required this.onPresent,
    required this.onChangeGame,
    required this.onDelete,
  });

  final List<SessionSummary> sessions;
  final Map<String, String> gameNames;
  final ValueChanged<SessionSummary> onControl;
  final ValueChanged<SessionSummary> onPresent;
  final ValueChanged<SessionSummary> onChangeGame;
  final ValueChanged<SessionSummary> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 140),
      children: [
        for (final session in sessions)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(session.name.isEmpty ? "Unnamed" : session.name, style: theme.textTheme.titleMedium),
                      ),
                      PopupMenuButton<VoidCallback>(
                        onSelected: (action) => action(),
                        itemBuilder: (context) => [
                          PopupMenuItem(value: () => onChangeGame(session), child: const Text("Change game")),
                          PopupMenuItem(value: () => onDelete(session), child: const Text("Delete")),
                        ],
                      ),
                    ],
                  ),
                  // The game is part of the card, so it is picked here and
                  // not somewhere inside the running show.
                  ActionChip(
                    avatar: const Icon(Icons.quiz_outlined, size: 18),
                    label: Text(
                      session.gameId == null ? "Choose a game" : (gameNames[session.gameId] ?? "A game you cannot open"),
                    ),
                    onPressed: () => onChangeGame(session),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => onPresent(session),
                          icon: const Icon(Icons.tv),
                          label: const Text("Present"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => onControl(session),
                          icon: const Icon(Icons.tune),
                          label: const Text("Control"),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Lets the user pick one of [games]; returns its id.
Future<String?> showGamePicker(BuildContext context, {required List<GameSummary> games, String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _GameChoices(
      games: games,
      selected: selected,
      onPicked: (id) => Navigator.of(context).pop(id),
    ),
  );
}

class _GameChoices extends StatelessWidget {
  const _GameChoices({required this.games, required this.selected, required this.onPicked});

  final List<GameSummary> games;
  final String? selected;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text("You have no games yet. Create one in the Games tab first.", textAlign: TextAlign.center),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      children: [
        for (final game in games)
          ListTile(
            leading: Icon(game.id == selected ? Icons.radio_button_checked : Icons.radio_button_off),
            title: Text(game.name.isEmpty ? "Unnamed" : game.name),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onTap: () => onPicked(game.id),
          ),
      ],
    );
  }
}

/// Name and game for a new session, in one step.
Future<({String name, String? gameId})?> showNewSessionSheet(BuildContext context, {required List<GameSummary> games}) {
  return showModalBottomSheet<({String name, String? gameId})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _NewSessionSheet(games: games),
  );
}

class _NewSessionSheet extends StatefulWidget {
  const _NewSessionSheet({required this.games});

  final List<GameSummary> games;

  @override
  State<_NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends State<_NewSessionSheet> {
  final TextEditingController _name = TextEditingController(text: "Quiz night");
  late String? _gameId = widget.games.length == 1 ? widget.games.first.id : null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("New session", style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: "Name")),
          const SizedBox(height: 16),
          Text("Game", style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.35),
            child: _GameChoices(games: widget.games, selected: _gameId, onPicked: (id) => setState(() => _gameId = id)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () {
                final name = _name.text.trim();
                Navigator.of(context).pop((name: name.isEmpty ? "Quiz night" : name, gameId: _gameId));
              },
              child: Text(_gameId == null ? "Create without a game" : "Create"),
            ),
          ),
        ],
      ),
    );
  }
}

/// Controls a session that another device presents.
class ControlPage extends StatefulWidget {
  const ControlPage({super.key, required this.sessionId, required this.title, this.joinLink});

  final String sessionId;
  final String title;

  /// Set when this device joined with a code rather than hosting; it has no
  /// join codes to hand out then.
  final SessionJoinLink? joinLink;

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  late final SessionConnection _connection = SessionConnection.control(
    widget.sessionId,
    joinLink: widget.joinLink,
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
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          ValueListenableBuilder<LinkStatus>(
            valueListenable: _connection.link!,
            builder: (context, status, _) => LinkStatusIcon(status),
          ),
        ],
      ),
      body: Column(
        children: [
          // Commands only take effect on the presenting device.
          StreamBuilder<SessionSummary?>(
            stream: widget.joinLink == null ? _session : null,
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
              onConnectDevices: widget.joinLink != null ? null : () => openConnectDevices(context, _connection),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> openConnectDevices(BuildContext context, SessionConnection connection) async {
  final navigator = Navigator.of(context);
  // The presenter knows its own addresses; any other device asks for them.
  final endpoints = connection.isPresenting
      ? connection.lanEndpoints.value
      : await SessionRepository.instance
          .watchLanEndpoints(connection.sessionId)
          .first
          .timeout(const Duration(seconds: 2), onTimeout: () => const <String>[])
          .catchError((Object _) => const <String>[]);
  navigator.push(MaterialPageRoute(
    builder: (_) => ConnectDevicesPage(
      sessionId: connection.sessionId,
      teams: connection.state.value?.teams ?? const [],
      lanEndpoints: endpoints,
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
