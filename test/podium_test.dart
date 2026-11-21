import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/boards/podium_board.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

/// The podium: every game's last board, with the top three on steps.
void main() {
  const teams = [
    Team(id: 'red', name: 'Red', points: 300),
    Team(id: 'blue', name: 'Blue', points: 500),
    Team(id: 'green', name: 'Green', points: 300),
    Team(id: 'gold', name: 'Gold', points: 100),
    Team(id: 'pink', name: 'Pink', points: 0),
  ];

  test('places by points; level teams share one and the next skips ahead', () {
    expect([for (final (place, team) in podiumPlaces(teams)) '$place ${team.id}'], ['1 blue', '2 red', '2 green', '4 gold', '5 pink']);
    expect(podiumPlaces(const []), isEmpty);
  });

  test('the controller picks it like any board, though no game has it as a group', () {
    final game = fixtureGame();
    var s = reduce(fixtureState(), const SelectGroup(podiumBoardId), game).state;
    expect(s.groupId, podiumBoardId);
    expect(reduce(s, const SelectGroup(podiumBoardId), game).accepted, isFalse);
    s = reduce(s, const SelectGroup('g1'), game).state;
    expect(s.groupId, 'g1');
    final open = reduce(fixtureState(), const OpenQuestion(free), game).state;
    expect(reduce(open, const SelectGroup(podiumBoardId), game).accepted, isFalse, reason: 'not under an open question');
  });

  testWidgets('the big screen shows the top three on steps and the others below, without the score bar', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = fixtureGame();
    final host = SessionHost(initial: const SessionState(gameId: 'game', teams: teams), game: game);
    addTearDown(host.dispose);
    host.dispatch(const SelectGroup(podiumBoardId));
    final connection = SessionConnection.local(host, game: game);
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PresenterView(connection: connection))));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PodiumBoard), findsOneWidget);
    for (final team in teams) {
      expect(find.text(team.name), findsOneWidget, reason: 'each team once, the score bar is off');
    }
    // Second, first, third from left to right.
    final x = {for (final id in ['red', 'blue', 'green']) id: tester.getCenter(find.byKey(ValueKey('podium-$id'))).dx};
    expect(x['red']! < x['blue']! && x['blue']! < x['green']!, isTrue);
    // The rest below the steps.
    expect(tester.getCenter(find.byKey(const ValueKey('podium-gold'))).dy, greaterThan(tester.getCenter(find.byKey(const ValueKey('podium-blue'))).dy));
    expect(find.text('4.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
