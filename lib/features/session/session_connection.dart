import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/session/lan/lan_host_server.dart';
import 'package:quiz_show/features/session/session_client.dart';
import 'package:quiz_show/features/session/session_links.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/game/game.dart';

/// One device's live connection to a session, for the presenter and the
/// controller alike: the current state, the game being played, and somewhere
/// to send commands.
class SessionConnection {
  SessionConnection._(this.sessionId, this.sink, {this.host, FirestoreHostLink? link, SessionClient? client})
      : _link = link,
        _client = client;

  final String sessionId;
  final CommandSink sink;

  /// Set on the presenting device only.
  final SessionHost? host;
  final FirestoreHostLink? _link;
  final SessionClient? _client;
  LanHostServer? _server;

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

  /// The local network is an extra: if it cannot be set up, the show still
  /// runs through the cloud.
  Future<void> _serveLan() async {
    final repo = SessionRepository.instance;
    var tokens = const <String, LanGrant>{};
    _subs.add(repo.watchTokens(sessionId).listen((next) => tokens = next, onError: (Object _) {}));
    try {
      final server = LanHostServer(host!, authorize: (token) => tokens[token]);
      await server.start();
      _server = server;
      lanEndpoints.value = await server.endpoints();
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

  /// A session that lives on this device alone: no account, no network.
  /// The game is whatever [game] holds; a `SetGame` command does not load one.
  factory SessionConnection.local(SessionHost host, {GameContent? game}) {
    final connection = SessionConnection._('local', LocalCommandSink(host), host: host);
    host.setGame(game);
    connection.game.value = game;
    connection.state.value = host.state;
    connection._subs.add(host.states.listen((state) => connection.state.value = state));
    return connection;
  }

  void _onState(SessionState? next) {
    state.value = next;
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
  }
}
