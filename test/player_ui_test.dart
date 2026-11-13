import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/companion/answer_view.dart';
import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/features/player/pages/player_page.dart';
import 'package:quiz_show/features/player/widgets/buzzer_button.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';
import 'game/rapid_fixture.dart';

/// A player's phone fed from a local host, with its commands going back in
/// under the player's own (restricted) sender.
void main() {
  late SessionHost host;
  final game = fixtureGame();

  Future<void> pumpPlayer(WidgetTester tester, {String teamId = 'red'}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StreamBuilder<SessionState>(
          stream: host.states,
          builder: (context, _) => PlayerView(
            view: PublicView(host.publicState),
            teamId: teamId,
            send: (command) => host.dispatch(command, sender: Sender(Role.player, teamId: teamId)),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  setUp(() => host = SessionHost(initial: fixtureState(), game: game));
  tearDown(() => host.dispose());

  bool buzzerEnabled(WidgetTester tester) => tester.widget<BuzzerButton>(find.byType(BuzzerButton)).onPressed != null;

  testWidgets('the buzzer is live only while buzzing counts', (tester) async {
    await pumpPlayer(tester);
    expect(find.text('Waiting for the next question'), findsOneWidget);
    expect(buzzerEnabled(tester), isFalse);

    host.dispatch(const OpenQuestion(free));
    await tester.pump();
    expect(find.text('Buzz when you know it!'), findsOneWidget);
    expect(find.text('Capital of France?'), findsOneWidget);
    expect(find.text('Paris'), findsNothing);
    expect(buzzerEnabled(tester), isTrue);

    host.dispatch(const CloseQuestion());
    host.dispatch(const OpenQuestion(estimate));
    await tester.pump();
    expect(find.text('No buzzers for this question'), findsOneWidget);
    expect(buzzerEnabled(tester), isFalse);
  });

  testWidgets('pressing it buzzes for the own team', (tester) async {
    host.dispatch(const OpenQuestion(free));
    await pumpPlayer(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(BuzzerButton)));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(seconds: 3));
    expect(host.state.buzzQueue, ['red']);
    expect(find.text('Your turn!'), findsOneWidget);
    expect(buzzerEnabled(tester), isFalse);
  });

  testWidgets('shows who is answering and the place in the queue', (tester) async {
    host
      ..dispatch(const SetQueueBuzzers(true))
      ..dispatch(const OpenQuestion(free))
      ..dispatch(const Buzz('blue'));
    await pumpPlayer(tester);
    expect(find.text('Blue is answering'), findsOneWidget);
    expect(buzzerEnabled(tester), isTrue);

    host.dispatch(const Buzz('red'));
    await tester.pump();
    expect(find.text('You are number 2 in line'), findsOneWidget);
    expect(buzzerEnabled(tester), isFalse);
  });

  testWidgets('without a timer the answer counts when the round ends; no locking in early', (tester) async {
    host
      ..dispatch(const OpenQuestion(estimate))
      ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.text)));
    await pumpPlayer(tester);
    expect(find.text('Lock in answer'), findsNothing);
    expect(find.text('Your answer counts as it stands when the gamemaster ends the round.'), findsOneWidget);
  });

  testWidgets('a text answer goes out as it is typed, and can be locked in when scored fastest first', (tester) async {
    host
      ..dispatch(const OpenQuestion(race))
      ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.text, timerSeconds: 60)));
    await pumpPlayer(tester);
    expect(find.byType(BuzzerButton), findsNothing);
    expect(find.text('Answer first'), findsOneWidget);

    await tester.enterText(find.byType(TextField), ' 42 ');
    await tester.pump(const Duration(seconds: 1));
    expect(host.state.answerRound!.answers['red']!.text, '42');

    await tester.tap(find.text('Lock in answer'));
    await tester.pump();
    expect(host.state.answerRound!.answers['red']!.locked, isTrue);
    expect(find.text('Locked in'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    // Ends the round, and its clock with it.
    host.dispatch(const ClearAnswers());
  });

  testWidgets('a question with a whiteboard opens it on the device by itself', (tester) async {
    host.dispatch(const OpenQuestion(sum));
    await pumpPlayer(tester);
    expect(find.text('What is 3+5?'), findsOneWidget);
    expect(find.byType(WhiteboardPad), findsOneWidget);
    expect(find.byType(BuzzerButton), findsNothing);
    expect(find.byType(RoundCountdown), findsOneWidget);

    // One stroke across the board.
    final board = tester.getRect(find.descendant(of: find.byType(WhiteboardPad), matching: find.byType(CustomPaint)).first);
    await tester.dragFrom(board.center - const Offset(60, 0), const Offset(120, 30));
    await tester.pump();
    final drawing = host.state.answerRound!.answers['red']!.drawing;
    expect(decodeDrawing(drawing), hasLength(1));

    host.dispatch(const LockAnswers());
    await tester.pump();
    expect(find.text('Time is up'), findsOneWidget);
    // The gamemaster rules it right and shows it.
    host
      ..dispatch(const RevealAnswer('red'))
      ..dispatch(const RateAnswer('red', correct: true));
    await tester.pump();
    expect(find.text('Right!'), findsOneWidget);
    expect(find.text('Your answer is on the big screen.'), findsOneWidget);
  });

  testWidgets('a choice answer offers the options', (tester) async {
    host
      ..dispatch(const OpenQuestion(abcd))
      ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.choice, options: ['a', 'b', 'c', 'd'])));
    await pumpPlayer(tester, teamId: 'blue');
    await tester.tap(find.text('c'));
    await tester.pump();
    expect(host.state.answerRound!.answers['blue']!.choice, 2);
  });

  testWidgets('with several allowed, picks are ticked on and off', (tester) async {
    host
      ..dispatch(const OpenQuestion(abcd))
      ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.choice, options: ['a', 'b', 'c', 'd'], multiple: true)));
    await pumpPlayer(tester, teamId: 'blue');
    await tester.tap(find.text('c'));
    await tester.pump();
    await tester.tap(find.text('a'));
    await tester.pump();
    expect(host.state.answerRound!.answers['blue']!.choices, [0, 2]);
    await tester.tap(find.text('c'));
    await tester.pump();
    expect(host.state.answerRound!.answers['blue']!.choices, [0]);
    expect(find.byIcon(Icons.check_box), findsOneWidget);
  });

  testWidgets('a slider answers with a number on its step', (tester) async {
    host
      ..dispatch(const OpenQuestion(estimate))
      ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.slider, min: 0, max: 100, step: 5, unit: 'm')));
    await pumpPlayer(tester);
    expect(find.text('Slide to answer'), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pump();
    final number = host.state.answerRound!.answers['red']!.number!;
    expect(number % 5, 0);
    expect(number, greaterThan(50));
  });

  testWidgets('sorting sends the order as shown from the start, as original indices', (tester) async {
    host
      ..dispatch(const OpenQuestion(estimate))
      ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.order, options: ['one', 'two', 'three'])));
    await pumpPlayer(tester);
    for (final text in ['one', 'two', 'three']) {
      expect(find.text(text), findsOneWidget);
    }
    // No button needed: the team can lock this order in as it is.
    await tester.pump();
    expect(find.text('This order is right'), findsNothing);
    final order = host.state.answerRound!.answers['red']!.order!;
    expect(order.toSet(), {0, 1, 2});
    // The device got them shuffled, so "as shown" is not the right order.
    expect(order, isNot([0, 1, 2]));
  });

  testWidgets('matching keeps the team\'s pairs on screen once locked, and follows another phone', (tester) async {
    final films = matchingGame();
    host.dispose();
    host = SessionHost(initial: fixtureState(), game: films);
    host
      ..dispatch(const OpenQuestion(matchingRound))
      // No time limit: then the question line shows up above the board on locking.
      ..dispatch(const ExtendAnswers(null));
    expect(host.state.answerRound!.endsAtMillis, isNull);
    const red = Sender(Role.player, teamId: 'red');
    // An upright phone.
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The phone as it really is: with its own team's answer in the view.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StreamBuilder<SessionState>(
          stream: host.states,
          builder: (context, _) => PlayerView(
            view: PublicView(publicView(host.state, films, teamId: 'red')),
            teamId: 'red',
            send: (command) => host.dispatch(command, sender: red),
          ),
        ),
      ),
    ));
    await tester.pump();

    // 1985 onto the first film.
    await tester.tap(find.text('1985'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(host.state.answerRound!.answers['red']!.pairs, [0, -1, -1, -1]);
    expect(find.text('1 / 4'), findsOneWidget);

    // Another phone of the team adds 1993 to the second.
    host.dispatch(const SubmitAnswer('red', PlayerAnswer(pairs: [0, 1, -1, -1])), sender: red);
    await tester.pump();
    expect(find.text('2 / 4'), findsOneWidget);

    // The gamemaster locks all: the pairs stay, the rest goes.
    host.dispatch(const LockAnswers());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('1985'), findsOneWidget);
    expect(find.text('1993'), findsOneWidget);
    expect(find.text('1977'), findsNothing);
    host.dispatch(const ClearAnswers());
  });

  testWidgets('a removed team is told so', (tester) async {
    await pumpPlayer(tester);
    host.dispatch(const RemoveTeam('red'));
    await tester.pump();
    expect(find.text('Your team was removed from the session.'), findsOneWidget);
  });
}
