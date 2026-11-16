import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/top_answers_fixture.dart';

void main() {
  Future<SessionHost> pumpController(WidgetTester tester, GameContent game) async {
    tester.view
      ..physicalSize = const Size(600, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = SessionHost(initial: topTeams);
    final connection = SessionConnection.local(host, game: game);
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ControllerView(connection: connection))));
    await tester.pump();
    return host;
  }

  Finder pad(String label) => find.widgetWithText(FilledButton, label);

  testWidgets('Next uncovers the top answers from the bottom, not the teams\' answers', (tester) async {
    final host = await pumpController(tester, topAnswersGame(mode: TopAnswersMode.typed));
    host.dispatch(const OpenQuestion(films));
    await tester.pump();
    // The teams are still typing: Next first closes answering.
    await tester.tap(pad('Lock all'));
    await tester.pump();
    expect(host.state.answerRound!.open, isFalse);
    await tester.tap(pad('Reveal'));
    await tester.pump();
    expect(host.state.feudRevealed, [4]);
    await tester.tap(pad('Reveal'));
    await tester.pump();
    expect(host.state.feudRevealed, [4, 3]);
    expect(host.state.answerRound!.revealed, isEmpty);
  });

  testWidgets('while a team answers, Next uncovers nothing', (tester) async {
    final host = await pumpController(tester, topAnswersGame());
    host
      ..dispatch(const OpenQuestion(films))
      ..dispatch(const Buzz('red'));
    await tester.pump();
    expect(host.state.phase, Phase.buzzered);
    expect(tester.widget<FilledButton>(pad('Reveal')).onPressed, isNull);
  });
}
