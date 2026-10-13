import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('answers from devices are collected, read and shown from their sheet', (tester) async {
    await pumpBoth(tester);
    host.dispatch(const OpenQuestion(estimate));
    await tester.pump();
    await tap(tester, tab('Answers'));
    await tap(tester, inSheet(find.text('Text')));
    expect(host.state.answerRound!.kind, AnswerKind.text);

    host.dispatch(const SubmitAnswer('red', PlayerAnswer(text: 'forty-two')));
    await tester.pump();
    expect(inSheet(find.text('forty-two')), findsOneWidget);
    expect(inPresenter(find.text('forty-two')), findsNothing);

    await tap(tester, inSheet(find.text('Show on screen')));
    expect(inPresenter(find.text('forty-two')), findsOneWidget);
  });
}
