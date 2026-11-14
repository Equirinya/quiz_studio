import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/companion/answer_view.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/pages/round_display.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';
import 'game/top_answers_fixture.dart';

/// The big screen at 1600×900 for a host [setUp] has played into.
void main() {
  late SessionHost host;

  Future<void> pumpScreen(WidgetTester tester, void Function(SessionHost host) setUp, {int teams = 2}) async {
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: fixtureState(), game: fixtureGame());
    addTearDown(host.dispose);
    for (var i = 3; i <= teams; i++) {
      host.dispatch(AddTeam('t$i', 'Team $i'));
    }
    setUp(host);
    final connection = SessionConnection.local(host, game: fixtureGame());
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PresenterView(connection: connection))));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('ABCD keeps its answers on screen while the teams pick on their devices', (tester) async {
    await pumpScreen(tester, (host) {
      host
        ..dispatch(const OpenQuestion(abcd))
        ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.choice, options: ['a', 'b', 'c', 'd'])))
        ..dispatch(const Reveal(4));
    });
    for (final option in ['a', 'b', 'c', 'd']) {
      expect(find.text(option), findsOneWidget);
    }
    expect(find.byType(RoundStatusStrip), findsOneWidget);
  });

  testWidgets('many teams: the status stays one line and the scores get flatter', (tester) async {
    await pumpScreen(tester, teams: 16, (host) {
      host
        ..dispatch(const OpenQuestion(free))
        ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.text)));
    });
    final strip = tester.getRect(find.byType(RoundStatusStrip));
    expect(strip.height, lessThan(40), reason: 'one line, however many teams');
    expect(strip.width, lessThanOrEqualTo(1600));
    // Two rows of score boxes, flat ones.
    final red = tester.getRect(find.text('Red').first);
    expect(red.top, lessThan(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shown answers pop up over the question, one big, four two by two', (tester) async {
    await pumpScreen(tester, teams: 5, (host) {
      host
        ..dispatch(const OpenQuestion(free))
        ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.text)));
      for (final id in ['red', 'blue', 't3', 't4', 't5']) {
        host.dispatch(SubmitAnswer(id, PlayerAnswer(text: 'answer $id')), sender: Sender(Role.player, teamId: id));
      }
      host.dispatch(const RevealAnswer('red'));
    });
    expect(find.byType(ShownAnswers), findsOneWidget);
    final one = tester.getRect(find.ancestor(of: find.text('answer red'), matching: find.byType(Container)).first);
    expect(one.width, greaterThan(1200), reason: 'a single answer nearly full screen');

    for (final id in ['blue', 't3', 't4']) {
      host.dispatch(RevealAnswer(id));
    }
    await tester.pump(const Duration(milliseconds: 500));
    final tiles = [for (final id in ['red', 'blue', 't3', 't4']) tester.getCenter(find.text('answer $id'))];
    // Two by two.
    expect(tiles[0].dy, moreOrLessEquals(tiles[1].dy, epsilon: 1));
    expect(tiles[2].dy, greaterThan(tiles[0].dy + 100));
    expect(tiles[0].dx, moreOrLessEquals(tiles[2].dx, epsilon: 1));
    expect(find.text('answer t5'), findsNothing);
  });

  test('grid shapes', () {
    expect([for (final n in [1, 2, 3, 4, 5, 6, 7, 9, 10]) gridShape(n)], [
      (1, 1), (2, 1), (2, 2), (2, 2), (3, 2), (3, 2), (3, 3), (3, 3), (4, 3),
    ]);
  });

  testWidgets('a whiteboard Fragenhagel shows drawings in the same popup', (tester) async {
    await pumpScreen(tester, (host) {
      host
        ..dispatch(const OpenQuestion(sum))
        ..dispatch(const RevealAnswer('red'));
    });
    expect(find.byType(ShownAnswers), findsOneWidget);
    expect(find.byType(RoundCountdown), findsNothing, reason: 'the popup covers the clock');
  });

  testWidgets('a category with its own colours colours the big screen while its question is open', (tester) async {
    final json = fixtureGame().toJson();
    (json['categories'] as Map)['c1'] = {...(json['categories'] as Map)['c1'] as Map, 'color': 0xFFE53935, 'accentColor': 0xFF43A047};
    final game = GameContent.fromJson(json);
    expect(game.category('c1')!.color, 0xFFE53935);
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: fixtureState(), game: game);
    addTearDown(host.dispose);
    final connection = SessionConnection.local(host, game: game);
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PresenterView(connection: connection))));
    final plain = Theme.of(tester.element(find.text('Red').first)).colorScheme.primary;
    host.dispatch(const OpenQuestion(free));
    await tester.pump(const Duration(milliseconds: 500));
    final coloured = Theme.of(tester.element(find.text('Capital of France?'))).colorScheme.primary;
    expect(coloured, isNot(plain));
    expect(coloured, ColorScheme.fromSeed(seedColor: const Color(0xFFE53935), tertiary: const Color(0xFF43A047)).primary);
  });

  testWidgets('top answers: every uncovered answer starts at the same place, however many teams found it', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = topAnswersGame();
    host = SessionHost(initial: topTeams, game: game);
    addTearDown(host.dispose);
    host
      ..dispatch(const OpenQuestion(films))
      ..dispatch(const Buzz('red'))
      // Found by Red, then one uncovered by nobody.
      ..dispatch(const TopAnswerToggle(0))
      ..dispatch(const TopAnswerToggle(1));
    final connection = SessionConnection.local(host, game: game);
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PresenterView(connection: connection))));
    await tester.pump(const Duration(seconds: 1));
    expect(host.state.feudRevealed, [0, 1]);
    expect(tester.getTopLeft(find.text('Titanic')).dx, moreOrLessEquals(tester.getTopLeft(find.text('Avatar')).dx, epsilon: 0.5));
  });
}
