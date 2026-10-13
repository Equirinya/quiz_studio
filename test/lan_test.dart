import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/lan/lan_client.dart';
import 'package:quiz_show/features/session/lan/lan_host_server.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

/// Real sockets on the loopback interface: the host server on one end, the
/// client other devices use on the other.
void main() {
  late SessionHost host;
  late LanHostServer server;
  late String endpoint;

  const tokens = <String, LanGrant>{
    'ctl': (role: Role.controller, teamId: null),
    'red': (role: Role.player, teamId: 'red'),
  };

  setUp(() async {
    host = SessionHost(initial: fixtureState(), game: fixtureGame());
    server = LanHostServer(host, authorize: (token) => tokens[token]);
    final port = await server.start(port: 0, address: InternetAddress.loopbackIPv4);
    endpoint = '127.0.0.1:$port';
  });

  tearDown(() async {
    await server.stop();
    await host.dispose();
  });

  /// Waits until the host has seen everything sent so far.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 100));

  test('a controller gets the game and the state, and drives the show', () async {
    final client = await LanClient.connect(endpoint, token: 'ctl');
    expect(client.role, Role.controller);
    final game = await client.games.first;
    expect(game!.question(free)!.answerHint, 'Paris');
    expect(game.groups.map((g) => g.id), ['g1', 'g2']);

    final next = client.states.firstWhere((s) => s.current == free);
    client.send(const OpenQuestion(free));
    expect((await next.timeout(const Duration(seconds: 2))).phase, Phase.question);
    expect(host.state.current, free);
    await client.close();
  });

  test('a player gets only the public view and may only buzz for its team', () async {
    final client = await LanClient.connect(endpoint, token: 'red');
    expect((client.role, client.teamId), (Role.player, 'red'));
    final frames = <String>[];
    client.views.listen((view) => frames.add(jsonEncode(view.json)));

    host.dispatch(const OpenQuestion(free));
    await settle();
    expect(frames.last, contains('Capital of France?'));
    expect(frames.join(), isNot(contains('Paris')));

    client
      ..send(const AdjustPoints('red', 1000))
      ..send(const Buzz('blue'))
      ..send(const Judge(correct: true));
    await settle();
    expect(host.state.team('red')!.points, 0);
    expect(host.state.buzzQueue, isEmpty);

    client.send(const Buzz('red'));
    await settle();
    expect(host.state.buzzQueue, ['red']);
    expect(PublicView(jsonDecode(frames.last) as Map<String, dynamic>).buzzQueue, ['red']);
    await client.close();
  });

  test('an unknown token is refused', () async {
    await expectLater(LanClient.connect(endpoint, token: 'made-up'), throwsA(isA<SocketException>()));
    expect(server.clientCount, 0);
  });

  test('commands before hello are ignored and the socket is closed', () async {
    final socket = await WebSocket.connect('ws://$endpoint/');
    socket.add(jsonEncode({'t': 'cmd', 'c': const OpenQuestion(free).toJson()}));
    final frames = await socket.toList().timeout(const Duration(seconds: 2));
    expect(frames.single, contains('denied'));
    expect(host.state.current, isNull);
  });

  test('garbage does not disturb the host or the connection', () async {
    final client = await LanClient.connect(endpoint, token: 'ctl');
    final socket = await WebSocket.connect('ws://$endpoint/');
    socket
      ..add('not json')
      ..add(jsonEncode([1, 2, 3]));
    await settle();
    client.send(const AdjustPoints('red', 5));
    await settle();
    expect(host.state.team('red')!.points, 5);
    await socket.close();
    await client.close();
  });

  test('a new game reaches connected controllers', () async {
    final client = await LanClient.connect(endpoint, token: 'ctl');
    final games = <GameContent?>[];
    client.games.listen(games.add);
    await settle();
    host.setGame(GameContent(id: 'other', name: 'Other'));
    await settle();
    expect(games.last!.id, 'other');
    host.dispatch(const AdjustPoints('red', 1));
    await settle();
    // The game is not resent with every state.
    expect(games.length, 2);
    await client.close();
  });

  test('a whiteboard picture reaches devices already connected and those that join later', () async {
    final early = await LanClient.connect(endpoint, token: 'red');
    final got = <(String, List<int>)>[];
    early.backgrounds.listen((b) => got.add((b.$1, b.$2.toList())));
    server.setBackground('map.png', [1, 2, 3, 250]);
    await settle();
    expect(got.single.$1, 'map.png');
    expect(got.single.$2, [1, 2, 3, 250]);

    final late = await LanClient.connect(endpoint, token: 'ctl');
    final picture = await late.backgrounds.first.timeout(const Duration(seconds: 2));
    expect(picture.$1, 'map.png');
    expect(picture.$2.toList(), [1, 2, 3, 250]);
    await early.close();
    await late.close();
  });

  test('the client notices when the host goes away', () async {
    final client = await LanClient.connect(endpoint, token: 'red');
    expect(client.isOpen, isTrue);
    await server.stop();
    await client.done.timeout(const Duration(seconds: 2));
    expect(client.isOpen, isFalse);
  });

  test('game content survives the trip as JSON', () {
    final game = fixtureGame();
    final copy = GameContent.fromJson(jsonDecode(jsonEncode(game.toJson())) as Map<String, dynamic>);
    expect(copy.name, game.name);
    String shape(GameContent g) => [for (final group in g.groups) '${group.id} ${group.type.name} ${group.categories.map((c) => c.id)}'].join(' | ');
    expect(shape(copy), shape(game));
    expect(copy.category('c1')!.questions.map((q) => q.id), ['free', 'estimate', 'song', 'sum']);
    expect(copy.question(feud)!.percentages, [50.0, 30.0, 20.0]);
    expect(copy.soundsFor(ref: reveal).effects, game.soundsFor(ref: reveal).effects);
    expect(copy.mediaPaths, game.mediaPaths);
  });

  test('values JSON cannot carry are dropped, not fatal', () {
    final game = GameContent.assemble(
      id: 'g',
      game: {'name': 'G', 'createdAt': DateTime(2026)},
      groups: {
        'grp': {'name': 'Group', 'categoryGroupIndex': 0, 'createdAt': Object()},
      },
      categories: {},
      questions: {},
    );
    final copy = GameContent.fromJson(jsonDecode(jsonEncode(game.toJson())) as Map<String, dynamic>);
    expect(copy.name, 'G');
    expect(copy.groups.single.name, 'Group');
  });
}
