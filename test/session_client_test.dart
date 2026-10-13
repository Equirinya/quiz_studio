import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/lan/lan_host_server.dart';
import 'package:quiz_show/features/session/session_client.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

/// The client between two transports: a real LAN server on loopback, and a
/// stand-in for the cloud made of plain streams.
void main() {
  late SessionHost host;
  late LanHostServer server;
  late StreamController<SessionState?> cloudStates;
  late StreamController<PublicView?> cloudViews;
  late List<Command> cloudSent;
  late int port;

  const tokens = <String, LanGrant>{
    'ctl': (role: Role.controller, teamId: null),
    'red': (role: Role.player, teamId: 'red'),
  };
  const fast = Duration(milliseconds: 50);

  Future<void> startServer({int onPort = 0}) async {
    server = LanHostServer(host, authorize: (token) => tokens[token]);
    port = await server.start(port: onPort, address: InternetAddress.loopbackIPv4);
  }

  /// The "cloud": every host state arrives there too, and commands sent
  /// through it reach the host.
  SessionClient client(Role role, {String? token, List<String>? endpoints, Stream<List<String>>? cloudEndpoints}) {
    final c = SessionClient(
      role: role,
      teamId: role == Role.player ? 'red' : null,
      token: token,
      endpoints: endpoints ?? ['127.0.0.1:$port'],
      cloudStates: role == Role.player ? null : cloudStates.stream,
      cloudViews: role == Role.player ? cloudViews.stream : null,
      cloudEndpoints: cloudEndpoints,
      cloudSend: (command) async {
        cloudSent.add(command);
        host.dispatch(command, sender: Sender(role, teamId: role == Role.player ? 'red' : null));
      },
      retryDelay: fast,
    );
    addTearDown(c.dispose);
    return c..start();
  }

  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(condition(), isTrue, reason: 'timed out');
  }

  setUp(() async {
    host = SessionHost(initial: fixtureState(), game: fixtureGame());
    cloudStates = StreamController<SessionState?>.broadcast();
    cloudViews = StreamController<PublicView?>.broadcast();
    cloudSent = [];
    host.states.listen((s) {
      cloudStates.add(s);
      cloudViews.add(PublicView(host.publicState));
    });
    await startServer();
  });

  tearDown(() async {
    await server.stop();
    await host.dispose();
  });

  test('uses the local network when the presenter is reachable there', () async {
    final c = client(Role.controller, token: 'ctl');
    await until(() => c.link.value == LinkStatus.lan && c.state.value != null);
    expect(c.lanGame.value!.id, 'game');

    c.send(const OpenQuestion(free));
    await until(() => c.state.value!.current == free);
    expect(cloudSent, isEmpty);
  });

  test('without a reachable presenter everything goes through the cloud', () async {
    final c = client(Role.controller, token: 'ctl', endpoints: ['127.0.0.1:1']);
    c.send(const AdjustPoints('red', 10));
    await until(() => c.state.value?.team('red')?.points == 10);
    expect(c.link.value, LinkStatus.cloud);
    expect(cloudSent, hasLength(1));
    expect(c.lanGame.value, isNull);
  });

  test('falls back to the cloud when the presenter drops off the network, and comes back', () async {
    final c = client(Role.player, token: 'red');
    await until(() => c.link.value == LinkStatus.lan && c.view.value != null);
    host.dispatch(const OpenQuestion(free));
    await until(() => c.view.value!.phase == Phase.question);

    await server.stop();
    await until(() => c.link.value == LinkStatus.cloud);
    c.send(const Buzz('red'));
    await until(() => c.view.value!.buzzQueue.contains('red'));
    expect(cloudSent, hasLength(1));

    await startServer(onPort: port);
    await until(() => c.link.value == LinkStatus.lan);
    host.dispatch(const Judge(correct: true));
    await until(() => c.view.value!.phase == Phase.overview);
  });

  test('an older state arriving late over the other transport is ignored', () async {
    final c = client(Role.controller, token: 'ctl');
    await until(() => c.link.value == LinkStatus.lan);
    final stale = host.state;
    host.dispatch(const AdjustPoints('red', 10));
    await until(() => c.state.value?.team('red')?.points == 10);
    cloudStates.add(stale);
    await Future<void>.delayed(fast);
    expect(c.state.value!.team('red')!.points, 10);
  });

  test("connects once the presenter's address or the token becomes known", () async {
    final endpoints = StreamController<List<String>>();
    addTearDown(endpoints.close);
    final c = client(Role.controller, endpoints: const [], cloudEndpoints: endpoints.stream);
    await Future<void>.delayed(fast * 2);
    expect(c.link.value, LinkStatus.cloud);

    endpoints.add(['127.0.0.1:$port']);
    await Future<void>.delayed(fast * 2);
    expect(c.link.value, LinkStatus.cloud, reason: 'still no token');

    c.token = 'ctl';
    await until(() => c.link.value == LinkStatus.lan);
  });

  test('a wrong token never gets onto the local network', () async {
    final c = client(Role.controller, token: 'nope');
    await Future<void>.delayed(fast * 4);
    expect(c.link.value, LinkStatus.cloud);
    expect(server.clientCount, 0);
  });
}
