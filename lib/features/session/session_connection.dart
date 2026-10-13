import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/session/session_links.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/game/game.dart';

/// One device's live connection to a session, for the presenter and the
/// controller alike: the current state, the game being played, and somewhere
/// to send commands.
class SessionConnection {
  SessionConnection._(this.sessionId, this.sink, {this.host, FirestoreHostLink? link}) : _link = link;

  final String sessionId;
  final CommandSink sink;

  /// Set on the presenting device only.
  final SessionHost? host;
  final FirestoreHostLink? _link;

  final ValueNotifier<SessionState?> state = ValueNotifier(null);
  final ValueNotifier<GameContent?> game = ValueNotifier(null);

  /// Media files of the current game that could not be cached.
  final ValueNotifier<List<String>> missingMedia = ValueNotifier(const []);

  StreamSubscription<dynamic>? _stateSub;
  StreamSubscription<dynamic>? _gameSub;
  String? _gameId;

  bool get isPresenting => host != null;

  /// See [FirestoreHostLink.displaced]; null when not presenting.
  ValueListenable<bool>? get displaced => _link?.displaced;

  void send(Command command) => sink.send(command);

  /// Makes this device the session's host: it holds the state, applies every
  /// command and publishes the results.
  static Future<SessionConnection> present(String sessionId) async {
    final deviceId = await SessionRepository.instance.deviceId();
    final host = SessionHost(initial: await FirestoreHostLink.loadState(sessionId));
    final link = FirestoreHostLink(sessionId, host, deviceId);
    final connection = SessionConnection._(sessionId, LocalCommandSink(host), host: host, link: link);
    connection._onState(host.state);
    connection._stateSub = host.states.listen(connection._onState);
    await link.start();
    return connection;
  }

  /// A session that lives on this device alone: no account, no network.
  /// The game is whatever [game] holds; a `SetGame` command does not load one.
  factory SessionConnection.local(SessionHost host, {GameContent? game}) {
    final connection = SessionConnection._('local', LocalCommandSink(host), host: host);
    host.setGame(game);
    connection.game.value = game;
    connection.state.value = host.state;
    connection._stateSub = host.states.listen((state) => connection.state.value = state);
    return connection;
  }

  /// Follows a session another device presents and sends it commands.
  static SessionConnection control(String sessionId, {void Function(Object error)? onSendError}) {
    final sink = RemoteCommandSink(sessionId, role: Role.controller, onError: onSendError);
    final connection = SessionConnection._(sessionId, sink);
    connection._stateSub = SessionRepository.instance.watchState(sessionId).listen(connection._onState);
    return connection;
  }

  void _onState(SessionState? next) {
    state.value = next;
    if (next?.gameId != _gameId) _watchGame(next?.gameId);
  }

  void _watchGame(String? gameId) {
    _gameId = gameId;
    _gameSub?.cancel();
    game.value = null;
    missingMedia.value = const [];
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
          if (_gameId == gameId) missingMedia.value = failed;
        });
      }
    }, onError: (Object error) {
      if (kDebugMode) print('Session: game $gameId is not available: $error');
      game.value = null;
      host?.setGame(null);
    });
  }

  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _gameSub?.cancel();
    await _link?.stop();
    await host?.dispose();
    state.dispose();
    game.dispose();
    missingMedia.dispose();
  }
}
