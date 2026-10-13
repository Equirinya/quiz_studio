import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:quiz_show/game/game.dart';

/// A device's connection to a `LanHostServer`.
class LanClient {
  LanClient._(this._socket, this.role, this.teamId);

  final WebSocket _socket;

  /// As granted by the host for the token used.
  final Role role;
  final String? teamId;

  final StreamController<SessionState> _states = StreamController<SessionState>.broadcast();
  final StreamController<PublicView> _views = StreamController<PublicView>.broadcast();
  final StreamController<GameContent?> _games = StreamController<GameContent?>.broadcast();
  final Completer<void> _done = Completer<void>();

  /// Controllers only.
  Stream<SessionState> get states => _states.stream;

  /// Controllers only: the game being played, sent by the host, so a
  /// controller needs no access to it of its own.
  Stream<GameContent?> get games => _games.stream;

  /// Players only.
  Stream<PublicView> get views => _views.stream;

  /// Completes when the connection is gone, for whatever reason.
  Future<void> get done => _done.future;

  bool get isOpen => !_done.isCompleted;

  /// Connects to [endpoint] (`ip:port`) and signs in with [token]. Throws
  /// when the host cannot be reached in time or refuses the token.
  static Future<LanClient> connect(
    String endpoint, {
    required String token,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final socket = await WebSocket.connect('ws://$endpoint/').timeout(timeout);
    socket.pingInterval = const Duration(seconds: 5);
    final messages = StreamIterator<dynamic>(socket);
    try {
      socket.add(jsonEncode({'t': 'hello', 'token': token}));
      if (!await messages.moveNext().timeout(timeout)) throw const SocketException('closed before welcome');
      final welcome = Map<String, dynamic>.from(jsonDecode(messages.current as String) as Map);
      if (welcome['t'] != 'welcome') throw const SocketException('token refused');
      final client = LanClient._(
        socket,
        welcome['role'] == 'player' ? Role.player : Role.controller,
        welcome['teamId'] as String?,
      );
      client._pump(messages);
      return client;
    } catch (_) {
      await socket.close();
      rethrow;
    }
  }

  Future<void> _pump(StreamIterator<dynamic> messages) async {
    try {
      while (await messages.moveNext()) {
        _onMessage(messages.current);
      }
    } catch (_) {
      // A broken connection ends the same way as a closed one.
    }
    await _states.close();
    await _views.close();
    await _games.close();
    if (!_done.isCompleted) _done.complete();
  }

  void _onMessage(Object? data) {
    try {
      final message = Map<String, dynamic>.from(jsonDecode(data as String) as Map);
      switch (message['t']) {
        case 'state':
          _states.add(SessionState.fromJson(Map<String, dynamic>.from(message['s'] as Map)));
        case 'public':
          _views.add(PublicView(Map<String, dynamic>.from(message['p'] as Map)));
        case 'game':
          final game = message['g'];
          _games.add(game == null ? null : GameContent.fromJson(Map<String, dynamic>.from(game as Map)));
      }
    } catch (_) {
      // One malformed message must not take the connection down.
    }
  }

  void send(Command command) {
    if (isOpen) _socket.add(jsonEncode({'t': 'cmd', 'c': command.toJson()}));
  }

  Future<void> close() => _socket.close();
}
