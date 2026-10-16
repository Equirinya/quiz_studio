import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:quiz_show/features/session/lan/lan_client.dart';
import 'package:quiz_show/features/session/lan/lan_discovery.dart';
import 'package:quiz_show/features/session/session_links.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/game/game.dart';

/// How this device currently reaches the presenter.
enum LinkStatus {
  /// Directly, over the local network.
  lan,

  /// Through the internet.
  cloud,
}

typedef LanConnector = Future<LanClient> Function(String endpoint, {required String token});

/// A controller's or player's line to the presenting device.
///
/// It uses the local network whenever the presenter can be reached there and
/// the internet otherwise, and switches between the two on its own. Both
/// carry the same states, numbered by `seq`, so whichever is newer wins and a
/// switch is not visible beyond the status icon.
class SessionClient implements CommandSink {
  SessionClient({
    required this.role,
    this.teamId,
    String? token,
    List<String> endpoints = const [],
    this.cloudStates,
    this.cloudViews,
    this.cloudEndpoints,
    this.cloudBackground,
    this.cloudSend,
    this.onSendError,
    this.discover,
    LanConnector? connect,
    this.retryDelay = const Duration(seconds: 2),
  })  : _token = token,
        _endpoints = {...endpoints},
        _connect = connect ?? LanClient.connect;

  /// A client backed by Firestore for the cloud side.
  factory SessionClient.firestore({
    required String sessionId,
    required Role role,
    String? teamId,
    String? token,
    List<String> endpoints = const [],
    void Function(Object error)? onSendError,
  }) {
    final repo = SessionRepository.instance;
    return SessionClient(
      role: role,
      teamId: teamId,
      token: token,
      endpoints: endpoints,
      cloudStates: role == Role.player ? null : repo.watchState(sessionId),
      cloudViews: role == Role.player ? repo.watchPublicState(sessionId, teamId: teamId) : null,
      cloudEndpoints: repo.watchLanEndpoints(sessionId),
      cloudBackground: repo.watchBackground(sessionId),
      cloudSend: (command) => repo.sendCommand(sessionId, command, role: role, teamId: teamId),
      onSendError: onSendError,
      discover: () => discoverPresenter(sessionId),
    );
  }

  final Role role;
  final String? teamId;

  /// Controllers: the full state as the cloud delivers it.
  final Stream<SessionState?>? cloudStates;

  /// Players: the public view as the cloud delivers it.
  final Stream<PublicView?>? cloudViews;

  /// Where the presenter says it listens; adds to what the join code carried.
  final Stream<List<String>>? cloudEndpoints;

  /// The picture of a whiteboard round as the cloud delivers it.
  final Stream<(String, Uint8List)?>? cloudBackground;
  final Future<void> Function(Command command)? cloudSend;
  final void Function(Object error)? onSendError;

  /// Asks the local network where the presenter is; used when none of the
  /// known addresses answers, e.g. after the presenter got a new one.
  final Future<String?> Function()? discover;
  final Duration retryDelay;
  final LanConnector _connect;

  final ValueNotifier<SessionState?> state = ValueNotifier(null);
  final ValueNotifier<PublicView?> view = ValueNotifier(null);

  /// The game as sent by the presenter over the local network; null until
  /// then, and always null for players.
  final ValueNotifier<GameContent?> lanGame = ValueNotifier(null);
  final ValueNotifier<LinkStatus> link = ValueNotifier(LinkStatus.cloud);

  /// The picture teams draw on, as (media name, image bytes); whichever
  /// transport brings it first.
  final ValueNotifier<(String, Uint8List)?> background = ValueNotifier(null);

  /// Screen effects, when the presenter is reached over the local network.
  Stream<Effect> get effects => _effectsOut.stream;
  final StreamController<Effect> _effectsOut = StreamController<Effect>.broadcast();

  /// False once the cloud refused this device, e.g. after it was removed.
  final ValueNotifier<bool> cloudOk = ValueNotifier(true);

