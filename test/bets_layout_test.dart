import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/betting_fixture.dart';

/// Where the bets are shown: beside each team's answer on the controller,
/// and on one line however many points on the big screen.
void main() {
  Future<SessionHost> pump(WidgetTester tester, Size size, Widget Function(SessionConnection) build, List<Command> commands) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = SessionHost(initial: bettingState(), game: bettingGame());
    addTearDown(host.dispose);
    for (final command in commands) {
      expect(host.dispatch(command), isTrue, reason: 'rejected: ${command.toJson()}');
    }
    final connection = SessionConnection.local(host, game: bettingGame());
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: build(connection))));
    await tester.pump(const Duration(seconds: 3));
    return host;
  }

  testWidgets('how many a team bet it can name sits beside its name on its answer, not on top', (tester) async {
    final host = await pump(tester, const Size(460, 1600), (c) => ControllerView(connection: c), const [
      OpenQuestion(films),
      PlaceBet('red', 7),
      PlaceBet('blue', 2),
      CloseBets(),
      StartQuestion(),
    ]);
    final red = find.byKey(const ValueKey('bet-red'));
    expect(red, findsOneWidget);
    expect(find.descendant(of: red, matching: find.textContaining('7')), findsOneWidget);
    final row = find.ancestor(of: red, matching: find.byType(Row)).first;
    expect(find.descendant(of: row, matching: find.textContaining('Red')), findsOneWidget, reason: 'on the line of its name');
    expect(find.textContaining('Red · 7'), findsNothing, reason: 'no list of bets on top any more');
    // The answer clock, stopped before the test ends.
    host.dispatch(const CloseQuestion());
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bets of more than 1000 points stay on one line on the big screen', (tester) async {
    await pump(tester, const Size(1600, 900), (c) => PresenterView(connection: c), const [
      OpenQuestion(picked),
      AdjustPoints('red', 2000),
      PlaceBet('red', 1500),
      PlaceBet('blue', 100),
      CloseBets(),
    ]);
    final bet = find.text('1500');
    expect(bet, findsOneWidget);
    final style = tester.widget<Text>(bet).style!;
    expect(tester.getSize(bet).height, lessThan(style.fontSize! * 1.6), reason: 'one line');
    expect(tester.takeException(), isNull);
  });
}
