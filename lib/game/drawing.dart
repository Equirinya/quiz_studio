/// Whiteboard ink as data: a list of strokes, each a list of points with
/// coordinates as fractions of the board (0..1). Plain Dart.
///
/// On the wire a drawing is a string: strokes separated by ';', points by
/// ' ', coordinates as integers 0..999 joined by ','. A page of handwriting
/// stays in the tens of kilobytes that way.
///
/// A board that is not the default shape says so up front: `a750|` before
/// the strokes means width / height = 0.75, a phone held upright.
library;

/// Shape of a whiteboard unless the drawing says otherwise: width / height.
const double kDefaultDrawingAspect = 4 / 3;

typedef InkPoint = (double x, double y);
typedef Stroke = List<InkPoint>;

/// Upper bound on the points of one drawing; older strokes are thinned out
/// first when a drawing exceeds it.
const int kMaxInkPoints = 6000;

String encodeDrawing(List<Stroke> strokes, {double aspect = kDefaultDrawingAspect}) {
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
  final ink = all.map((stroke) => stroke.map((p) => '${q(p.$1)},${q(p.$2)}').join(' ')).join(';');
  final custom = (aspect - kDefaultDrawingAspect).abs() > 0.01;
  return custom ? 'a${(aspect * 1000).round()}|$ink' : ink;
}

/// The shape of the board [encoded] was drawn on, as width / height.
double drawingAspect(String? encoded) {
  if (encoded == null || !encoded.startsWith('a')) return kDefaultDrawingAspect;
  final end = encoded.indexOf('|');
  final value = end < 0 ? null : int.tryParse(encoded.substring(1, end));
  // Anything outside sane proportions is treated as not given.
  return value == null || value < 300 || value > 3000 ? kDefaultDrawingAspect : value / 1000;
}

/// Reads [encodeDrawing]'s format; anything malformed is skipped.
List<Stroke> decodeDrawing(String? encoded) {
  if (encoded == null || encoded.isEmpty) return [];
  final strokes = <Stroke>[];
  final ink = encoded.startsWith('a') && encoded.contains('|') ? encoded.substring(encoded.indexOf('|') + 1) : encoded;
  for (final part in ink.split(';')) {
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
