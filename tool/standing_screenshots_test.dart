// Last team standing on every screen. Writes tool/screenshots/standing/.
//
//   flutter test tool/standing_screenshots_test.dart --update-goldens

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

import '../test/game/last_standing_test.dart' show standingGame, biopics, teams;

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

  late SessionHost host;
  const midGame = [OpenQuestion(biopics), TakeTurn(StandingResult.right), TakeTurn(StandingResult.out)];

  Future<SessionConnection> start(WidgetTester tester, Size size, List<Command> commands) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: teams());
    final connection = SessionConnection.local(host, game: standingGame());
    addTearDown(connection.dispose);
    for (final command in commands) {
      host.dispatch(command);
    }
    return connection;
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/standing/$name.png'));
    expect(tester.takeException(), isNull);
  }

  testWidgets('controller on a phone', (tester) async {
    final connection = await start(tester, const Size(412, 892), midGame);
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
    await shot(tester, 'controller');
  });

  for (final (name, commands) in [
    ('presenter', midGame),
    ('presenter_winner', [...midGame, const TakeTurn(StandingResult.out)]),
  ]) {
    testWidgets(name, (tester) async {
      final connection = await start(tester, const Size(1600, 900), commands);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.dark),
          home: Scaffold(body: PresenterView(connection: connection)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await shot(tester, name);
      await tester.pump(const Duration(seconds: 4));
    });
  }

  testWidgets('a phone on its turn', (tester) async {
    await start(tester, const Size(412, 892), midGame);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: SafeArea(
            child: PlayerView(view: PublicView(host.publicStateFor('green')), teamId: 'green', send: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, 'player_turn');
  });

  testWidgets('the editor', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final question = standingGame().question(biopics)!;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          appBar: AppBar(title: const Text("Biopics")),
          body: ListView(
            padding: const EdgeInsets.all(8),
            children: [QuestionCard(gameId: 'g', categoryId: 'c', question: question, initiallyExpanded: true)],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'editor');
  });
}
