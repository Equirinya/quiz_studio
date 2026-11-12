/// Where everything sits on a map board. Positions are fractions of the
/// canvas (0..1 in both directions), so a layout fits any screen. The canvas
/// is as tall as the screen and may be several screens wide; the board then
/// scrolls sideways.
///
/// Stored on the category group document as `mapLayout`:
///   width:       number   canvas width in screens; absent = as wide as the
///                automatic layout needs (about four bubbles per screen)
///   after:       {categoryId: [categoryId, ...]}  the bubbles with an
///                arrow into this one; [] starts a new chain; absent = the
///                category before it in the group's order. Several make a
///                merge, several categories after the same one a branch.
///   follows:     {categoryId: categoryId | ""}   the older form, one
///                arrow in at most; read where `after` has no entry and
///                turned into `after` when the layout is next saved
///   nodes:       {categoryId: {x, y, scale}}     x and y: a bubble placed by
///                hand; scale: its size relative to the others (default 1)
///   decorations: [{type: "title", text, x, y, size}
///                 {type: "image", image, x, y, width}
///                 {type: "line", x1, y1, x2, y2}]
/// and `mapLabels`: "points" (default) | "label".
library;

import 'dart:math';

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

/// The bubbles each category comes after, where that was chosen: `after`,
/// or `follows` for a category saved before a bubble could have several
/// arrows into it. Ids are not checked against the group; categories may
/// have gone since.
Map<String, List<String>> storedMapAfter(Object? stored) {
  final layout = stored is Map ? stored : const {};
  final result = <String, List<String>>{};
  if (layout['follows'] case final Map follows) {
    for (final MapEntry(:key, :value) in follows.entries) {
      if (key is String && value is String) result[key] = [if (value.isNotEmpty) value];
    }
  }
  if (layout['after'] case final Map after) {
    for (final MapEntry(:key, :value) in after.entries) {
      if (key is String && value is List) {
        result[key] = {
          for (final id in value)
            if (id is String && id.isNotEmpty) id,
        }.toList();
      }
    }
  }
  return result;
}

/// [stored] as a `mapLayout` with the arrows into [categoryId] coming from
/// [after], or from the category before it again when null. An older
/// `follows` is carried over into `after` on the way.
Map<String, dynamic> mapLayoutWithAfter(Object? stored, String categoryId, List<String>? after) {
  final layout = Map<String, dynamic>.from(stored is Map ? stored : const {});
  final chosen = storedMapAfter(layout);
  after == null ? chosen.remove(categoryId) : chosen[categoryId] = after;
  layout
    ..remove('follows')
    ..['after'] = chosen;
  return layout;
}

/// How wide a bubble of scale 1 is, as a fraction of the canvas, on a canvas
/// [widthFactor] 16:9 screens wide. [MapCanvas.bubbleWidth] works out the
/// same in pixels.
double mapBubbleWidth(int columns, int rows, double widthFactor) =>
    min(min(0.72 / columns, 9 / 16 * 1.4 / rows / widthFactor), 0.28 / widthFactor);

