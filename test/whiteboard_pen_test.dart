import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

void main() {
  late String drawing;

  Future<Rect> pumpPad(WidgetTester tester) async {
    drawing = '';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: WhiteboardPad(onChanged: (d) => drawing = d)),
      ),
    );
    return tester.getRect(find.descendant(of: find.byType(WhiteboardPad), matching: find.byType(CustomPaint)).first);
  }

  Future<void> stroke(WidgetTester tester, Offset from, PointerDeviceKind kind, {int buttons = kPrimaryButton}) async {
    final gesture = await tester.startGesture(from, kind: kind, buttons: buttons);
    for (var i = 1; i <= 5; i++) {
      await gesture.moveTo(from + Offset(i * 10.0, i * 2.0));
    }
    await gesture.up();
    await tester.pump();
  }

  testWidgets('a pen stroke starts right where the pen lands', (tester) async {
    final board = await pumpPad(tester);
    await stroke(tester, board.center, PointerDeviceKind.stylus);
    final strokes = decodeDrawing(drawing);
    expect(strokes, hasLength(1));
    final first = strokes.single.first;
    expect(first.$1 * board.width, closeTo(board.width / 2, 2));
    expect(strokes.single, hasLength(6));
  });

  testWidgets('once a pen has drawn, fingers no longer do', (tester) async {
    final board = await pumpPad(tester);
    await stroke(tester, board.center - const Offset(80, 40), PointerDeviceKind.touch);
    await stroke(tester, board.center, PointerDeviceKind.stylus);
    await stroke(tester, board.center + const Offset(0, 60), PointerDeviceKind.touch);
    expect(decodeDrawing(drawing), hasLength(2));
  });

  testWidgets('a palm touching down before the pen leaves no mark', (tester) async {
    final board = await pumpPad(tester);
    final palm = await tester.startGesture(board.center + const Offset(60, 60), kind: PointerDeviceKind.touch, pointer: 7);
    await palm.moveBy(const Offset(20, 0));
    await stroke(tester, board.center - const Offset(60, 0), PointerDeviceKind.stylus);
    await palm.up();
    await tester.pump();
    expect(decodeDrawing(drawing), hasLength(1));
  });

  testWidgets('with the eraser picked, a pen without an eraser end erases', (tester) async {
    final board = await pumpPad(tester);
    await stroke(tester, board.center, PointerDeviceKind.stylus);
    await stroke(tester, board.center + const Offset(0, 80), PointerDeviceKind.stylus);
    expect(decodeDrawing(drawing), hasLength(2));

    await tester.tap(find.byKey(const ValueKey('whiteboardEraser')));
    await tester.pump();
    await stroke(tester, board.center + const Offset(0, 80), PointerDeviceKind.stylus);
    expect(decodeDrawing(drawing), hasLength(1));

    // Back to the pen: it draws again.
    await tester.tap(find.byKey(const ValueKey('whiteboardEraser')));
    await tester.pump();
    await stroke(tester, board.center + const Offset(0, 80), PointerDeviceKind.stylus);
    expect(decodeDrawing(drawing), hasLength(2));
  });

  testWidgets("the pen's eraser end removes the strokes it touches", (tester) async {
    final board = await pumpPad(tester);
    await stroke(tester, board.center - const Offset(0, 60), PointerDeviceKind.stylus);
    await stroke(tester, board.center + const Offset(0, 60), PointerDeviceKind.stylus);
    expect(decodeDrawing(drawing), hasLength(2));
    await stroke(tester, board.center + const Offset(0, 60), PointerDeviceKind.invertedStylus);
    expect(decodeDrawing(drawing), hasLength(1));
    // So does the pen's side button.
    await stroke(tester, board.center - const Offset(0, 60), PointerDeviceKind.stylus, buttons: kPrimaryButton | kSecondaryStylusButton);
    expect(decodeDrawing(drawing), isEmpty);
  });
}
