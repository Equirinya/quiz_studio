import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/last_standing_test.dart' show disney, standingGame, teams;

/// Last team standing ended from the controller with several teams still in.
void main() {
  testWidgets('End on the controller ends it; the big screen shows every team still in', (tester) async {
    tester.view
      ..physicalSize = const Size(460, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = standingGame();
    final host = SessionHost(initial: teams(), game: game);
    addTearDown(host.dispose);
    host
      ..dispatch(const OpenQuestion(disney))
      ..dispatch(const StartTurns())
      ..dispatch(const TakeTurn(StandingResult.out));
    final connection = SessionConnection.local(host, game: game);
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ControllerView(connection: connection))));
    await tester.pump();

    final end = find.byKey(const ValueKey('endTurns'));
    await tester.ensureVisible(end);
    await tester.tap(end);
    await tester.pump();
    expect(host.state.standing!.winners, ['blue', 'green']);
    expect(find.textContaining('Blue, Green'), findsOneWidget, reason: 'the panel says who is still in');

    tester.view.physicalSize = const Size(1600, 900);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PresenterView(connection: connection))));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Blue · Green'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
