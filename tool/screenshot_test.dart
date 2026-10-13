// Renders the session screens to PNG files for a quick look without a device:
//   flutter test tool/screenshot_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
  Future<SessionHost> pump(WidgetTester tester, List<Command> commands) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(1900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = SessionHost(initial: fixtureState());
    final connection = SessionConnection.local(host, game: fixtureGame());
    addTearDown(connection.dispose);
    for (final command in commands) {
      host.dispatch(command);
    }
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrangeAccent, brightness: Brightness.dark),
      ),
      home: Scaffold(
        body: Row(
          children: [
            SizedBox(width: 520, child: ControllerView(connection: connection, games: const Stream<List<GameSummary>>.empty())),
            const VerticalDivider(width: 1),
            Expanded(child: PresenterView(connection: connection)),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    return host;
  }

  testWidgets('board', (tester) async {
    await pump(tester, const [AdjustPoints('red', 300), OpenQuestion(free), CloseQuestion(), AdjustPoints('blue', 100)]);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/board.png'));
  });

  testWidgets('abcd', (tester) async {
    await pump(tester, const [OpenQuestion(abcd), Reveal(1), Reveal(1), Reveal(1), Buzz('red')]);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/abcd.png'));
  });

  testWidgets('feud', (tester) async {
    await pump(tester, const [OpenQuestion(feud), Buzz('blue'), FeudToggle(0), FeudToggle(2), FeudWrong()]);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/feud.png'));
  });
}
