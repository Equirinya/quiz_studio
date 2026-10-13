/// Whiteboard ink as data: a list of strokes, each a list of points with
/// coordinates as fractions of the board (0..1). Plain Dart.
///
/// On the wire a drawing is a string: strokes separated by ';', points by
/// ' ', coordinates as integers 0..999 joined by ','. A page of handwriting
/// stays in the tens of kilobytes that way.
library;

typedef InkPoint = (double x, double y);
typedef Stroke = List<InkPoint>;

/// Upper bound on the points of one drawing; older strokes are thinned out
/// first when a drawing exceeds it.
const int kMaxInkPoints = 6000;

String encodeDrawing(List<Stroke> strokes) {
  var all = strokes.where((s) => s.isNotEmpty).toList();
  var total = all.fold(0, (sum, s) => sum + s.length);
  // Halve the resolution of every stroke until it fits.
  while (total > kMaxInkPoints) {
    all = [
      for (final stroke in all)
        [
          for (var i = 0; i < stroke.length; i++)
            if (i.isEven || i == stroke.length - 1) stroke[i],
        ],
    ];
    final next = all.fold(0, (sum, s) => sum + s.length);
    if (next == total) break;
    total = next;
  }
  int q(double v) => (v.clamp(0, 1) * 999).round();
  return all.map((stroke) => stroke.map((p) => '${q(p.$1)},${q(p.$2)}').join(' ')).join(';');
}

/// Reads [encodeDrawing]'s format; anything malformed is skipped.
List<Stroke> decodeDrawing(String? encoded) {
  if (encoded == null || encoded.isEmpty) return [];
  final strokes = <Stroke>[];
  for (final part in encoded.split(';')) {
    final stroke = <InkPoint>[];
    for (final point in part.split(' ')) {
      final xy = point.split(',');
      if (xy.length != 2) continue;
      final x = int.tryParse(xy[0]);
      final y = int.tryParse(xy[1]);
      if (x == null || y == null) continue;
      stroke.add((x.clamp(0, 999) / 999, y.clamp(0, 999) / 999));
    }
    if (stroke.isNotEmpty) strokes.add(stroke);
  }
  return strokes;
}
