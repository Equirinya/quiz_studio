// Renders the session screens to PNG files for a quick look without a device:
//   flutter test tool/screenshot_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/core/theme.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import '../test/game/fixture.dart';

const _fonts = '/home/jacob/development/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  Future<ByteData> read(String name) => Future.value(ByteData.view(File('$_fonts/$name').readAsBytesSync().buffer));
  final roboto = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(read(name));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'));
  await icons.load();
}

void main() {
  // Real file I/O: has to happen outside the fake clock of testWidgets.
  setUpAll(_loadFonts);

  late SessionHost host;

  ThemeData theme(Brightness brightness) => buildAppTheme(brightness);

  /// The controller as on a phone.
  Future<void> phone(WidgetTester tester, List<Command> commands, {Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: fixtureState());
    final connection = SessionConnection.local(host, game: fixtureGame());
    addTearDown(connection.dispose);
    for (final command in commands) {
      host.dispatch(command);
    }
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(brightness),
      home: Scaffold(
        appBar: AppBar(title: const Text("Quiz night")),
        body: ControllerView(
          connection: connection,
          games: const Stream<List<GameSummary>>.empty(),
          onConnectDevices: () {},
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The presenter as on a 16:9 screen.
  Future<void> screen(WidgetTester tester, List<Command> commands) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: fixtureState());
    final connection = SessionConnection.local(host, game: fixtureGame());
    addTearDown(connection.dispose);
    for (final command in commands) {
      host.dispatch(command);
    }
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.dark),
      home: Scaffold(body: PresenterView(connection: connection)),
    ));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> shot(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/$name.png'));

  Future<void> tapText(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('controller: board', (tester) async {
    await phone(tester, const [AdjustPoints('red', 300), OpenQuestion(free), CloseQuestion(), AdjustPoints('blue', 100)]);
    await shot('controller_board');
  });

  testWidgets('controller: board sheet', (tester) async {
    await phone(tester, const [OpenQuestion(free), CloseQuestion()]);
    await tapText(tester, find.widgetWithText(TextButton, 'Board'));
    await tapText(tester, find.widgetWithText(FilledButton, '200').first);
    await shot('controller_board_sheet');
  });

  testWidgets('controller: answering', (tester) async {
    await phone(tester, const [SetQueueBuzzers(true), OpenQuestion(abcd), Reveal(1), Reveal(1), Buzz('red'), Buzz('blue')]);
    await shot('controller_answering');
  });

  testWidgets('controller: feud, dark', (tester) async {
    await phone(
      tester,
      const [OpenQuestion(feud), Buzz('blue'), FeudToggle(0), FeudToggle(2), FeudWrong()],
      brightness: Brightness.dark,
    );
    await shot('controller_feud');
  });

  testWidgets('controller: team sheet', (tester) async {
    await phone(tester, const [OpenQuestion(free)]);
    await tapText(tester, find.text('Red'));
    await shot('controller_team_sheet');
  });

  testWidgets('controller: setup sheet', (tester) async {
    await phone(tester, const []);
    await tapText(tester, find.widgetWithText(TextButton, 'Setup'));
    await shot('controller_setup_sheet');
  });

  testWidgets('presenter: board', (tester) async {
    await screen(tester, const [AdjustPoints('red', 300), OpenQuestion(free), CloseQuestion(), AdjustPoints('blue', 100)]);
    await shot('presenter_board');
  });

  testWidgets('presenter: abcd', (tester) async {
    await screen(tester, const [OpenQuestion(abcd), Reveal(1), Reveal(1), Reveal(1), Buzz('red')]);
    await shot('presenter_abcd');
  });

  testWidgets('presenter: feud', (tester) async {
    await screen(tester, const [OpenQuestion(feud), Buzz('blue'), FeudToggle(0), FeudToggle(2), FeudWrong()]);
    await shot('presenter_feud');
  });
}
