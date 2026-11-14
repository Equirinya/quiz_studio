import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/player/pages/player_page.dart';
import 'package:quiz_show/game/game.dart';

/// A bet of points up to the team's own points, on its phone.
void main() {
  final game = GameContent.assemble(
    id: 'game',
    game: const {'name': 'Bets'},
    groups: const {
      'g': {'name': 'Round', 'categoryGroupIndex': 0},
    },
    categories: const {
      'c': {'name': 'Sport', 'categoryGroup': 'g', 'categoryIndex': 0},
    },
    questions: const {
      'c': {
        'q': {'type': 'free', 'question': 'Who won?', 'pointsPlus': 300, 'wager': true, 'betOwnPoints': true},
      },
    },
  );

  Future<void> pumpBet(WidgetTester tester, int points) async {
    final host = SessionHost(
      initial: SessionState(gameId: 'game', teams: [Team(id: 'red', name: 'Red', points: points)]),
      game: game,
    );
    addTearDown(host.dispose);
    host.dispatch(const OpenQuestion(QuestionRef('c', 'q')));
    final team = host.state.team('red')!;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BetScreen(view: PublicView(publicView(host.state, game, teamId: 'red')), team: team, send: (_) {}),
      ),
    ));
  }

  testWidgets('the slider goes up to the team\'s points, all in is all it has', (tester) async {
    await pumpBet(tester, 70);
    expect(tester.widget<Slider>(find.byType(Slider)).max, 70);
    await tester.tap(find.text('All in'));
    await tester.pump();
    expect(find.text('70'), findsOneWidget);
  });

  testWidgets('a team without points sees a bet of nothing, and nothing breaks', (tester) async {
    await pumpBet(tester, 0);
    expect(tester.widget<Slider>(find.byType(Slider)).max, 0);
    await tester.tap(find.text('All in'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
