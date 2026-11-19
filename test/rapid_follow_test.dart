import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

/// The controller's Fragenhagel list follows the item being asked only when
/// the gamemaster was looking at it and the next one would be out of view.
void main() {
  const ref = QuestionRef('r', 'long');
  final game = GameContent.assemble(
    id: 'game',
    game: const {'name': 'Rapid'},
    groups: const {'g': {'name': 'Round', 'categoryGroupIndex': 0}},
    categories: const {'r': {'name': 'Rapid', 'categoryGroup': 'g', 'categoryIndex': 0}},
    questions: {
      'r': {
        'long': {
          'type': 'rapidFire',
          'question': 'Capitals',
          'pointsPlus': 10,
          'rapidFire': {
            'mode': 'buzzer',
            'items': [for (var i = 1; i <= 30; i++) {'question': 'Item $i?', 'answer': 'Answer $i'}],
          },
        },
      },
    },
  );

  late SessionHost host;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(460, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: fixtureState(), game: game);
    final connection = SessionConnection.local(host, game: game);
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ControllerView(connection: connection))));
    host.dispatch(const OpenQuestion(ref));
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    host.dispatch(const Reveal(1));
    await tester.pumpAndSettle();
  }

  ScrollPosition position(WidgetTester tester) =>
      Scrollable.of(tester.element(find.text('Answer 1'))).position;

  bool fullyInView(WidgetTester tester, String text) {
    final viewport = tester.getRect(find.byWidget(Scrollable.of(tester.element(find.text('Answer 1'))).widget));
    final item = tester.getRect(find.text(text));
    return item.top >= viewport.top && item.bottom <= viewport.bottom;
  }

  testWidgets('it scrolls along once the next item would be out of view, and not before', (tester) async {
    await pump(tester);
    await next(tester);
    expect(position(tester).pixels, 0, reason: 'item 2 is in view: nothing moves');
    var asked = 1;
    // Step on until the next item would drop below the edge.
    while (fullyInView(tester, 'Answer ${asked + 1}') && asked < 25) {
      await next(tester);
      asked++;
      expect(position(tester).pixels, 0);
    }
    await next(tester);
    asked++;
    expect(position(tester).pixels, greaterThan(0));
    expect(fullyInView(tester, 'Answer $asked'), isTrue);
  });

  testWidgets('scrolled elsewhere, it stays where the gamemaster put it', (tester) async {
    await pump(tester);
    await next(tester);
    // Off to look at the end of the list.
    position(tester).jumpTo(position(tester).maxScrollExtent);
    await tester.pumpAndSettle();
    final there = position(tester).pixels;
    await next(tester);
    await next(tester);
    expect(position(tester).pixels, there);
  });
}
