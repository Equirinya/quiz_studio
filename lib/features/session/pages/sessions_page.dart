import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/core/widgets/near_mouse.dart';
import 'package:quiz_show/features/audio/audio_director.dart';
import 'package:quiz_show/features/audio/audioplayers_backend.dart';
import 'package:quiz_show/features/audio/team_sounds.dart';
import 'package:quiz_show/features/buzzers/buzzer_link.dart';
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
import 'package:quiz_show/features/session/pages/session_setup_page.dart';
import 'package:quiz_show/features/session/presenter_window.dart';
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
  Map<String, String> get _gameNames => {for (final game in _playable) game.id: game.name};

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
    final picked = await showNewSessionSheet(context, games: _playable);
    if (picked == null || !mounted) return;
    await guarded(
      context,
      // Saved with the game's name for devices that cannot open the game.
      () => _repo.createSession(name: _gameNames[picked.gameId] ?? "", gameId: picked.gameId),
      failure: "Could not create the session.",
    );
  }

  Future<void> _changeGame(SessionSummary session) async {
    final gameId = await showGamePicker(context, games: _playable, selected: session.gameId);
    if (gameId == null || gameId == session.gameId || !mounted) return;
    await guarded(context, () => _repo.setGame(session.id, gameId, name: _gameNames[gameId]));
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

  void _setUp(SessionSummary session) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SessionSetupPage(session: session, title: sessionTitle(session, _gameNames))),
    );
  }

  void _control(SessionSummary session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ControlPage(sessionId: session.id, title: sessionTitle(session, _gameNames)),
      ),
    );
  }

  Future<void> _delete(SessionSummary session) async {
    final sure = await confirm(
      context,
      title: "Delete session",
      message: "The session of \"${sessionTitle(session, _gameNames)}\" with its teams and points will be deleted.",
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
            gameNames: _gameNames,
            onControl: _control,
            onPresent: _present,
            onChangeGame: _changeGame,
            onDelete: _delete,
            onSetUp: _setUp,
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
    this.onSetUp,
  });

  final List<SessionSummary> sessions;
  final Map<String, String> gameNames;
  final ValueChanged<SessionSummary> onControl;
  final ValueChanged<SessionSummary> onPresent;
  final ValueChanged<SessionSummary> onChangeGame;
  final ValueChanged<SessionSummary> onDelete;

  /// Opens the teams and buzzers before the show; hidden when null.
  final ValueChanged<SessionSummary>? onSetUp;

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
                      // The game is the card's title, so it is picked here
                      // and not somewhere inside the running show.
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => onChangeGame(session),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      sessionTitle(session, gameNames),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: session.gameId == null ? theme.colorScheme.primary : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
                                ],
                              ),
                            ),
                          ),
                        ),
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
                  if (session.createdAtMillis != null)
                    Text(
                      "Created ${formatSessionDate(DateTime.fromMillisecondsSinceEpoch(session.createdAtMillis!))}",
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                      if (onSetUp != null) ...[
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          onPressed: () => onSetUp!(session),
                          icon: const Icon(Icons.settings_outlined),
                          tooltip: "Set up teams and buzzers",
                        ),
                      ],
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

/// What a session is called on screen: the game it plays.
String sessionTitle(SessionSummary session, Map<String, String> gameNames) {
  if (session.gameId == null) return "Choose a game";
  final name = gameNames[session.gameId];
  if (name != null) return name.isEmpty ? "Unnamed game" : name;
  return session.name.isEmpty ? "A game you cannot open" : session.name;
}

/// "17 Oct, 20:15", with the year when it is not this one.
String formatSessionDate(DateTime date, {DateTime? now}) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String two(int n) => n.toString().padLeft(2, '0');
  final year = date.year == (now ?? DateTime.now()).year ? '' : ' ${date.year}';
  return "${date.day} ${months[date.month - 1]}$year, ${two(date.hour)}:${two(date.minute)}";
}

