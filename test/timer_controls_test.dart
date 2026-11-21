import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

/// One set of timer buttons on the controller's main panel, for the
/// question's own clock or the devices' round, whichever the question has.
void main() {
  Future<SessionHost> pump(WidgetTester tester, List<Command> commands) async {
    tester.view
      ..physicalSize = const Size(460, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = fixtureGame();
    final host = SessionHost(initial: fixtureState(), game: game);
    addTearDown(host.dispose);
    commands.forEach(host.dispatch);
    final connection = SessionConnection.local(host, game: game);
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ControllerView(connection: connection))));
    await tester.pump();
    return host;
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final button = find.byKey(ValueKey(key));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  bool enabled(WidgetTester tester, String key) => tester.widget<ActionChip>(find.byKey(ValueKey(key))).onPressed != null;

  testWidgets('the question\'s own clock: more, less, pause and on, and none', (tester) async {
    final host = await pump(tester, const [OpenQuestion(free)]);
    expect(enabled(tester, 'timerLess'), isFalse, reason: 'no clock yet');
    expect(enabled(tester, 'pauseTimer'), isFalse);
    await tap(tester, 'timerMore60');
    final ends = host.state.timer!.endsAtMillis;
    await tap(tester, 'timerLess');
    expect(host.state.timer!.endsAtMillis, ends - 30000);
    await tap(tester, 'pauseTimer');
    expect(host.state.timer!.paused, isTrue);
    expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget, reason: 'the countdown stands still');
    await tap(tester, 'pauseTimer');
    expect(host.state.timer!.paused, isFalse);
    await tap(tester, 'stopTimer');
    expect(host.state.timer, isNull);
  });

  testWidgets('with a round on the devices the same buttons act on its timer', (tester) async {
    final host = await pump(tester, const [OpenQuestion(estimate), OpenAnswers(CompanionSpec(kind: CompanionKind.text, timerSeconds: 60))]);
    final ends = host.state.answerRound!.endsAtMillis!;
    await tap(tester, 'timerMore30');
    expect(host.state.answerRound!.endsAtMillis, ends + 30000);
    expect(host.state.timer, isNull, reason: 'not a question clock beside it');
    await tap(tester, 'timerLess');
    expect(host.state.answerRound!.endsAtMillis, ends);
    await tap(tester, 'pauseTimer');
    expect(host.state.answerRound!.timerPaused, isTrue);
    await tap(tester, 'pauseTimer');
    expect(host.state.answerRound!.timerPaused, isFalse);
    await tap(tester, 'noTimeLimit');
    expect(host.state.answerRound!.endsAtMillis, isNull);
    expect(enabled(tester, 'noTimeLimit'), isFalse);
    expect(enabled(tester, 'pauseTimer'), isFalse);
    // Let edit again after the time: a fresh minute from now.
    host
      ..dispatch(const LockAnswers())
      ..dispatch(const UnlockAnswers());
    await tester.pump();
    await tap(tester, 'timerMore60');
    expect(host.state.answerRound!.endsAtMillis, isNotNull);
    expect(host.state.answerRound!.open, isTrue);
    // The host's deadline goes with the round.
    host.dispatch(const ClearAnswers());
    await tester.pumpWidget(const SizedBox());
  });
}
