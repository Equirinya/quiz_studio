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
}
