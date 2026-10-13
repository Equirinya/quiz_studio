/// Where everything sits on a map board. Positions are fractions of the
/// canvas (0..1 in both directions), so a layout fits any screen. The canvas
/// is as tall as the screen and may be several screens wide; the board then
/// scrolls sideways.
///
/// Stored on the category group document as `mapLayout`:
///   width:       number   canvas width in screens; absent = as wide as the
///                automatic layout needs (about four bubbles per screen)
///   follows:     {categoryId: categoryId | ""}   which bubble a category
///                comes after; "" starts a new chain; absent = the category
///                before it in the group's order
///   nodes:       {categoryId: {x, y, scale}}     x and y: a bubble placed by
///                hand; scale: its size relative to the others (default 1)
///   decorations: [{type: "title", text, x, y, size}
///                 {type: "image", image, x, y, width}
///                 {type: "line", x1, y1, x2, y2}]
/// and `mapLabels`: "points" (default) | "label".
library;

import 'content.dart';

class MapPoint {
  const MapPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) => other is MapPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}

sealed class MapDecoration {
  const MapDecoration();

  static MapDecoration? fromMap(Object? stored) {
    if (stored is! Map) return null;
    double? n(String key) => stored[key] is num ? (stored[key] as num).toDouble() : null;
    switch (stored['type']) {
      case 'title':
        final text = stored['text'];
        if (text is! String || text.isEmpty || n('x') == null || n('y') == null) return null;
        return MapTitle(text, MapPoint(n('x')!, n('y')!), size: n('size') ?? 1);
      case 'image':
        final image = stored['image'];
        if (image is! String || image.isEmpty || n('x') == null || n('y') == null) return null;
        return MapImage(image, MapPoint(n('x')!, n('y')!), width: n('width') ?? 0.2);
      case 'line':
        if ([n('x1'), n('y1'), n('x2'), n('y2')].contains(null)) return null;
        return MapLine(MapPoint(n('x1')!, n('y1')!), MapPoint(n('x2')!, n('y2')!));
    }
    return null;
  }
}

/// Free text; [size] scales it relative to a category title.
class MapTitle extends MapDecoration {
  const MapTitle(this.text, this.center, {this.size = 1});
  final String text;
  final MapPoint center;
  final double size;
}

/// A media file of the game; [width] is a fraction of the board's width.
class MapImage extends MapDecoration {
  const MapImage(this.image, this.center, {this.width = 0.2});
  final String image;
  final MapPoint center;
  final double width;
}

class MapLine extends MapDecoration {
  const MapLine(this.from, this.to);
  final MapPoint from;
  final MapPoint to;
}

class MapLayout {
  const MapLayout({
    required this.nodes,
    required this.edges,
    required this.columns,
    required this.rows,
    this.widthFactor = 1,
    this.scales = const {},
    this.decorations = const [],
  });

  /// How many screens wide the canvas is; never less than one.
  final double widthFactor;

  /// Size of each bubble relative to the default, where it was changed.
  final Map<String, double> scales;

  double scaleOf(String categoryId) => scales[categoryId] ?? 1;

  /// Centre of each category's bubble, by category id.
  final Map<String, MapPoint> nodes;

  /// Connections as (from, to) category ids.
  final List<(String, String)> edges;

  /// The grid the automatic layout used; tells the renderer how much room a
  /// bubble has.
  final int columns;
  final int rows;
  final List<MapDecoration> decorations;
}

/// Smallest and largest size a bubble can be given, relative to the default.
const double kMapMinScale = 0.6;
const double kMapMaxScale = 2.0;

/// Widest canvas, in screens.
const double kMapMaxWidth = 8;

/// How many steps of the path fit on one screen before the canvas grows.
const int kMapColumnsPerScreen = 4;

/// Lays a group out as a map: every category a bubble, each following
/// another. A plain sequence becomes a chain running left to right, a
/// category that several others follow becomes a branching point, as in an
/// organisation chart. A long path makes the canvas wider than the screen
/// rather than the bubbles smaller.
MapLayout layoutMap(CategoryGroup group) {
  final stored = group.data['mapLayout'];
  final layout = stored is Map ? stored : const {};
  final follows = layout['follows'] is Map ? layout['follows'] as Map : const {};
  final manual = layout['nodes'] is Map ? layout['nodes'] as Map : const {};
  final ids = [for (final category in group.categories) category.id];

  // Who each category comes after.
  final parent = <String, String?>{};
  for (final (i, id) in ids.indexed) {
    final choice = follows[id];
    if (choice is String && choice.isEmpty) {
      parent[id] = null;
    } else if (choice is String && choice != id && ids.contains(choice)) {
      parent[id] = choice;
    } else {
      parent[id] = i == 0 ? null : ids[i - 1];
    }
  }
  // A loop has no beginning to draw from; cut it where it closes.
  for (final id in ids) {
    final seen = {id};
    var at = parent[id];
    while (at != null) {
      if (!seen.add(at)) {
        parent[id] = null;
        break;
      }
      at = parent[at];
    }
  }

  final children = <String?, List<String>>{};
  for (final id in ids) {
    children.putIfAbsent(parent[id], () => []).add(id);
  }
  final roots = children[null] ?? const <String>[];
  final edges = [
    for (final id in ids)
      if (parent[id] != null) (parent[id]!, id),
  ];

  // A tidy tree: columns are steps along the path, leaves take one row
  // each, and a branching point sits level with the middle of its branches.
  final column = <String, int>{};
  final row = <String, double>{};
  var columns = 1;
  var nextRow = 0;
  void place(String id, int depth) {
    column[id] = depth;
    if (depth + 1 > columns) columns = depth + 1;
    final next = children[id] ?? const <String>[];
    if (next.isEmpty) {
      row[id] = (nextRow++).toDouble();
      return;
    }
    for (final child in next) {
      place(child, depth + 1);
    }
    row[id] = (row[next.first]! + row[next.last]!) / 2;
  }

  for (final root in roots) {
    place(root, 0);
  }
  final rows = nextRow < 1 ? 1 : nextRow;

  final storedWidth = layout['width'];
  final widthFactor = storedWidth is num
      ? storedWidth.toDouble().clamp(1.0, kMapMaxWidth).toDouble()
      : (columns / kMapColumnsPerScreen).clamp(1.0, kMapMaxWidth).toDouble();

  final nodes = <String, MapPoint>{};
  for (final id in ids) {
    final placed = manual[id];
    if (placed is Map && placed['x'] is num && placed['y'] is num) {
      nodes[id] = MapPoint((placed['x'] as num).toDouble().clamp(0, 1), (placed['y'] as num).toDouble().clamp(0, 1));
    } else {
      nodes[id] = MapPoint((column[id]! + 0.5) / columns, (row[id]! + 0.5) / rows);
    }
  }

  return MapLayout(
    nodes: nodes,
    edges: edges,
    columns: columns,
    rows: rows,
    widthFactor: widthFactor,
    scales: {
      for (final id in ids)
        if (manual[id] case {'scale': final num scale})
          id: scale.toDouble().clamp(kMapMinScale, kMapMaxScale).toDouble(),
    },
    decorations: [
      if (layout['decorations'] is List)
        for (final entry in layout['decorations'] as List) ?MapDecoration.fromMap(entry),
    ],
  );
}

/// Whether the map shows each question's short label instead of its points.
bool mapShowsLabels(CategoryGroup group) => group.data['mapLabels'] == 'label';