/// Lays a group out as a map: every category a bubble, with arrows from the
/// ones it comes after. A plain sequence becomes a chain running left to
/// right; a category with arrows to several others becomes a branching
/// point, as in an organisation chart, and one with arrows from several
/// others joins their branches again. A long path makes the canvas wider
/// than the screen rather than the bubbles smaller.
MapLayout layoutMap(CategoryGroup group) {
  final stored = group.data['mapLayout'];
  final layout = stored is Map ? stored : const {};
  final chosen = storedMapAfter(layout);
  final manual = layout['nodes'] is Map ? layout['nodes'] as Map : const {};
  final ids = [for (final category in group.categories) category.id];

  // Who each category comes after. A choice that only names categories that
  // are gone falls back to the default, so the bubble stays in the chain.
  final parents = <String, List<String>>{};
  for (final (i, id) in ids.indexed) {
    final choice = chosen[id];
    final known = [
      for (final other in choice ?? const <String>[])
        if (other != id && ids.contains(other)) other,
    ];
    parents[id] = choice != null && (choice.isEmpty || known.isNotEmpty) ? known : [if (i > 0) ids[i - 1]];
  }

  // A loop has no beginning to draw from. Walking the arrows from the first
  // category on, an arrow that leads back to a bubble still on the way is
  // left out: the loop is cut where it closes.
  final wanted = <String, List<String>>{for (final id in ids) id: []};
  for (final id in ids) {
    for (final parent in parents[id]!) {
      wanted[parent]!.add(id);
    }
  }
  final cut = <(String, String)>{};
  final onTheWay = <String>{};
  final visited = <String>{};
  void walk(String id) {
    visited.add(id);
    onTheWay.add(id);
    for (final next in wanted[id]!) {
      if (onTheWay.contains(next)) {
        cut.add((id, next));
      } else if (!visited.contains(next)) {
        walk(next);
      }
    }
    onTheWay.remove(id);
  }

  for (final id in ids) {
    if (!visited.contains(id)) walk(id);
  }
  final into = <String, List<String>>{for (final id in ids) id: []};
  final edges = <(String, String)>[];
  for (final id in ids) {
    for (final parent in parents[id]!) {
      if (cut.contains((parent, id))) continue;
      into[id]!.add(parent);
      edges.add((parent, id));
    }
  }

  // Columns are steps along the path: a bubble sits one step after the
  // furthest of those it comes after, so a merge waits for its longest
  // branch.
  final column = <String, int>{};
  int columnOf(String id) =>
      column[id] ??= into[id]!.isEmpty ? 0 : into[id]!.map(columnOf).reduce(max) + 1;
  for (final id in ids) {
    columnOf(id);
  }
  final columns = ids.isEmpty ? 1 : column.values.reduce(max) + 1;

  // Rows come from a tree: each bubble hangs off the furthest of those it
  // comes after (the first, when several are as far).
  final children = <String, List<String>>{};
  final roots = <String>[];
  for (final id in ids) {
    final from = into[id]!;
    if (from.isEmpty) {
      roots.add(id);
      continue;
    }
    final parent = from.firstWhere((p) => column[p] == column[id]! - 1);
    children.putIfAbsent(parent, () => []).add(id);
  }

  // A tidy tree: leaves take one row each, and a branching point sits level
  // with the middle of its branches.
  final row = <String, double>{};
  var nextRow = 0;
  void place(String id) {
    final next = children[id] ?? const <String>[];
    if (next.isEmpty) {
      row[id] = (nextRow++).toDouble();
      return;
    }
    for (final child in next) {
      place(child);
    }
    row[id] = (row[next.first]! + row[next.last]!) / 2;
  }

  for (final root in roots) {
    place(root);
  }
  final rows = nextRow < 1 ? 1 : nextRow;

  // Where branches join, the joining bubble (and what comes after it) moves
  // level with the middle of the bubbles it comes after, unless that would
  // put it on top of another one.
  for (final id in [...ids]..sort((a, b) => column[a]!.compareTo(column[b]!))) {
    final from = into[id]!;
    if (from.length < 2) continue;
    final delta = from.map((p) => row[p]!).reduce((a, b) => a + b) / from.length - row[id]!;
    if (delta == 0) continue;
    final moving = <String>{};
    void collect(String at) {
      if (moving.add(at)) (children[at] ?? const <String>[]).forEach(collect);
    }

    collect(id);
    final blocked = moving.any((m) => ids.any(
          (other) => !moving.contains(other) && column[other] == column[m] && (row[other]! - row[m]! - delta).abs() < 1,
        ));
    if (blocked) continue;
    for (final m in moving) {
      row[m] = row[m]! + delta;
    }
  }

  final storedWidth = layout['width'];
  final widthFactor = storedWidth is num
      ? storedWidth.toDouble().clamp(1.0, kMapMaxWidth).toDouble()
      : (columns / kMapColumnsPerScreen).clamp(1.0, kMapMaxWidth).toDouble();

  final scales = {
    for (final id in ids)
      if (manual[id] case {'scale': final num scale})
        id: scale.toDouble().clamp(kMapMinScale, kMapMaxScale).toDouble(),
  };
  bool placedByHand(String id) => manual[id] is Map && manual[id]['x'] is num && manual[id]['y'] is num;

  // Equal space between the columns, edge to edge, however wide the bubbles
  // in them are: a column is as wide as its widest bubble.
  final bubble = mapBubbleWidth(columns, rows, widthFactor);
  final widths = List.filled(columns, 0.0);
  for (final id in ids) {
    if (placedByHand(id)) continue;
    widths[column[id]!] = max(widths[column[id]!], bubble * (scales[id] ?? 1));
  }
  for (var c = 0; c < columns; c++) {
    if (widths[c] == 0) widths[c] = bubble;
  }
  final space = (1 - widths.fold(0.0, (a, b) => a + b)) / columns;
  final centres = <double>[];
  var left = 0.0;
  for (final (c, width) in widths.indexed) {
    // Columns all as wide as each other simply share the canvas out evenly.
    centres.add(widths.every((w) => w == width) ? (c + 0.5) / columns : left + space / 2 + width / 2);
    left += width + space;
  }

  final nodes = <String, MapPoint>{};
  for (final id in ids) {
    final placed = manual[id];
    if (placed is Map && placed['x'] is num && placed['y'] is num) {
      nodes[id] = MapPoint((placed['x'] as num).toDouble().clamp(0, 1), (placed['y'] as num).toDouble().clamp(0, 1));
    } else {
      nodes[id] = MapPoint(centres[column[id]!].clamp(0, 1).toDouble(), (row[id]! + 0.5) / rows);
    }
  }

  return MapLayout(
    nodes: nodes,
    edges: edges,
    columns: columns,
    rows: rows,
    widthFactor: widthFactor,
    scales: scales,
    decorations: [
      if (layout['decorations'] is List)
        for (final entry in layout['decorations'] as List) ?MapDecoration.fromMap(entry),
    ],
  );
}

/// Whether the map shows each question's short label instead of its points.
bool mapShowsLabels(CategoryGroup group) => group.data['mapLabels'] == 'label';
