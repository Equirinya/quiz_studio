import 'dart:math';
import 'dart:ui';

/// A connection between two bubbles: a cubic curve from the edge of one to
/// the edge of the other, ending in an arrowhead.
class MapArrow {
  const MapArrow(this.start, this.control1, this.control2, this.end);

  final Offset start;
  final Offset control1;
  final Offset control2;

  /// The arrow's tip.
  final Offset end;

  /// The direction the arrow points in at its tip, as a unit vector.
  Offset get heading {
    final d = end - control2;
    final length = d.distance;
    return length == 0 ? const Offset(1, 0) : d / length;
  }

  Path get curve => Path()
    ..moveTo(start.dx, start.dy)
    ..cubicTo(control1.dx, control1.dy, control2.dx, control2.dy, end.dx, end.dy);

  /// The curve, stopping where the arrowhead of [length] begins, so the
  /// line's round end does not poke through its tip.
  Path shaft(double length) {
    final stop = end - heading * length * 0.8;
    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(control1.dx, control1.dy, control2.dx, control2.dy, stop.dx, stop.dy);
  }

  /// A triangle with its tip at [end].
  Path head(double length) {
    final back = end - heading * length;
    final side = Offset(-heading.dy, heading.dx) * length * 0.55;
    return Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(back.dx + side.dx, back.dy + side.dy)
      ..lineTo(back.dx - side.dx, back.dy - side.dy)
      ..close();
  }
}

/// Routes an arrow from the bubble [from] to the bubble [to].
///
/// It leaves and arrives through the sides that face each other: sideways
/// when there is room between the bubbles for that or they are mostly next
/// to each other, up or down when one is mostly above the other. Leaving
/// and arriving square to those sides gives the gentle S of an organisation
/// chart. [gap] keeps both ends clear of the bubbles' outlines.
/// [startShift] and [endShift] move the ends along their sides, away from
/// the middle (down or to the right when positive), so that arrows sharing a
/// side do not run into each other.
MapArrow routeArrow(Rect from, Rect to, {double gap = 0, double startShift = 0, double endShift = 0}) {
  final delta = to.center - from.center;
  final sideways = _sideways(from, to, gap);

  late Offset start, end, normalOut, normalIn;
  if (sideways) {
    final right = delta.dx >= 0;
    normalOut = Offset(right ? 1 : -1, 0);
    normalIn = normalOut;
    start = Offset(right ? from.right + gap : from.left - gap, from.center.dy + startShift);
    end = Offset(right ? to.left - gap : to.right + gap, to.center.dy + endShift);
  } else {
    final down = delta.dy >= 0;
    normalOut = Offset(0, down ? 1 : -1);
    normalIn = normalOut;
    start = Offset(from.center.dx + startShift, down ? from.bottom + gap : from.top - gap);
    end = Offset(to.center.dx + endShift, down ? to.top - gap : to.bottom + gap);
  }
  // Run out square to the side for half the way across: the classic S that
  // never overshoots, however far the two bubbles are offset from each other.
  final across = sideways ? (end.dx - start.dx).abs() : (end.dy - start.dy).abs();
  final reach = max(across * 0.5, gap);
  var control1 = start + normalOut * reach;
  var control2 = end - normalIn * reach;

  // Two bubbles exactly in line would get a dead straight arrow. A slight
  // bow, always to the same side of the direction of travel, keeps the map
  // looking drawn rather than ruled.
  final offset = sideways ? (end.dy - start.dy).abs() : (end.dx - start.dx).abs();
  final length = (end - start).distance;
  // Bubbles that almost touch leave no room for a curve: a short straight
  // arrow reads better than a squeezed one.
  final cramped = length < gap * 8;
  if (cramped) {
    control1 = start + (end - start) * 0.3;
    control2 = start + (end - start) * 0.7;
  } else if (length > 0 && offset < length * 0.08) {
    // One even arc: both controls on the chord, pushed out to one side.
    final bow = Offset(normalOut.dy, -normalOut.dx) * length * 0.2;
    control1 = start + (end - start) * 0.3 + bow;
    control2 = start + (end - start) * 0.7 + bow;
  }
  return MapArrow(start, control1, control2, end);
}

/// Whether the arrow from [from] to [to] runs sideways rather than up or
/// down. A map reads left to right, so it does wherever there is room for an
/// arrow between the bubbles' facing sides, and otherwise when they are
/// further apart side by side than one above the other (measured between
/// their facing sides, negative where they overlap).
bool _sideways(Rect from, Rect to, double gap) {
  final delta = to.center - from.center;
  final clearX = delta.dx.abs() - (from.width + to.width) / 2;
  final clearY = delta.dy.abs() - (from.height + to.height) / 2;
  return clearX >= clearY || (gap > 0 && clearX >= gap * 6);
}

/// Routes every arrow of a map, each from the first bubble of its pair to
/// the second. Where several arrows leave or arrive through the same side of
/// a bubble, as at a branch or where branches join, their ends are spread
/// along that side in the order of the bubbles at their other ends, so they
/// fan out instead of piling up on one point and crossing.
List<MapArrow> routeArrows(List<(Rect, Rect)> pairs, {double gap = 0}) {
  // Each end of each arrow, by the side of the bubble it sits on.
  final ends = <(Rect, int), List<(int, bool)>>{};
  for (final (i, (from, to)) in pairs.indexed) {
    final delta = to.center - from.center;
    final sideways = _sideways(from, to, gap);
    // 0 right, 1 left, 2 bottom, 3 top.
    final out = sideways ? (delta.dx >= 0 ? 0 : 1) : (delta.dy >= 0 ? 2 : 3);
    final into = out ^ 1;
    ends.putIfAbsent((from, out), () => []).add((i, true));
    ends.putIfAbsent((to, into), () => []).add((i, false));
  }
  final startShift = List.filled(pairs.length, 0.0);
  final endShift = List.filled(pairs.length, 0.0);
  for (final MapEntry(key: (rect, side), value: here) in ends.entries) {
    if (here.length < 2) continue;
    final vertical = side < 2;
    // Along the side, by where the other bubble is.
    double along((int, bool) end) {
      final (from, to) = pairs[end.$1];
      final other = end.$2 ? to : from;
      return vertical ? other.center.dy : other.center.dx;
    }

    here.sort((a, b) => along(a).compareTo(along(b)));
    final length = vertical ? rect.height : rect.width;
    // Spread over the middle of the side, never further apart than needed.
    final step = min(length * 0.6 / (here.length - 1), gap * 6);
    for (final (k, (i, starts)) in here.indexed) {
      final shift = (k - (here.length - 1) / 2) * step;
      starts ? startShift[i] = shift : endShift[i] = shift;
    }
  }
  return [
    for (final (i, (from, to)) in pairs.indexed)
      routeArrow(from, to, gap: gap, startShift: startShift[i], endShift: endShift[i]),
  ];
}
