import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/boards/map_arrows.dart';

void main() {
  const a = Rect.fromLTWH(0, 100, 100, 60);

  test('bubbles side by side are joined through their facing sides', () {
    final arrow = routeArrow(a, const Rect.fromLTWH(300, 300, 100, 60), gap: 5);
    expect(arrow.start, const Offset(105, 130));
    expect(arrow.end, const Offset(295, 330));
    // It leaves and arrives level, so the head points straight at the bubble.
    expect(arrow.control1.dy, arrow.start.dy);
    expect(arrow.control2.dy, arrow.end.dy);
    expect(arrow.heading, const Offset(1, 0));
    // An S that does not overshoot: both controls stay between the bubbles.
    expect(arrow.control1.dx, inInclusiveRange(arrow.start.dx, arrow.end.dx));
    expect(arrow.control2.dx, inInclusiveRange(arrow.start.dx, arrow.end.dx));
  });

  test('right to left and bottom to top work the same way', () {
    final back = routeArrow(const Rect.fromLTWH(300, 100, 100, 60), a, gap: 5);
    expect(back.start.dx, 295);
    expect(back.end.dx, 105);
    expect(back.heading.dx, lessThan(0));

    final up = routeArrow(const Rect.fromLTWH(0, 400, 100, 60), a, gap: 5);
    expect(up.start, const Offset(50, 395));
    expect(up.end, const Offset(50, 165));
    expect(up.heading.dy, lessThan(0));
  });

  test('one above the other is joined top to bottom', () {
    final arrow = routeArrow(a, const Rect.fromLTWH(20, 400, 100, 60));
    expect(arrow.start, const Offset(50, 160));
    expect(arrow.end, const Offset(70, 400));
  });

  test('bubbles exactly in line get a bowed arrow, not a ruled one', () {
    final arrow = routeArrow(a, const Rect.fromLTWH(300, 100, 100, 60));
    expect(arrow.start.dy, arrow.end.dy);
    expect(arrow.control1.dy, isNot(arrow.start.dy));
    expect(arrow.control1.dy, arrow.control2.dy);
    // The head follows the curve into the bubble.
    expect(arrow.heading.dx, greaterThan(0.5));
  });

  test('the head is a triangle with its tip on the end', () {
    final arrow = routeArrow(a, const Rect.fromLTWH(300, 300, 100, 60));
    final bounds = arrow.head(20).getBounds();
    expect(bounds.right, closeTo(arrow.end.dx, 0.01));
    expect(bounds.width, closeTo(20, 0.01));
    expect(bounds.center.dy, closeTo(arrow.end.dy, 0.01));
    // The line stops inside the head instead of poking through the tip.
    expect(arrow.shaft(20).getBounds().right, lessThan(arrow.end.dx));
  });

  test('bubbles that almost touch get a short straight arrow', () {
    final arrow = routeArrow(a, const Rect.fromLTWH(130, 100, 100, 60), gap: 5);
    expect(arrow.start, const Offset(105, 130));
    expect(arrow.end, const Offset(125, 130));
    expect(arrow.control1.dy, 130);
    expect(arrow.control2.dy, 130);
    expect(arrow.heading, const Offset(1, 0));
  });

  test('touching or overlapping bubbles still give a finite arrow', () {
    final arrow = routeArrow(a, a.shift(const Offset(40, 10)), gap: 5);
    for (final point in [arrow.start, arrow.control1, arrow.control2, arrow.end]) {
      expect(point.dx.isFinite && point.dy.isFinite, isTrue);
    }
  });

  group('several arrows', () {
    const b = Rect.fromLTWH(300, 0, 100, 60);
    const c = Rect.fromLTWH(300, 200, 100, 60);
    const d = Rect.fromLTWH(600, 100, 100, 60);

    test('a branch fans out from one side instead of leaving from one point', () {
      final [toB, toC] = routeArrows([(a, b), (a, c)], gap: 5);
      expect(toB.start.dx, toC.start.dx);
      // The arrow to the upper bubble leaves higher up, so they do not cross.
      expect(toB.start.dy, lessThan(toC.start.dy));
      expect((toB.start.dy + toC.start.dy) / 2, closeTo(a.center.dy, 1e-9));
      expect(toB.start.dy, greaterThan(a.top));
      expect(toC.start.dy, lessThan(a.bottom));
      // Their tips still meet the middle of their own bubbles.
      expect(toB.end, const Offset(295, 30));
      expect(toC.end, const Offset(295, 230));
    });

    test('where branches join, the arrows arrive side by side', () {
      final [fromB, fromC] = routeArrows([(b, d), (c, d)], gap: 5);
      expect(fromB.end.dx, fromC.end.dx);
      expect(fromB.end.dy, lessThan(fromC.end.dy));
      expect(fromB.start, const Offset(405, 30));
    });

    test('a single arrow is routed as before', () {
      final [only] = routeArrows([(a, b)], gap: 5);
      final alone = routeArrow(a, b, gap: 5);
      expect((only.start, only.control1, only.control2, only.end), (alone.start, alone.control1, alone.control2, alone.end));
    });
  });
}