/// Lets the user pick one of [games]; returns its id.
Future<String?> showGamePicker(BuildContext context, {required List<GameSummary> games, String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _GameChoices(games: games, selected: selected, onPicked: (id) => Navigator.of(context).pop(id)),
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

/// The game for a new session; null when the sheet was dismissed.
Future<({String? gameId})?> showNewSessionSheet(BuildContext context, {required List<GameSummary> games}) {
  return showModalBottomSheet<({String? gameId})>(
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
  late String? _gameId = widget.games.length == 1 ? widget.games.first.id : null;

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
          const SizedBox(height: 8),
          Text("Game", style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.35),
            child: _GameChoices(games: widget.games, selected: _gameId, onPicked: (id) => setState(() => _gameId = id)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop((gameId: _gameId)),
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
          ValueListenableBuilder<LinkStatus>(valueListenable: _connection.link!, builder: (context, status, _) => LinkStatusIcon(status)),
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
              // No buzzer box on a controller, but the teams' sounds are
              // saved with the session and can be chosen from here.
              onBuzzerSetup: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BuzzersPage(connection: _connection))),
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
  navigator.push(
    MaterialPageRoute(
      builder: (_) =>
          ConnectDevicesPage(sessionId: connection.sessionId, teams: connection.state.value?.teams ?? const [], lanEndpoints: endpoints),
    ),
  );
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

  /// The big screen in a window of its own, while this one controls.
  PresenterWindow? _window;

  bool get _canFullscreen => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    SessionConnection.present(widget.sessionId).then(
      (connection) {
        if (!mounted) {
          connection.dispose();
          return;
        }
        connection.displaced!.addListener(_onDisplaced);
        // Sound comes out of the presenting device only.
        // A team's own sound is fetched when it is chosen; until this device
        // has it, the team buzzes with the built-in sound.
        void fetchTeamSounds() {
          for (final team in connection.state.value?.teams ?? const <Team>[]) {
            if (team.sound != null) TeamSounds.instance.ensureCached(widget.sessionId, team.sound!);
          }
        }

        connection.state.addListener(fetchTeamSounds);
        TeamSounds.instance.init().then((_) => fetchTeamSounds());
        final audio = AudioDirector(
          host: connection.host!,
          backend: AudioplayersBackend(),
          teamSound: (teamId) => TeamSounds.instance.pathFor(widget.sessionId, connection.host!.state.team(teamId)?.sound),
          resolve: (gameId, name) {
            final file = MediaService.instance.localFile(gameId, name);
            return file.existsSync() ? file.path : null;
          },
        );
        // Files still downloading when a sound was asked for start once they are in.
        connection.missingMedia.addListener(audio.sync);
        // The buzzer box is plugged into this device, so its presses go
        // straight into the host: no network in between.
        // Subscribed once, for as long as this device presents. Whether a
        // press counts right now is decided by the host, not by listening or
        // not listening.
        Buzzers.instance.start();
        _buzzers = Buzzers.instance.link.pressed.listen((id) {
          final teamId = Buzzers.instance.teamFor(widget.sessionId, id, connection.host!.state.teams);
          if (teamId != null) connection.host!.dispatch(Buzz(teamId));
        });
        setState(() {
          _connection = connection;
          _audio = audio;
        });
      },
      onError: (Object error) {
        if (mounted) setState(() => _error = error);
      },
    );
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
    final audio = _audio;
    if (audio != null) _connection?.missingMedia.removeListener(audio.sync);
    audio?.dispose();
    _connection?.dispose();
    if (_fullscreen) windowManager.setFullScreen(false);
    _window?.close();
    super.dispose();
  }

  Future<void> _openWindow(SessionConnection connection) async {
    final access = connection.windowAccess;
    if (access == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final arrivalsBefore = connection.windowArrivals.value;
    try {
      final window = await PresenterWindow.open(
        PresenterWindowArgs(sessionId: widget.sessionId, endpoint: access.endpoint, token: access.token),
      );
      if (!mounted) {
        window.close();
        return;
      }
      if (_fullscreen) {
        _fullscreen = false;
        windowManager.setFullScreen(false);
      }
      setState(() => _window = window);
      // Closed over there: the show comes back to this window.
      window.closed.then((_) {
        if (mounted && identical(_window, window)) setState(() => _window = null);
      });
      // A window that never signs in (it did not start, or hangs) would leave
      // this one controlling an empty screen: take the show back.
      if (await _windowArrives(connection, arrivalsBefore) || !mounted || !identical(_window, window)) return;
      _bringBack();
      messenger.showSnackBar(const SnackBar(content: Text("Could not open a second window.")));
    } catch (error) {
      messenger.showSnackBar(const SnackBar(content: Text("Could not open a second window.")));
    }
  }

  Future<bool> _windowArrives(SessionConnection connection, int before) async {
    final arrived = Completer<bool>();
    void check() {
      if (connection.windowArrivals.value > before && !arrived.isCompleted) arrived.complete(true);
    }

    connection.windowArrivals.addListener(check);
    check();
    final result = await arrived.future.timeout(const Duration(seconds: 20), onTimeout: () => false);
    if (mounted) connection.windowArrivals.removeListener(check);
    return result;
  }

  void _bringBack() {
    _window?.close();
    setState(() => _window = null);
  }

  @override
  Widget build(BuildContext context) {
    final connection = _connection;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("Could not start presenting this session.")),
      );
    }
    if (connection == null) return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    final faint = Theme.of(context).colorScheme.outlineVariant;
    if (_window != null) {
      // The audience looks at the other window; this one is the controller.
      return Scaffold(
        appBar: AppBar(
          title: const Text("Controlling"),
          actions: [
            TextButton.icon(onPressed: _bringBack, icon: const Icon(Icons.close_fullscreen), label: const Text("Close presenter window")),
            IconButton(icon: const Icon(Icons.close), tooltip: "Stop presenting", onPressed: () => Navigator.of(context).pop()),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ControllerView(
              connection: connection,
              onConnectDevices: () => openConnectDevices(context, connection),
              onBuzzerSetup: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BuzzersPage(connection: connection))),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      endDrawer: Drawer(
        width: 460,
        child: SafeArea(
          child: ControllerView(
            connection: connection,
            onConnectDevices: () => openConnectDevices(context, connection),
            // Team sounds are set up there too, so it is offered everywhere.
            onBuzzerSetup: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BuzzersPage(connection: connection))),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: PresenterView(connection: connection, videoCards: true)),
          // Kept faint: the audience is looking at this screen. Only Close
          // stays; the rest come up when the mouse gets near.
          Positioned(
            top: 0,
            right: 0,
            child: Builder(
              builder: (context) => NearMouse(
                builder: (near) => Padding(
                  padding: const EdgeInsets.fromLTRB(96, 4, 4, 96),
                  child: Column(
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: faint),
                        tooltip: "Stop presenting",
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      RevealedWhen(
                        near,
                        child: Column(
                          children: [
                            if (PresenterWindow.supported && connection.windowAccess != null)
                              IconButton(
                                icon: Icon(Icons.open_in_new, color: faint),
                                tooltip: "Open in a new window, to drag onto another screen",
                                onPressed: () => _openWindow(connection),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Says so on screen when a buzzer box was set up but is not talking.
          Positioned(
            left: 8,
            top: 8,
            child: ValueListenableBuilder<BuzzerStatus>(
              valueListenable: Buzzers.instance.link.status,
              builder: (context, status, _) => Buzzers.instance.wanted.value && (status == BuzzerStatus.disconnected || status == BuzzerStatus.silent)
                  ? Chip(
                      avatar: Icon(Icons.usb_off, size: 18, color: Theme.of(context).colorScheme.error),
                      label: const Text("Buzzer box not connected · retrying"),
                    )
                  : const SizedBox(),
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
