import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:quiz_show/game/game.dart';

/// The default port; a fixed one is easier to allow through a firewall.
const int kLanPort = 47800;

/// What a join token entitles a device to.
typedef LanGrant = ({Role role, String? teamId});

/// Serves a [SessionHost] to devices on the same network over WebSockets, so
/// a show keeps running when the internet does not.
///
/// A device opens the socket and says hello with its join token. From then on
/// it receives every new state (controllers: the full state and the game;
/// players: only the public view) and may send commands, which go through the
/// same permission check as everywhere else.
///
/// Protocol, one JSON object per text frame:
///   client → host   {"t":"hello","token":…}        {"t":"cmd","c":{command}}
///   host → client   {"t":"welcome","role":…,"teamId":…}   {"t":"denied"}
///                   {"t":"state","s":{…}}  {"t":"game","g":{…}|null}  {"t":"public","p":{…}}
///                   {"t":"bg","n":name,"d":base64}   the picture of a whiteboard
///                   {"t":"fx","n":name}   controllers: a screen effect such as confetti,
///                                         for a presenter window showing the show
class LanHostServer {
  LanHostServer(this.host, {required this.authorize});

  final SessionHost host;

  /// Looks a join token up; null when it is not valid.
  final LanGrant? Function(String token) authorize;

  HttpServer? _server;
  StreamSubscription<SessionState>? _states;
  StreamSubscription<Effect>? _effects;
  final Map<WebSocket, LanGrant> _clients = {};
  GameContent? _sentGame;
  String? _gameJson;
  String? _backgroundMessage;

  /// Hands every device the picture teams draw on in the current round, and
  /// every device that connects later too. [name] is the media file's name,
  /// by which devices match it to the round.
  void setBackground(String name, List<int> bytes) {
    _backgroundMessage = jsonEncode({'t': 'bg', 'n': name, 'd': base64Encode(bytes)});
    for (final socket in _clients.keys.toList()) {
      try {
        socket.add(_backgroundMessage!);
      } catch (_) {
        _clients.remove(socket);
      }
    }
  }

  int get port => _server?.port ?? 0;

  int get clientCount => _clients.length;

  /// Starts listening, on [port] if it is free and on any free port if not.
  Future<int> start({int port = kLanPort, InternetAddress? address}) async {
    final bindTo = address ?? InternetAddress.anyIPv4;
    try {
      _server = await HttpServer.bind(bindTo, port);
    } on SocketException {
      _server = await HttpServer.bind(bindTo, 0);
    }
    _server!.listen(_onRequest, onError: (Object _) {});
    _states = host.states.listen((_) => _broadcast());
    _effects = host.effects.listen(_onEffect);
    return this.port;
  }

  /// `ip:port` for every address other devices might reach this one on.
  Future<List<String>> endpoints() async {
    if (_server == null) return const [];
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    return [
      for (final interface in interfaces)
        for (final address in interface.addresses) '${address.address}:$port',
    ];
  }

  Future<void> _onRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    socket.pingInterval = const Duration(seconds: 5);
    // A device that connects and never says hello is dropped.
    final unauthenticated = Timer(const Duration(seconds: 5), () {
      if (!_clients.containsKey(socket)) socket.close(WebSocketStatus.policyViolation);
    });
    socket.listen(
      (data) => _onMessage(socket, data),
      onDone: () {
        unauthenticated.cancel();
        _clients.remove(socket);
      },
      onError: (Object _) => _clients.remove(socket),
      cancelOnError: true,
    );
  }

  void _onMessage(WebSocket socket, Object? data) {
    Map<String, dynamic> message;
    try {
      message = Map<String, dynamic>.from(jsonDecode(data as String) as Map);
    } catch (_) {
      return;
    }
    final grant = _clients[socket];
    if (grant == null) {
      final token = message['token'];
      final granted = message['t'] == 'hello' && token is String ? authorize(token) : null;
      if (granted == null || granted.role == Role.host) {
        socket.add(jsonEncode({'t': 'denied'}));
        socket.close(WebSocketStatus.policyViolation);
        return;
      }
      _clients[socket] = granted;
      socket.add(jsonEncode({'t': 'welcome', 'role': granted.role.name, 'teamId': granted.teamId}));
      if (_backgroundMessage != null) socket.add(_backgroundMessage!);
      _sendCurrent(socket, granted, withGame: true);
      return;
    }
    if (message['t'] != 'cmd' || message['c'] is! Map) return;
    final command = Command.fromJson(Map<String, dynamic>.from(message['c'] as Map));
    if (command == null) return;
    host.dispatch(command, sender: Sender(grant.role, teamId: grant.teamId));
  }

  void _sendCurrent(WebSocket socket, LanGrant grant, {required bool withGame}) {
    if (grant.role == Role.player) {
      // A team's devices get their team's view, with what only they may see.
      socket.add(jsonEncode({'t': 'public', 'p': host.publicStateFor(grant.teamId)}));
      return;
    }
    if (withGame) socket.add(_gameMessage());
    socket.add(jsonEncode({'t': 'state', 's': host.state.toJson()}));
  }

  String _gameMessage() {
    if (!identical(_sentGame, host.game) || _gameJson == null) {
      _sentGame = host.game;
      _gameJson = jsonEncode({'t': 'game', 'g': host.game?.toJson()});
    }
    return _gameJson!;
  }

  void _broadcast() {
    final gameChanged = !identical(_sentGame, host.game);
    for (final entry in _clients.entries.toList()) {
      try {
        _sendCurrent(entry.key, entry.value, withGame: gameChanged);
      } catch (_) {
        _clients.remove(entry.key);
      }
    }
    // Also when nobody is connected, so the next broadcast compares rightly.
    if (gameChanged) _gameMessage();
  }

  /// Confetti and the like happen once, outside the state, so they are
  /// passed on as they come.
  void _onEffect(Effect effect) {
    if (effect is! VisualEffect) return;
    final message = jsonEncode({'t': 'fx', 'n': effect.name});
    for (final entry in _clients.entries.toList()) {
      if (entry.value.role == Role.player) continue;
      try {
        entry.key.add(message);
      } catch (_) {
        _clients.remove(entry.key);
      }
    }
  }

  Future<void> stop() async {
    await _states?.cancel();
    await _effects?.cancel();
    for (final socket in _clients.keys.toList()) {
      await socket.close(WebSocketStatus.goingAway);
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
