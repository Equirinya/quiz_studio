import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/player/pages/player_page.dart';
import 'package:quiz_show/features/player/widgets/buzzer_button.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

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

  testWidgets('a text answer is sent, can be changed, and closes when locked', (tester) async {
    host
      ..dispatch(const OpenQuestion(estimate))
      ..dispatch(const OpenAnswers(AnswerKind.text));
    await pumpPlayer(tester);
    expect(find.byType(BuzzerButton), findsNothing);

    await tester.enterText(find.byType(TextField), ' 42 ');
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(host.state.answerRound!.answers['red']!.text, '42');
    expect(find.text('Send again'), findsOneWidget);

    host.dispatch(const LockAnswers());
    await tester.pump();
    expect(find.text('Your answer is in.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a choice answer offers the question\'s options', (tester) async {
    host
      ..dispatch(const OpenQuestion(abcd))
      ..dispatch(const Reveal(1))
      ..dispatch(const OpenAnswers(AnswerKind.choice));
    await pumpPlayer(tester, teamId: 'blue');
    // Revealed options carry their text, the others only their letter.
    expect(find.text('A   a'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    await tester.tap(find.text('C'));
    await tester.pump();
    expect(host.state.answerRound!.answers['blue']!.choice, 2);
  });

  testWidgets('a removed team is told so', (tester) async {
    await pumpPlayer(tester);
    host.dispatch(const RemoveTeam('red'));
    await tester.pump();
    expect(find.text('Your team was removed from the session.'), findsOneWidget);
  });
}
