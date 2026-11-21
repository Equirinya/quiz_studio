import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/boards/podium_board.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
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

  group('unveiling', () {
    final game = fixtureGame();
    SessionState podium() =>
        reduce(const SessionState(gameId: 'game', teams: teams), const SelectGroup(podiumBoardId), game).state;

    test('it comes up with no place shown; places come up one by one, all at once, or back', () {
      var s = podium();
      expect(s.podiumShown, 0);
      var result = reduce(s, const RevealPodium(1), game);
      expect(result.state.podiumShown, 1);
      expect([for (final e in result.effects) if (e is SoundEffect) e.key], [effectReveal]);
      s = result.state;
      result = reduce(s, const RevealPodium(99), game);
      expect(result.state.podiumShown, teams.length, reason: 'all at once, no further');
      expect([for (final e in result.effects) if (e is SoundEffect) e.key], [effectFanfare], reason: 'the winner with a fanfare');
      s = result.state;
      result = reduce(s, RevealPodium(teams.length - 1), game);
      expect(result.state.podiumShown, teams.length - 1);
      expect(result.effects, isEmpty, reason: 'taking one away is quiet');
      expect(reduce(result.state, RevealPodium(teams.length - 1), game).accepted, isFalse);
    });

    test('shown again, it starts over; elsewhere there is nothing to unveil', () {
      var s = reduce(podium(), const RevealPodium(3), game).state;
      s = reduce(s, const SelectGroup('g1'), game).state;
      expect(reduce(s, const RevealPodium(1), game).accepted, isFalse);
      s = reduce(s, const SelectGroup(podiumBoardId), game).state;
      expect(s.podiumShown, 0);
      expect(SessionState.fromJson(reduce(s, const RevealPodium(2), game).state.toJson()).podiumShown, 2);
    });

    testWidgets('the big screen shows the unveiled teams from the last place up, the rest hidden', (tester) async {
      tester.view
        ..physicalSize = const Size(1600, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      double opacityOf(String name) => tester
          .widgetList<AnimatedOpacity>(find.ancestor(of: find.text(name), matching: find.byType(AnimatedOpacity)))
          .first
          .opacity;
      Future<void> show(int shown) async {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: PodiumBoard(teams: teams, unit: 9, shown: shown))));
        await tester.pumpAndSettle();
      }

      await show(0);
      for (final team in teams) {
        expect(opacityOf(team.name), 0, reason: '${team.name} hidden');
      }
      // Last (Pink) and fourth (Gold) first.
      await show(2);
      expect(opacityOf('Pink'), 1);
      expect(opacityOf('Gold'), 1);
      expect(opacityOf('Green'), 0);
      expect(opacityOf('Blue'), 0);
      await show(teams.length);
      expect(opacityOf('Blue'), 1);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the controller unveils the next place, all of them, or takes one back', (tester) async {
    tester.view
      ..physicalSize = const Size(460, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = fixtureGame();
    final host = SessionHost(initial: const SessionState(gameId: 'game', teams: teams), game: game);
    addTearDown(host.dispose);
    host.dispatch(const SelectGroup(podiumBoardId));
    final connection = SessionConnection.local(host, game: game);
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ControllerView(connection: connection))));
    await tester.pump();
    Future<void> tap(String key) async {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
    }

    expect(find.text('Unveil 5th place'), findsOneWidget);
    await tap('podiumNext');
    expect(host.state.podiumShown, 1);
    expect(find.text('Unveil 4th place'), findsOneWidget);
    await tap('podiumBack');
    expect(host.state.podiumShown, 0);
    await tap('podiumAll');
    expect(host.state.podiumShown, teams.length);
    expect(find.text('All places shown'), findsOneWidget);
  });
}
