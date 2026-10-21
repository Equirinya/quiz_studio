// Screens of top answers and of rating answers, for a look without a device:
//   flutter test tool/rating_screenshot_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/core/theme.dart';
import 'package:quiz_show/features/games/pages/category_editor_page.dart';
import 'package:quiz_show/features/player/pages/player_page.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import '../test/game/fixture.dart';
import '../test/game/top_answers_fixture.dart';

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

void main() {
  setUpAll(_loadFonts);

  final hosts = <SessionHost>[];
  final owned = <SessionHost>{};

  SessionHost host(GameContent game, List<Command> commands, {SessionState state = topTeams}) {
    final h = SessionHost(initial: state, game: game);
    hosts.add(h);
    for (final command in commands) {
      h.dispatch(command, sender: command is SubmitAnswer ? Sender(Role.player, teamId: command.teamId) : const Sender(Role.controller));
    }
    return h;
  }

  SessionConnection connect(SessionHost h) {
    owned.add(h);
    final connection = SessionConnection.local(h, game: h.game);
    addTearDown(connection.dispose);
    return connection;
  }

  Future<void> shot(WidgetTester tester, String name, Size size, Widget home, {bool dark = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(dark ? Brightness.dark : Brightness.light), home: home),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/$name.png'));
    for (final h in hosts) {
      h.dispatch(const ClearAnswers());
      if (!owned.contains(h)) h.dispose();
    }
    hosts.clear();
    owned.clear();
  }

  Widget controller(SessionHost h) => Scaffold(
    appBar: AppBar(title: const Text("Quiz night")),
    body: ControllerView(connection: connect(h), onConnectDevices: () {}),
  );

  Widget presenter(SessionHost h) => Scaffold(body: PresenterView(connection: connect(h)));

  const phone = Size(412, 892);
  const screen = Size(1600, 900);

  final buzzed = [
    const OpenQuestion(films),
    const Buzz('red'),
    const TopAnswerToggle(2),
    const Buzz('blue'),
    const TopAnswerToggle(0),
    const Buzz('red'),
  ];

  testWidgets('top answers: controller, a team buzzed', (tester) async {
    await shot(tester, 'top_answers_controller_buzzed', phone, controller(host(topAnswersGame(), buzzed)));
  });

  testWidgets('top answers: big screen with who found what', (tester) async {
    await shot(tester, 'top_answers_presenter', screen, presenter(host(topAnswersGame(), buzzed)), dark: true);
  });

  final typed = [
    const OpenQuestion(films),
    const SubmitAnswer('red', PlayerAnswer(items: ['titanik', 'lion king', 'Frozen', 'Avatar', ''])),
    const SubmitAnswer('blue', PlayerAnswer(items: ['Star Wars', 'Jurasic Park', '', '', ''])),
    const MarkTopAnswers('blue', [3]),
  ];

  testWidgets('top answers: controller ticking typed answers', (tester) async {
    await shot(tester, 'top_answers_controller_typed', phone, controller(host(topAnswersGame(mode: TopAnswersMode.typed), typed)));
  });

  testWidgets('top answers: big screen on the devices, answers uncovered', (tester) async {
    final game = topAnswersGame(mode: TopAnswersMode.typed);
    await shot(
      tester,
      'top_answers_presenter_devices',
      screen,
      presenter(
        host(game, [
          ...typed,
          const MarkTopAnswers('red', [0, 1, 2]),
          const TopAnswerToggle(0),
          const TopAnswerToggle(2),
          const TopAnswerToggle(3),
        ]),
      ),
      dark: true,
    );
  });

  testWidgets('top answers: a team typing its list', (tester) async {
    final h = host(topAnswersGame(mode: TopAnswersMode.typed, timer: 60), const [OpenQuestion(films)]);
    await shot(
      tester,
      'top_answers_phone',
      phone,
      Scaffold(
        body: SafeArea(
          child: PlayerView(view: PublicView(h.publicStateFor('red')), teamId: 'red', send: (_) {}, onLeave: () {}),
        ),
      ),
    );
  });

  testWidgets('top answers: editor', (tester) async {
    final question = topAnswersGame(mode: TopAnswersMode.typed).question(films)!;
    await shot(
      tester,
      'top_answers_editor',
      const Size(900, 1000),
      Scaffold(
        appBar: AppBar(title: const Text("Films")),
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: [QuestionCard(gameId: 'g', categoryId: 'c', question: Question.fromMap('q', question.data), initiallyExpanded: true)],
        ),
      ),
    );
  });

  testWidgets('rating: matching gets points per pair', (tester) async {
    const spec = CompanionSpec(
      kind: CompanionKind.match,
      options: ['France', 'Italy', 'Spain', 'Peru'],
      targets: ['Paris', 'Rome', 'Madrid', 'Lima'],
    );
    final h = host(fixtureGame(), const [
      OpenQuestion(estimate),
      OpenAnswers(spec),
      SubmitAnswer('red', PlayerAnswer(pairs: [0, 1, 3, 2])),
      SubmitAnswer('blue', PlayerAnswer(pairs: [0, 1, 2, 3])),
    ], state: fixtureState());
    await shot(tester, 'rating_matching_partial', phone, controller(h));
  });

  testWidgets('rating: estimate with scoring choices', (tester) async {
    const spec = CompanionSpec(kind: CompanionKind.number, solution: 330, unit: 'm');
    final h = host(fixtureGame(), const [
      OpenQuestion(estimate),
      OpenAnswers(spec),
      SubmitAnswer('red', PlayerAnswer(number: 300)),
      SubmitAnswer('blue', PlayerAnswer(number: 450)),
    ], state: fixtureState());
    h.dispatch(AwardAnswer('blue', 0));
    await shot(tester, 'rating_estimate', phone, controller(h));
  });

  testWidgets('rating: half points in the menu', (tester) async {
    final h = host(fixtureGame(), const [
      OpenQuestion(estimate),
      OpenAnswers(CompanionSpec(kind: CompanionKind.text)),
      SubmitAnswer('red', PlayerAnswer(text: 'About three hundred')),
    ], state: fixtureState());
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(Brightness.light), home: controller(h)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip("Other points").first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/rating_half_points.png'));
    h.dispatch(const ClearAnswers());
  });
}
