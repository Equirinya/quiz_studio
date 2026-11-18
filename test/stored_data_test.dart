import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/pages/stored_data_page.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

/// The stored data of a session, and reopening a played question with its
/// answers from the controller's board.
void main() {
  final game = fixtureGame();

  /// `sum` played on whiteboards: red right (400), blue wrong; `free` won
  /// by blue on the buzzer.
  SessionHost played() {
    final host = SessionHost(initial: fixtureState(), game: game, clock: () => 1000);
    addTearDown(host.dispose);
    for (final command in <Command>[
      const OpenQuestion(sum),
      const SubmitAnswer('red', PlayerAnswer(drawing: '1,1 2,2')),
      const SubmitAnswer('blue', PlayerAnswer(drawing: '5,5 6,6')),
      const RevealAnswer('red'),
      const RateAnswer('red', correct: true),
      const CloseQuestion(),
      const OpenQuestion(free),
      const Buzz('blue'),
      const Judge(correct: true),
    ]) {
      expect(host.dispatch(command), isTrue, reason: '${command.toJson()}');
    }
    return host;
  }

  testWidgets('stored data: the points, the questions played, and each team\'s kept answer', (tester) async {
    final host = played();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StoredDataView(state: host.state, rounds: host.rounds, game: game)),
      ),
    );
    expect(find.text('Red'), findsOneWidget);
    expect(find.text('400'), findsWidgets);
    expect(find.text('Capital of France?'), findsOneWidget);
    expect(find.text('What is 3+5?'), findsOneWidget);
    expect(find.textContaining('answers kept'), findsOneWidget);

    await tester.tap(find.text('What is 3+5?'));
    await tester.pumpAndSettle();
    expect(find.byType(DrawingView), findsNWidgets(2));
    expect(find.text('+400'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('not rated'), findsOneWidget, reason: 'blue drew but was not rated');
  });

  testWidgets('nothing played yet', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StoredDataView(state: fixtureState(), rounds: const {}, game: game))));
    expect(find.textContaining('Nothing stored yet'), findsOneWidget);
  });

  testWidgets('a played question with kept answers reopens with them from the board', (tester) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = played();
    final connection = SessionConnection.local(host, game: game);
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ControllerView(connection: connection))));
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Board'));
    await tester.pump(const Duration(milliseconds: 400));
    // The buzzer question kept nothing: no second option.
    await tester.tap(find.widgetWithText(FilledButton, '100').first);
    await tester.pump();
    expect(find.text('Capital of France?'), findsOneWidget);
    expect(find.byKey(const Key('reopenWithAnswers')), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '400').first);
    await tester.pump();
    expect(find.text('What is 3+5?'), findsOneWidget);
    expect(find.textContaining('answers kept'), findsOneWidget);
    expect(find.text('Mark as not played'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reopenWithAnswers')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(host.state.current, sum);
    expect(host.state.answerRound!.answers['blue']!.drawing, '5,5 6,6');
  });
}
