import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

/// Controller and presenter side by side on one local session, the way the
/// presenting device shows them.
void main() {
  late SessionHost host;
  late SessionConnection connection;

  Future<void> pumpBoth(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: fixtureState());
    connection = SessionConnection.local(host, game: fixtureGame());
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 700,
              child: ControllerView(connection: connection, games: const Stream<List<GameSummary>>.empty()),
            ),
            Expanded(child: PresenterView(connection: connection)),
          ],
        ),
      ),
    ));
    await tester.pump();
  }

  Finder inController(Finder finder) => find.descendant(of: find.byType(ControllerView), matching: finder);
  Finder inPresenter(Finder finder) => find.descendant(of: find.byType(PresenterView), matching: finder);

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a question is previewed on the first tap and opened on the second', (tester) async {
    await pumpBoth(tester);
    expect(inPresenter(find.text('Capital of France?')), findsNothing);

    await tap(tester, inController(find.widgetWithText(FilledButton, '100')).first);
    expect(host.state.current, isNull);
    expect(inController(find.text('Capital of France?')), findsOneWidget);
    expect(inController(find.text('Paris')), findsOneWidget);
    expect(inPresenter(find.text('Capital of France?')), findsNothing);

    await tap(tester, inController(find.widgetWithText(FilledButton, '100')).first);
    expect(host.state.current, free);
    expect(inPresenter(find.text('Capital of France?')), findsOneWidget);
    // The audience never sees the answer hint.
    expect(inPresenter(find.text('Paris')), findsNothing);
  });

  testWidgets('buzz, judge right: points land on both screens and the board returns', (tester) async {
    await pumpBoth(tester);
    host.dispatch(const OpenQuestion(free));
    await tester.pump();

    await tap(tester, inController(find.widgetWithText(FilledButton, 'Red')));
    expect(host.state.buzzQueue, ['red']);
    await tap(tester, inController(find.widgetWithText(FilledButton, 'Right')));

    expect(host.state.phase, Phase.overview);
    expect(host.state.team('red')!.points, 100);
    expect(inPresenter(find.text('100')), findsWidgets);
    expect(inPresenter(find.text('Capital of France?')), findsNothing);
  });

  testWidgets('abcd answers appear on the big screen as they are revealed', (tester) async {
    await pumpBoth(tester);
    host.dispatch(const OpenQuestion(abcd));
    await tester.pump();
    // Hidden tiles keep their place but not their text.
    expect(inPresenter(find.text('a')), findsNothing);

    await tap(tester, inController(find.widgetWithText(FilledButton, 'Reveal next')));
    expect(inPresenter(find.text('a')), findsOneWidget);
    expect(inPresenter(find.text('b')), findsNothing);
    // The gamemaster sees all of them from the start.
    expect(inController(find.textContaining('B  b')), findsOneWidget);
  });

  testWidgets('feud: uncover an answer, three strikes, steal', (tester) async {
    await pumpBoth(tester);
    host
      ..dispatch(const OpenQuestion(feud))
      ..dispatch(const Buzz('red'));
    await tester.pump();

    await tap(tester, inController(find.widgetWithText(FilterChip, '50%  apple')));
    expect(inPresenter(find.text('apple')), findsOneWidget);
    expect(inPresenter(find.text('banana')), findsNothing);

    for (var i = 0; i < 2; i++) {
      await tap(tester, inController(find.widgetWithText(FilledButton, 'Wrong answer')));
    }
    await tap(tester, inController(find.widgetWithText(FilledButton, 'Wrong · other team may steal')));
    expect(host.state.wrongAttempts, 3);
    await tap(tester, inController(find.widgetWithText(FilledButton, 'Steal succeeded')));
    expect(host.state.team('blue')!.points, 500);
    expect(inPresenter(find.text('banana')), findsOneWidget);
  });

  testWidgets('team points and the buzzer queue switch', (tester) async {
    await pumpBoth(tester);
    await tap(tester, inController(find.widgetWithText(TextButton, '+100')).first);
    await tap(tester, inController(find.widgetWithText(TextButton, '−100')).last);
    expect(host.state.team('red')!.points, 100);
    expect(host.state.team('blue')!.points, -100);

    await tap(tester, inController(find.byType(SwitchListTile)));
    expect(host.state.queueBuzzers, isTrue);
  });

  testWidgets('switching the group changes the board, but not under an open question', (tester) async {
    await pumpBoth(tester);
    await tap(tester, inController(find.text('Finale')));
    expect(host.state.groupId, 'g2');

    host.dispatch(const OpenQuestion(feud));
    await tester.pump();
    await tap(tester, inController(find.text('Round 1')));
    expect(host.state.groupId, 'g2');
  });
}
