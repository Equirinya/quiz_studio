import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/boards/map_board.dart';
import 'package:quiz_show/game/game.dart';

/// Eight categories in a row: a canvas two screens wide.
CategoryGroup wide() => CategoryGroup(
      id: 'g',
      type: BoardType.map,
      categories: [
        for (var c = 0; c < 8; c++)
          Category(id: 'c$c', name: 'Category $c', index: c, questions: [Question(id: 'q', type: QuestionType.free, pointsPlus: 100)]),
      ],
    );

void main() {
  test('the window centres a bubble, except where the canvas ends', () {
    // canvas 2000 wide, window 1000
    expect(mapScrollOffset(0.5, 2000, 1000), 500);
    expect(mapScrollOffset(0.6, 2000, 1000), 700);
    expect(mapScrollOffset(0.1, 2000, 1000), 0, reason: 'near the start it stays at the start');
    expect(mapScrollOffset(0.95, 2000, 1000), 1000, reason: 'near the end it stops at the end');
    expect(mapScrollOffset(0.5, 1000, 1000), 0, reason: 'a canvas that fits does not scroll');
  });

  group('in the game', () {
    Future<void> pumpBoard(WidgetTester tester, SessionState state, {Size size = const Size(1600, 900)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MapBoard(group: wide(), state: state, imageFile: (_) => null)),
      ));
      await tester.pump();
    }

    double offset(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

    SessionState open(String category) => SessionState(phase: Phase.question, current: QuestionRef(category, 'q'));

    testWidgets('the board starts at the beginning of the canvas', (tester) async {
      await pumpBoard(tester, const SessionState());
      expect(offset(tester), 0);
      expect(tester.getSize(find.byType(MapCanvas)).width, 3200);
    });

    testWidgets('a narrower window shows less of the map, at the same size', (tester) async {
      await pumpBoard(tester, const SessionState());
      final wideText = tester.getSize(find.text('Category 0')).height;
      await pumpBoard(tester, const SessionState(), size: const Size(1100, 900));
      expect(tester.getSize(find.byType(MapCanvas)).width, 3200);
      expect(tester.getSize(find.text('Category 0')).height, wideText);
    });

    testWidgets('opening a question glides its category to the middle', (tester) async {
      await pumpBoard(tester, const SessionState());
      await pumpBoard(tester, open('c4'));
      // c4 sits at 4.5/8 of a 3200 wide canvas = 1800; centred in a 1600 window.
      await tester.pump(const Duration(milliseconds: 450));
      final halfway = offset(tester);
      expect(halfway, inExclusiveRange(0, 1000));
      await tester.pumpAndSettle();
      expect(offset(tester), 1000);
      // Ease in and out: by half time it is about half way, not all the way.
      expect(halfway, closeTo(500, 120));
    });

    testWidgets('categories at either end stop at the edge of the canvas', (tester) async {
      await pumpBoard(tester, const SessionState());
      await pumpBoard(tester, open('c7'));
      await tester.pumpAndSettle();
      expect(offset(tester), 1600);
      await pumpBoard(tester, open('c0'));
      await tester.pumpAndSettle();
      expect(offset(tester), 0);
    });

    testWidgets('closing the question leaves the window where it is', (tester) async {
      await pumpBoard(tester, const SessionState());
      await pumpBoard(tester, open('c5'));
      await tester.pumpAndSettle();
      final at = offset(tester);
      expect(at, greaterThan(0));
      await pumpBoard(tester, const SessionState(played: {'c5/q'}));
      await tester.pumpAndSettle();
      expect(offset(tester), at);
    });

    testWidgets('back on the board after a question, it opens on that category', (tester) async {
      // The question took the whole screen; the board comes back afresh.
      await pumpBoard(tester, const SessionState(played: {'c4/q'}, boardFocus: 'c4'));
      await tester.pump();
      expect(offset(tester), 1000);
    });

    testWidgets('the gamemaster can turn the board to a category', (tester) async {
      await pumpBoard(tester, const SessionState());
      await pumpBoard(tester, const SessionState(boardFocus: 'c7'));
      await tester.pumpAndSettle();
      expect(offset(tester), 1600);
    });

    testWidgets('a show resumed mid-question starts on that category, without a glide', (tester) async {
      await pumpBoard(tester, open('c4'));
      await tester.pump();
      expect(offset(tester), 1000);
    });
  });
}
