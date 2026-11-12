import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/companion/answer_view.dart';
import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/game/game.dart';

void main() {
  testWidgets('a board next to a running countdown is drawn once per change, not every frame', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    Widget screen(String drawing) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            RoundCountdown(openedAt: now, endsAt: now + 60000, hostClock: true),
            for (var i = 0; i < 3; i++) SizedBox(width: 200, child: DrawingView(drawing: drawing)),
          ],
        ),
      ),
    );
    final one = encodeDrawing([
      [(0.1, 0.1), (0.9, 0.9)],
    ]);
    await tester.pumpWidget(screen(one));
    final first = WhiteboardPainter.debugPaintedPoints;
    expect(first, greaterThan(0));

    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(WhiteboardPainter.debugPaintedPoints, first);

    // A rebuild with the same drawing draws nothing again either; a new one does.
    await tester.pumpWidget(screen(one));
    expect(WhiteboardPainter.debugPaintedPoints, first);
    final two = encodeDrawing([
      [(0.1, 0.1), (0.9, 0.9)],
      [(0.5, 0.1), (0.5, 0.9)],
    ]);
    await tester.pumpWidget(screen(two));
    expect(WhiteboardPainter.debugPaintedPoints, first + 3 * 4);
  });
}
