// The main screens with twelve teams, to see that nothing overflows or gets
// unreadable with a big group. Writes tool/screenshots/twelve_teams/.
//
//   flutter test tool/twelve_teams_screenshots_test.dart --update-goldens

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/core/theme.dart';
import 'package:quiz_show/features/player/pages/player_page.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import '../test/game/betting_fixture.dart' show bettingGame, buzzed;
import '../test/game/fixture.dart' show fixtureGame, free, estimate;
import '../test/game/scoring_fixture.dart' show scoringGame, mime, raced;

final _fonts = '${Platform.environment['FLUTTER_ROOT'] ?? '/home/jacob/development/flutter'}/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  Future<ByteData> read(String name) => Future.value(ByteData.view(File('$_fonts/$name').readAsBytesSync().buffer));
  final roboto = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(read(name));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'))).load();
}

const _names = [
  'Red', 'Blue', 'Green', 'The Popcorn Brigade', 'Yellow', 'Purple', //
  'Team 7', 'Orange', 'Die Filmnerds', 'Teal', 'Pink', 'Last but not least',
];

/// Twelve teams, some with their own colour and long names, with scores.
SessionState twelve() => SessionState(
  gameId: 'game',
  teams: [
    for (final (i, name) in _names.indexed)
      Team(id: 't$i', name: name, points: (i * 137) % 900, color: i.isEven ? teamColors[i ~/ 2 % teamColors.length] : null),
  ],
);

final _teamIds = [for (var i = 0; i < 12; i++) 't$i'];

void main() {
  setUpAll(_loadFonts);

  late SessionHost host;

  Future<SessionConnection> start(WidgetTester tester, Size size, GameContent game, List<Command> commands) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: twelve());
    final connection = SessionConnection.local(host, game: game);
    addTearDown(connection.dispose);
    for (final command in commands) {
      host.dispatch(command);
    }
    return connection;
  }

  Future<void> presenter(WidgetTester tester, GameContent game, List<Command> commands) async {
    final connection = await start(tester, const Size(1600, 900), game, commands);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.dark),
        home: Scaffold(body: PresenterView(connection: connection)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> controller(WidgetTester tester, GameContent game, List<Command> commands, {Size size = const Size(412, 892)}) async {
    final connection = await start(tester, size, game, commands);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          appBar: AppBar(title: const Text("Quiz night")),
          body: ControllerView(connection: connection, onConnectDevices: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/twelve_teams/$name.png'));
    expect(tester.takeException(), isNull, reason: '$name overflows or throws');
    host.dispatch(const ClearAnswers());
  }

  const numbers = CompanionSpec(kind: CompanionKind.number, solution: 330, unit: 'm');
  final answered = [
    const OpenQuestion(estimate),
    const OpenAnswers(numbers),
    for (final (i, id) in _teamIds.indexed) SubmitAnswer(id, PlayerAnswer(number: 250.0 + i * 13)),
    const LockAnswers(),
  ];

  testWidgets('presenter: the board', (tester) async {
    await presenter(tester, fixtureGame(), const []);
    await shot(tester, 'presenter_board');
  });

  testWidgets('presenter: six teams buzzed', (tester) async {
    await presenter(tester, fixtureGame(), [
      const SetQueueBuzzers(true),
      const OpenQuestion(free),
      for (final id in ['t3', 't0', 't7', 't11', 't5', 't9']) Buzz(id),
    ]);
    await shot(tester, 'presenter_buzzed');
  });

  testWidgets('presenter: every answer on screen', (tester) async {
    await presenter(tester, fixtureGame(), [...answered, const RevealAnswers()]);
    await shot(tester, 'presenter_answers');
  });

  testWidgets('presenter: the bets', (tester) async {
    await presenter(tester, bettingGame(), [
      const OpenQuestion(buzzed),
      for (final (i, id) in _teamIds.indexed) PlaceBet(id, 50 * (i + 1)),
      const CloseBets(),
    ]);
    // The cards come in one after another.
    await tester.pump(const Duration(seconds: 4));
    await shot(tester, 'presenter_bets');
  });

  testWidgets('presenter: twelve teams scoring at once', (tester) async {
    await presenter(tester, scoringGame(), [const OpenQuestion(mime), for (final id in _teamIds.reversed) PlaceTeam(id)]);
    host.dispatch(const GivePoints());
    // Pop-ups one after another: the first ones are up.
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await shot(tester, 'presenter_pops');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('controller: the board', (tester) async {
    await controller(tester, fixtureGame(), const []);
    await shot(tester, 'controller_board');
  });

  testWidgets('controller: twelve answers rated, points not given', (tester) async {
    await controller(tester, scoringGame(), [
      const OpenQuestion(raced),
      for (final (i, id) in _teamIds.indexed) ...[
        SubmitAnswer(id, PlayerAnswer(text: i % 3 == 0 ? 'Nosferatu' : 'Metropolis')),
        LockAnswer(id),
      ],
      for (final (i, id) in _teamIds.indexed) RateAnswer(id, correct: i % 3 != 0),
    ]);
    await shot(tester, 'controller_rated');
  });

  testWidgets('controller: charades with twelve teams', (tester) async {
    await controller(tester, scoringGame(), [
      const OpenQuestion(mime),
      for (final id in ['t4', 't0', 't9', 't2']) PlaceTeam(id),
    ]);
    await shot(tester, 'controller_charades');
  });

  testWidgets('controller: answers on a tablet', (tester) async {
    await controller(tester, fixtureGame(), answered, size: const Size(1180, 820));
    await shot(tester, 'controller_answers_tablet');
  });

  testWidgets('a phone: the bets of all twelve', (tester) async {
    await start(tester, const Size(412, 892), bettingGame(), [
      const OpenQuestion(buzzed),
      for (final (i, id) in _teamIds.indexed) PlaceBet(id, 50 * (i + 1)),
      const CloseBets(),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: SafeArea(
            child: PlayerView(view: PublicView(host.publicStateFor('t3')), teamId: 't3', send: (_) {}, onLeave: () {}),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, 'player_bets');
  });
}