  String? _token;
  final Set<String> _endpoints;
  final List<StreamSubscription<dynamic>> _subs = [];
  LanClient? _lan;
  int _seq = -1;
  bool _disposed = false;
  bool _started = false;
  Completer<void>? _wake;

  /// The join token, when it only becomes known after construction.
  set token(String? value) {
    _token = value;
    _wake?.complete();
  }

  void start() {
    if (_started) return;
    _started = true;
    void failed(Object _) => cloudOk.value = false;
    if (cloudStates != null) {
      _subs.add(cloudStates!.listen((s) {
        if (s != null) _onState(s);
      }, onError: failed));
    }
    if (cloudViews != null) {
      _subs.add(cloudViews!.listen((v) {
        if (v != null) _onView(v);
      }, onError: failed));
    }
    if (cloudEndpoints != null) {
      _subs.add(cloudEndpoints!.listen((endpoints) {
        if (_endpoints.length != endpoints.length || !_endpoints.containsAll(endpoints)) {
          _endpoints.addAll(endpoints);
          _wake?.complete();
        }
      }, onError: (Object _) {}));
    }
    if (cloudBackground != null) {
      _subs.add(cloudBackground!.listen(_onBackground, onError: (Object _) {}));
    }
    _lanLoop();
  }

  // A message can still be on its way when the client is disposed; it is
  // dropped then rather than handed to a notifier that is gone.

  void _onBackground((String, Uint8List)? next) {
    if (_disposed) return;
    // The same picture from the other transport changes nothing.
    if (next != null && next.$1 != background.value?.$1) background.value = next;
  }

  void _onState(SessionState next) {
    if (_disposed || next.seq < _seq) return;
    _seq = next.seq;
    state.value = next;
  }

  void _onView(PublicView next) {
    if (_disposed || next.seq < _seq) return;
    _seq = next.seq;
    view.value = next;
  }

  /// Keeps trying to reach the presenter on the local network for as long as
  /// this client lives, and holds the connection while it lasts.
  Future<void> _lanLoop() async {
    while (!_disposed) {
      final token = _token;
      if (token != null) {
        var connected = false;
        for (final endpoint in _endpoints.toList()) {
          if (_disposed) return;
          try {
            final client = await _connect(endpoint, token: token);
            if (_disposed) {
              await client.close();
              return;
            }
            connected = true;
            await _useLan(client);
            break;
          } catch (_) {
            // Not reachable here; try the next address.
          }
        }
        if (!connected && discover != null && !_disposed) {
          final found = await discover!();
          // A new address is tried straight away.
          if (found != null && _endpoints.add(found)) continue;
        }
      }
      if (_disposed) return;
      // Retry later, or right away when a token or address comes in.
      final wake = _wake = Completer<void>();
      await Future.any([wake.future, Future<void>.delayed(retryDelay)]);
      _wake = null;
    }
  }

  Future<void> _useLan(LanClient client) async {
    _lan = client;
    final subs = [
      client.states.listen(_onState),
      client.views.listen(_onView),
      client.games.listen((game) {
        if (!_disposed) lanGame.value = game;
      }),
      client.backgrounds.listen(_onBackground),
      client.effects.listen((effect) {
        if (!_disposed) _effectsOut.add(effect);
      }),
    ];
    link.value = LinkStatus.lan;
    await client.done;
    for (final sub in subs) {
      await sub.cancel();
    }
    _lan = null;
    if (!_disposed) link.value = LinkStatus.cloud;
  }

  @override
  void send(Command command) {
    final lan = _lan;
    if (lan != null && lan.isOpen) {
      lan.send(command);
      return;
    }
    final send = cloudSend;
    if (send == null) {
      onSendError?.call(StateError('not connected'));
      return;
    }
    send(command).catchError((Object error) => onSendError?.call(error));
  }

  Future<void> dispose() async {
    _disposed = true;
    _wake?.complete();
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _lan?.close();
    state.dispose();
    view.dispose();
    lanGame.dispose();
    link.dispose();
    background.dispose();
    cloudOk.dispose();
    await _effectsOut.close();
  }
}
