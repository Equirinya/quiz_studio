import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/session/background_image.dart';
import 'package:quiz_show/features/session/lan/lan_discovery.dart';
import 'package:quiz_show/features/session/lan/lan_host_server.dart';
import 'package:quiz_show/features/session/session_client.dart';
import 'package:quiz_show/features/session/session_links.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/game/game.dart';

/// One device's live connection to a session, for the presenter and the
/// controller alike: the current state, the game being played, and somewhere
/// to send commands.
class SessionConnection {
  SessionConnection._(
    this.sessionId,
    this.sink, {
    this.host,
    FirestoreHostLink? link,
    SessionClient? client,
    bool cloud = true,
  })  : _link = link,
        _client = client,
        _cloud = cloud;

  final String sessionId;
  final CommandSink sink;

  /// Set on the presenting device only.
  final SessionHost? host;
  final FirestoreHostLink? _link;
  final SessionClient? _client;
  LanHostServer? _server;
  LanBeacon? _beacon;

  /// False for a presenter window, which has no account of its own and gets
  /// everything from the main window.
  final bool _cloud;

  /// Presenting: lets a presenter window of this app in over the loopback.
  /// Made up afresh every time and never stored anywhere.
  final String _windowToken = _randomToken();

  static String _randomToken() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
  }

  final ValueNotifier<SessionState?> state = ValueNotifier(null);
  final ValueNotifier<GameContent?> game = ValueNotifier(null);

  /// Media files of the current game that could not be cached.
  final ValueNotifier<List<String>> missingMedia = ValueNotifier(const []);

  /// Presenting only: where this device listens on the local network.
  final ValueNotifier<List<String>> lanEndpoints = ValueNotifier(const []);

  final List<StreamSubscription<dynamic>> _subs = [];
  StreamSubscription<dynamic>? _gameSub;
  String? _gameId;
  bool _disposed = false;

  bool get isPresenting => host != null;

  /// See [FirestoreHostLink.displaced]; null when not presenting.
  ValueListenable<bool>? get displaced => _link?.displaced;

  /// Controlling only: whether the presenter is reached over the local
  /// network or the internet.
  ValueListenable<LinkStatus>? get link => _client?.link;

  void send(Command command) => sink.send(command);

  /// Confetti and the like: from the host itself when presenting, otherwise
  /// as the presenter passes them on over the local network.
  Stream<Effect>? get effects => host?.effects ?? _client?.effects;

  /// Presenting: where a presenter window on this computer connects, and the
  /// token it signs in with; null when the local network server is not up.
  ({String endpoint, String token})? get windowAccess =>
      _server == null ? null : (endpoint: '127.0.0.1:${_server!.port}', token: _windowToken);

  /// Presenting: counts presenter windows that signed in with [windowAccess],
  /// so the main window can tell whether one actually arrived.
  final ValueNotifier<int> windowArrivals = ValueNotifier(0);

  /// Makes this device the session's host: it holds the state, applies every
  /// command and publishes the results, to the cloud and on the local network.
  static Future<SessionConnection> present(String sessionId) async {
    final repo = SessionRepository.instance;
    final deviceId = await repo.deviceId();
    final host = SessionHost(initial: await FirestoreHostLink.loadState(sessionId));
    final link = FirestoreHostLink(sessionId, host, deviceId);
    final connection = SessionConnection._(sessionId, LocalCommandSink(host), host: host, link: link);
    connection._onState(host.state);
    connection._subs.add(host.states.listen(connection._onState));
    await link.start();
    await connection._serveLan();
    return connection;
  }

  /// Who [token] lets in over the local network: the presenter window of this
  /// computer, or whoever the session's join tokens name.
  static LanGrant? grantFor(String token, {required String windowToken, required Map<String, LanGrant> tokens}) =>
      token == windowToken ? (role: Role.controller, teamId: null) : tokens[token];

  /// The local network is an extra: if it cannot be set up, the show still
  /// runs through the cloud.
  Future<void> _serveLan() async {
    final repo = SessionRepository.instance;
    var tokens = const <String, LanGrant>{};
    _subs.add(repo.watchTokens(sessionId).listen((next) => tokens = next, onError: (Object _) {}));
    try {
      final server = LanHostServer(
        host!,
        // The presenter window sees everything and may take a finished video
        // card off screen, like a controller.
        authorize: (token) {
          if (token == _windowToken) windowArrivals.value++;
          return grantFor(token, windowToken: _windowToken, tokens: tokens);
        },
      );
      await server.start();
      _server = server;
      lanEndpoints.value = await server.endpoints();
      // Answering "where is the presenter?" is optional on top of that.
      try {
        _beacon = LanBeacon(sessionId: sessionId, serverPort: server.port);
        await _beacon!.start();
      } catch (error) {
        if (kDebugMode) print('Session: no discovery beacon: $error');
      }
      await repo.publishLanEndpoints(sessionId, lanEndpoints.value);
    } catch (error) {
      if (kDebugMode) print('Session: no local network server: $error');
    }
  }

  /// Follows a session another device presents and sends it commands.
  ///
  /// [joinLink] is the scanned code of a device that joined; the host's own
  /// devices leave it out and fetch a token themselves.
  static SessionConnection control(
    String sessionId, {
    SessionJoinLink? joinLink,
    void Function(Object error)? onSendError,
  }) {
    final client = SessionClient.firestore(
      sessionId: sessionId,
      role: Role.controller,
      token: joinLink?.token,
      endpoints: joinLink?.lan ?? const [],
      onSendError: onSendError,
    );
    final connection = SessionConnection._(sessionId, client, client: client);
    client.state.addListener(() => connection._onState(client.state.value));
    // A picture arriving is worth a repaint of whatever shows answers.
    client.background.addListener(() => connection.state.value = client.state.value == null ? null : connection.state.value?.copyWith());
    // Over the local network the presenter sends the game along, which also
    // serves a controller whose account cannot open the game itself.
    client.lanGame.addListener(() {
      final sent = client.lanGame.value;
      if (sent == null) return;
      connection._gameSub?.cancel();
      connection._gameSub = null;
      connection.game.value = sent;
    });
    client.start();
    if (joinLink == null) {
      SessionRepository.instance.joinLinks(sessionId, const []).then(
            (links) => connection._disposed ? null : client.token = links.controller.token,
            onError: (Object _) {},
          );
    }
    return connection;
  }

  /// The show in a second window of this app on the same computer: it
  /// follows the main window over the loopback and has no account of its own.
  static SessionConnection window({required String sessionId, required String endpoint, required String token}) {
    final client = SessionClient(
      role: Role.controller,
      token: token,
      endpoints: [endpoint],
      retryDelay: const Duration(milliseconds: 500),
    );
    final connection = SessionConnection._(sessionId, client, client: client, cloud: false);
    client.state.addListener(() => connection._onState(client.state.value));
    client.background.addListener(() => connection.state.value = client.state.value == null ? null : connection.state.value?.copyWith());
    client.lanGame.addListener(() {
      final sent = client.lanGame.value;
      if (sent != null) connection.game.value = sent;
    });
    client.start();
    return connection;
  }

  /// A session that lives on this device alone: no account, no network.
  /// The game is whatever [game] holds; a `SetGame` command does not load one.
  /// [sessionId] names a saved session this one sets up, for its team sounds
  /// and buzzer assignments.
  factory SessionConnection.local(SessionHost host, {GameContent? game, String sessionId = 'local'}) {
    final connection = SessionConnection._(sessionId, LocalCommandSink(host), host: host);
    host.setGame(game);
    connection.game.value = game;
    connection.state.value = host.state;
    connection._subs.add(host.states.listen((state) => connection.state.value = state));
    return connection;
  }

  String? _backgroundName;

  /// The picture a whiteboard round is drawn on, for showing answers: from
  /// this device's media cache when it presents, otherwise as received from
  /// the presenter.
  ImageProvider? backgroundImage(String? name) {
    if (name == null) return null;
    if (isPresenting) {
      final gameId = _gameId;
      if (gameId == null) return null;
      final file = MediaService.instance.localFile(gameId, name);
      return file.existsSync() ? FileImage(file) : null;
    }
    final received = _client?.background.value;
    return received != null && received.$1 == name ? MemoryImage(received.$2) : null;
  }

  /// Presenting: when a round with a picture starts, shrink the picture and
  /// send it to the teams' devices, over the local network and the cloud.
  Future<void> _shareBackground(SessionState? next) async {
    final name = next?.answerRound?.spec.backgroundImage;
    final gameId = _gameId;
    if (!isPresenting || name == null || gameId == null || name == _backgroundName) return;
    _backgroundName = name;
    try {
      await MediaService.instance.ensureCached(gameId, name);
      final bytes = await prepareBackgroundFile(MediaService.instance.localFile(gameId, name));
      if (bytes == null || _disposed) return;
      _server?.setBackground(name, bytes);
      await SessionRepository.instance.publishBackground(sessionId, name, bytes);
    } catch (error) {
      // The round still works; the teams draw on plain paper.
      if (kDebugMode) print('Session: could not share the whiteboard picture: $error');
      _backgroundName = null;
    }
  }

  void _onState(SessionState? next) {
    state.value = next;
    _shareBackground(next);
    if (next?.gameId != _gameId) _watchGame(next?.gameId);
  }

  void _watchGame(String? gameId) {
    _gameId = gameId;
    _gameSub?.cancel();
    _gameSub = null;
    missingMedia.value = const [];
    // The presenter's copy, when there is one, is already the right game.
    final sent = _client?.lanGame.value;
    if (sent != null && sent.id == gameId) {
      game.value = sent;
      return;
    }
    game.value = null;
    if (!_cloud) return; // It comes from the main window.
    if (gameId == null || gameId.isEmpty) {
      host?.setGame(null);
      return;
    }
    _gameSub = GameRepository.instance.watchGame(gameId, activeOnly: true).listen((snapshot) {
      game.value = snapshot.content;
      host?.setGame(snapshot.content);
      // Only the presenter shows and plays media.
      if (isPresenting) {
        MediaService.instance.ensureAllCached(gameId, snapshot.content.mediaPaths).then((failed) {
          if (_gameId == gameId && !_disposed) missingMedia.value = failed;
        });
      }
    }, onError: (Object error) {
      if (kDebugMode) print('Session: game $gameId is not available: $error');
      if (_client?.lanGame.value == null) game.value = null;
      host?.setGame(null);
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _gameSub?.cancel();
    _beacon?.stop();
    if (_server != null) {
      await _server!.stop();
      SessionRepository.instance.publishLanEndpoints(sessionId, const []).catchError((Object _) {});
    }
    await _link?.stop();
    await _client?.dispose();
    await host?.dispose();
    state.dispose();
    game.dispose();
    missingMedia.dispose();
    lanEndpoints.dispose();
    windowArrivals.dispose();
  }
}
