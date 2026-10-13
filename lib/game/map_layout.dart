/// Where everything sits on a map board. Positions are fractions of the
/// board (0..1 in both directions), so a layout fits any screen.
///
/// Stored on the category group document as `mapLayout`:
///   follows:     {categoryId: categoryId | ""}   which bubble a category
///                comes after; "" starts a new chain; absent = the category
///                before it in the group's order
///   nodes:       {categoryId: {x, y}}            bubbles placed by hand
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
  const MapLayout({required this.nodes, required this.edges, required this.columns, required this.rows, this.decorations = const []});

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

/// Lays a group out as a map: every category a bubble, each following
/// another. A plain sequence becomes a chain (winding back and forth when it
/// is long), a category that several others follow becomes a branching
/// point, as in an organisation chart.
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

  final column = <String, int>{};
  final row = <String, double>{};
  final isChain = roots.length == 1 && children.values.every((list) => list.length <= 1);
  var columns = 1;
  var rows = 1;

  if (isChain && ids.length > 5) {
    // A long chain winds back and forth instead of shrinking to fit one row.
    rows = ids.length <= 10 ? 2 : 3;
    columns = (ids.length / rows).ceil();
    var id = roots.first;
    for (var i = 0; i < ids.length; i++) {
      final r = i ~/ columns;
      final c = i % columns;
      column[id] = r.isEven ? c : columns - 1 - c;
      row[id] = r.toDouble();
      final next = children[id];
      if (next == null || next.isEmpty) break;
      id = next.first;
    }
  } else {
    // A tidy tree: columns are steps along the path, leaves take one row
    // each, and a branching point sits level with the middle of its branches.
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
    rows = nextRow < 1 ? 1 : nextRow;
  }

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
    decorations: [
      if (layout['decorations'] is List)
        for (final entry in layout['decorations'] as List) ?MapDecoration.fromMap(entry),
    ],
  );
}

/// Whether the map shows each question's short label instead of its points.
bool mapShowsLabels(CategoryGroup group) => group.data['mapLabels'] == 'label';
