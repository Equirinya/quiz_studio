import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/top_answers_fixture.dart';

/// While rating, the controller shows beside each line a team wrote which
/// answer it was matched with.
void main() {
  Future<SessionHost> pumpController(WidgetTester tester, GameContent game) async {
    tester.view
      ..physicalSize = const Size(600, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = SessionHost(initial: topTeams);
    final connection = SessionConnection.local(host, game: game);
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ControllerView(connection: connection))));
    await tester.pump();
    return host;
  }

  testWidgets('top answers: each typed line rated by itself shows the answer on the list it matched', (tester) async {
    final host = await pumpController(tester, topAnswersGame(mode: TopAnswersMode.typed));
    host
      ..dispatch(const OpenQuestion(films))
      ..dispatch(const SubmitAnswer('red', PlayerAnswer(items: ['Titanik', 'lion king', 'Shrek', '', ''])))
      ..dispatch(const LockAnswers());
    await tester.pump();
    expect(host.state.answerRound!.found['red'], [0, 2]);
    expect(find.text('matches 1. Titanic'), findsOneWidget);
    expect(find.text('matches 3. The Lion King / Lion King'), findsOneWidget);
    // A line that matches nothing is shown as it is.
    expect(find.text('3. Shrek'), findsOneWidget);
  });

  testWidgets('an answer list with right answers marks the matching lines, but gives no points', (tester) async {
    final game = GameContent.assemble(
      id: 'tg',
      game: const {'name': 'Planets'},
      groups: const {'g': {'name': 'Round', 'categoryGroupType': 'category_wheel', 'categoryGroupIndex': 0}},
      categories: const {'tc': {'name': 'Space', 'categoryGroup': 'g', 'categoryIndex': 0, 'active': true}},
      questions: {
        'tc': {
          'planets': {
            'type': 'free',
            'question': 'Name the inner planets',
            'pointsPlus': 100,
            'noBuzzer': true,
            'companion': const CompanionSpec(
              kind: CompanionKind.list,
              listRows: 3,
              solutions: ['Mercury', 'Venus', 'Earth', 'Mars'],
            ).toMap(),
          },
        },
      },
    );
    final host = await pumpController(tester, game);
    host
      ..dispatch(const OpenQuestion(QuestionRef('tc', 'planets')))
      ..dispatch(const SubmitAnswer('blue', PlayerAnswer(items: ['Merkur', 'Pluto', 'mars'])))
      ..dispatch(const LockAnswers());
    await tester.pump();
    expect(find.text('matches Mercury'), findsOneWidget);
    expect(find.text('matches Mars'), findsOneWidget);
    expect(find.text('2. Pluto'), findsOneWidget);
    expect(host.state.results.isEmpty, isTrue);
  });
}
