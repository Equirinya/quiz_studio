import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/companion/match_input.dart';

void main() {
  late List<List<int>> sent;

  Future<void> pump(WidgetTester tester, {int pairs = 3, bool enabled = true, Size size = const Size(412, 700)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    sent = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MatchInput(
              left: [for (var i = 0; i < pairs; i++) 'L$i'],
              // Shown in reverse, as if shuffled.
              right: [for (var i = pairs - 1; i >= 0; i--) (i, 'R$i')],
              enabled: enabled,
              onChanged: sent.add,
            ),
          ),
        ),
      ),
    );
  }

  Finder slotOf(String left) => find.descendant(
    of: find.ancestor(of: find.text(left), matching: find.byType(Row)).first,
    matching: find.byIcon(Icons.add_rounded),
  );

  Finder chip(String text) => find.text(text).last;

  testWidgets('tap an answer, then a slot', (tester) async {
    await pump(tester);
    await tester.tap(chip('R1'));
    await tester.pump();
    expect(find.text('Now tap where “R1” goes'), findsOneWidget);
    await tester.tap(slotOf('L0'));
    await tester.pumpAndSettle();
    expect(sent.last, [1, -1, -1]);
    expect(find.text('Drag each answer onto its partner'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('drag an answer onto a slot, then onto another to swap', (tester) async {
    await pump(tester);
    await tester.drag(chip('R2'), tester.getCenter(slotOf('L2')) - tester.getCenter(chip('R2')));
    await tester.pumpAndSettle();
    expect(sent.last, [-1, -1, 2]);

    await tester.drag(chip('R0'), tester.getCenter(slotOf('L0')) - tester.getCenter(chip('R0')));
    await tester.pumpAndSettle();
    expect(sent.last, [0, -1, 2]);

    // A placed answer is picked up with a short hold, then dropped on the
    // other filled slot: the two swap.
    final from = tester.getCenter(find.text('R0'));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 300));
    final row2 = find.ancestor(of: find.text('L2'), matching: find.byType(Row)).first;
    await gesture.moveTo(tester.getCenter(find.descendant(of: row2, matching: find.text('R2'))));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(sent.last, [2, -1, 0]);
  });

  testWidgets('a placed answer goes back to the tray', (tester) async {
    await pump(tester);
    await tester.tap(chip('R1'));
    await tester.pump();
    await tester.tap(slotOf('L1'));
    await tester.pumpAndSettle();
    // Pick it up again by tapping it, then tap the tray.
    await tester.tap(find.text('R1'));
    await tester.pump();
    expect(find.text('Now tap where “R1” goes'), findsOneWidget);
    await tester.tap(chip('R0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    // Tapping another answer picks that one instead.
    expect(find.text('Now tap where “R0” goes'), findsOneWidget);
    await tester.tap(chip('R0'));
    await tester.tap(find.text('R1'));
    await tester.pump();
    await tester.tapAt(tester.getBottomRight(find.byType(MatchInput)) - const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(sent.last, [-1, -1, -1]);
  });

  testWidgets('eleven pairs fit a phone: the slots scroll, the tray stays', (tester) async {
    await pump(tester, pairs: 11, size: const Size(390, 600));
    expect(tester.takeException(), isNull);
    expect(find.text('0 / 11'), findsOneWidget);
    // Every answer is reachable in the tray.
    for (var i = 0; i < 11; i++) {
      expect(find.text('R$i'), findsOneWidget);
    }
    // The last slot can be scrolled to and filled.
    await tester.tap(chip('R10'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('L10'), 100, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(slotOf('L10'));
    await tester.pumpAndSettle();
    expect(sent.last[10], 10);
  });

  testWidgets('locked: no tray, nothing moves', (tester) async {
    await pump(tester, enabled: false);
    expect(find.text('R0'), findsNothing);
    expect(find.text('Your pairs'), findsOneWidget);
  });
}
