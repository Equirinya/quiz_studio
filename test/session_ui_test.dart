import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/pages/screen_overlays.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

/// Controller and presenter side by side on one local session, the way the
/// presenting device shows them.
void main() {
  late SessionHost host;
  late SessionConnection connection;

  Future<void> pumpBoth(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2000, 1400);
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
              width: 460,
              child: ControllerView(connection: connection),
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
  Finder inSheet(Finder finder) => find.descendant(of: find.byType(BottomSheet), matching: finder);
  Finder tab(String label) => inController(find.widgetWithText(TextButton, label));
  Finder pad(String label) => inController(find.widgetWithText(FilledButton, label));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(1000, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  bool enabled(WidgetTester tester, String label) => tester.widget<FilledButton>(pad(label)).onPressed != null;

  testWidgets('the board is a sheet: tap a field to read it, then open it', (tester) async {
    await pumpBoth(tester);
    await tap(tester, tab('Board'));
    await tap(tester, inSheet(find.widgetWithText(FilledButton, '100')).first);
    expect(host.state.current, isNull);
    expect(inSheet(find.text('Capital of France?')), findsOneWidget);
    expect(inSheet(find.text('Paris')), findsOneWidget);
    expect(inPresenter(find.text('Capital of France?')), findsNothing);

    await tap(tester, inSheet(find.text('Open question')));
    expect(host.state.current, free);
    expect(find.byType(BottomSheet), findsNothing);
    expect(inPresenter(find.text('Capital of France?')), findsOneWidget);
    // The gamemaster sees the answer hint, the audience never does.
    expect(inController(find.text('Paris')), findsOneWidget);
    expect(inPresenter(find.text('Paris')), findsNothing);
  });

  testWidgets('the pad never moves; buttons switch off instead', (tester) async {
    await pumpBoth(tester);
    const labels = ['Right', 'Wrong', 'Close', 'Hide', 'Reveal', 'Play', 'Reopen'];
    final before = {for (final label in labels) label: tester.getRect(pad(label))};
    expect(labels.where((label) => enabled(tester, label)), isEmpty);

    host
      ..dispatch(const OpenQuestion(abcd))
      ..dispatch(const Buzz('red'));
    await tester.pump();
    for (final label in labels) {
      expect(tester.getRect(pad(label)), before[label], reason: label);
    }
    expect(labels.where((label) => enabled(tester, label)), ['Right', 'Wrong', 'Close', 'Reveal', 'Reopen']);
  });

  testWidgets('buzz for a team from its sheet, then judge right', (tester) async {
    await pumpBoth(tester);
    host.dispatch(const OpenQuestion(free));
    await tester.pump();

    await tap(tester, inController(find.text('Red')));
    await tap(tester, inSheet(find.text('Buzz for this team')));
    expect(host.state.buzzQueue, ['red']);
    expect(inController(find.text('Red is answering')), findsOneWidget);

    await tap(tester, pad('Right'));
    expect(host.state.phase, Phase.overview);
    expect(host.state.team('red')!.points, 100);
    expect(inPresenter(find.text('Capital of France?')), findsNothing);
  });

  testWidgets('points are adjusted in the team sheet', (tester) async {
    await pumpBoth(tester);
    await tap(tester, inController(find.text('Blue')));
    await tap(tester, inSheet(find.text('+100')));
    await tap(tester, inSheet(find.text('−10')));
    expect(host.state.team('blue')!.points, 90);
    expect(inSheet(find.text('90')), findsOneWidget);
    expect(inSheet(find.widgetWithText(FilledButton, 'Buzz for this team')), findsOneWidget);
    expect(tester.widget<FilledButton>(inSheet(find.widgetWithText(FilledButton, 'Buzz for this team'))).onPressed, isNull);
  });

  testWidgets('abcd answers appear on the big screen as they are revealed', (tester) async {
    await pumpBoth(tester);
    host.dispatch(const OpenQuestion(abcd));
    await tester.pump();
    expect(inPresenter(find.text('a')), findsNothing);

    await tap(tester, pad('Reveal'));
    expect(inPresenter(find.text('a')), findsOneWidget);
    expect(inPresenter(find.text('b')), findsNothing);
    expect(inController(find.textContaining('B  b')), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tap(tester, pad('Reveal'));
    }
    // One step is left: showing which answers are right.
    await tap(tester, pad('Solution'));
    expect(host.state.revealed, 5);
  });

  testWidgets('feud: uncover an answer, three strikes, steal', (tester) async {
    await pumpBoth(tester);
    host
      ..dispatch(const OpenQuestion(feud))
      ..dispatch(const Buzz('red'));
    await tester.pump();
    expect(enabled(tester, 'Right'), isFalse);

    await tap(tester, inController(find.text('apple')));
    expect(inPresenter(find.text('apple')), findsOneWidget);
    expect(inPresenter(find.text('banana')), findsNothing);

    for (var i = 0; i < 3; i++) {
      await tap(tester, pad('Strike'));
    }
    expect(host.state.wrongAttempts, 3);
    await tap(tester, pad('Steal worked'));
    expect(host.state.team('blue')!.points, 500);
    expect(inPresenter(find.text('banana')), findsOneWidget);
  });

  testWidgets('setup holds the rarely used switches', (tester) async {
    await pumpBoth(tester);
    await tap(tester, tab('Setup'));
    await tap(tester, inSheet(find.text('Queue buzzers')));
    expect(host.state.queueBuzzers, isTrue);
    await tap(tester, inSheet(find.text('Buzzer test')));
    expect(host.state.phase, Phase.buzzerTest);
  });

  testWidgets('the group is switched on the board sheet, but not under an open question', (tester) async {
    await pumpBoth(tester);
    await tap(tester, tab('Board'));
    await tap(tester, inSheet(find.text('Finale')));
    expect(host.state.groupId, 'g2');
    await closeSheet(tester);

    host.dispatch(const OpenQuestion(feud));
    await tester.pump();
    await tap(tester, tab('Board'));
    await tap(tester, inSheet(find.text('Round 1')));
    expect(host.state.groupId, 'g2');
  });

  testWidgets('the whiteboard scenario: watch, lock, show one by one, rate', (tester) async {
    await pumpBoth(tester);
    host.dispatch(const OpenQuestion(sum));
    await tester.pump();
    // The round started with the question; nothing is on the big screen yet.
    expect(host.state.answerRound!.kind, CompanionKind.whiteboard);
    expect(inController(find.byType(DrawingView)), findsNothing);

    host
      ..dispatch(SubmitAnswer('red', PlayerAnswer(drawing: encodeDrawing([[(0.2, 0.2), (0.8, 0.8)]]))))
      ..dispatch(SubmitAnswer('blue', PlayerAnswer(drawing: encodeDrawing([[(0.5, 0.1), (0.5, 0.9)]]))));
    await tester.pump();
    // The gamemaster sees both boards while they are being written.
    expect(inController(find.byType(DrawingView)), findsNWidgets(2));
    expect(inPresenter(find.byType(DrawingView)), findsNothing);

    // The pad's reveal button now walks through the teams' answers.
    await tap(tester, pad('Show answer'));
    expect(host.state.answerRound!.revealed, ['red']);
    expect(host.state.answerRound!.open, isFalse);
    expect(inPresenter(find.byType(DrawingView)), findsOneWidget);
    await tap(tester, pad('Show answer'));
    expect(inPresenter(find.byType(DrawingView)), findsNWidgets(2));
    expect(enabled(tester, 'Show answer'), isFalse);
    await tap(tester, pad('Hide'));
    expect(host.state.answerRound!.revealed, ['red']);

    // Right for red, wrong for blue, each on its own card.
    await tester.ensureVisible(inController(find.byTooltip('Right')).first);
    await tap(tester, inController(find.byTooltip('Right')).first);
    await tester.ensureVisible(inController(find.byTooltip('Wrong')).last);
    await tap(tester, inController(find.byTooltip('Wrong')).last);
    expect(host.state.team('red')!.points, 400);
    expect(host.state.team('blue')!.points, 0);
    expect(host.state.answerRound!.verdicts, {'red': true, 'blue': false});
    // Changing one's mind does not count twice.
    await tap(tester, inController(find.byTooltip('Right')).first);
    expect(host.state.team('red')!.points, 0);
  });

  testWidgets('a round can be started by hand, with a timer, from the Answers sheet', (tester) async {
    await pumpBoth(tester);
    host.dispatch(const OpenQuestion(estimate));
    await tester.pump();
    await tap(tester, tab('Answers'));
    await tap(tester, inSheet(find.text('30 s')));
    await tap(tester, inSheet(find.text('Number')));
    final round = host.state.answerRound!;
    expect((round.kind, round.spec.timerSeconds, round.endsAtMillis != null), (CompanionKind.number, 30, true));

    host.dispatch(const SubmitAnswer('red', PlayerAnswer(number: 42)));
    await tester.pump();
    expect(inController(find.text('42')), findsOneWidget);
    expect(inPresenter(find.text('42')), findsNothing);
    await tap(tester, pad('Show answer'));
    expect(inPresenter(find.text('42')), findsOneWidget);
  });

  testWidgets('a text typed in the effects sheet goes over the screen and comes off again', (tester) async {
    await pumpBoth(tester);
    await tap(tester, tab('Effects'));
    await tester.enterText(inSheet(find.byType(TextField)), 'Back in ten minutes');
    await tap(tester, inSheet(find.text('Show')));
    expect(host.state.overlay!.text, 'Back in ten minutes');
    expect(inPresenter(find.text('Back in ten minutes')), findsOneWidget);

    await tap(tester, inSheet(find.text('Take card off screen')));
    expect(host.state.overlay, isNull);
    await tester.pump(const Duration(milliseconds: 500));
    expect(inPresenter(find.text('Back in ten minutes')), findsNothing);
  });

  testWidgets('confetti runs on the presenter and ends by itself', (tester) async {
    await pumpBoth(tester);
    expect(inPresenter(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ConfettiPainter)), findsNothing);
    await tap(tester, tab('Effects'));
    await tap(tester, inSheet(find.text('Confetti')));
    expect(inPresenter(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ConfettiPainter)), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(inPresenter(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ConfettiPainter)), findsNothing);
  });
}
