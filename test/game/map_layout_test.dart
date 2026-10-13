import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

CategoryGroup group(int count, {Map<String, dynamic> layout = const {}}) => CategoryGroup(
      id: 'g',
      type: BoardType.map,
      categories: [for (var i = 0; i < count; i++) Category(id: 'c$i', name: 'C$i', index: i)],
      data: {'mapLayout': layout},
    );

void main() {
  test('by default the categories form one chain in their order', () {
    final map = layoutMap(group(3));
    expect(map.edges, [('c0', 'c1'), ('c1', 'c2')]);
    expect((map.columns, map.rows), (3, 1));
    expect(map.nodes['c0'], const MapPoint(1 / 6, 0.5));
    expect(map.nodes['c2'], const MapPoint(5 / 6, 0.5));
  });

  test('a long chain winds back and forth', () {
    final map = layoutMap(group(8));
    expect((map.columns, map.rows), (4, 2));
    // First row left to right, second row right to left.
    expect(map.nodes['c3']!.x, closeTo(7 / 8, 1e-9));
    expect(map.nodes['c4']!.x, closeTo(7 / 8, 1e-9));
    expect(map.nodes['c4']!.y, 0.75);
    expect(map.nodes['c7']!.x, closeTo(1 / 8, 1e-9));
    expect(map.edges, hasLength(7));
  });

  test('two categories following the same one make a branch', () {
    final map = layoutMap(group(4, layout: {
      'follows': {'c2': 'c0', 'c3': 'c2'},
    }));
    // c0 -> c1, and c0 -> c2 -> c3
    expect(map.edges.toSet(), {('c0', 'c1'), ('c0', 'c2'), ('c2', 'c3')});
    expect((map.columns, map.rows), (3, 2));
    expect(map.nodes['c1']!.y, 0.25);
    expect(map.nodes['c2']!.y, 0.75);
    expect(map.nodes['c3']!.y, 0.75);
    // The branching point sits between its branches.
    expect(map.nodes['c0'], const MapPoint(1 / 6, 0.5));
  });

  test('an empty "follows" starts a second chain', () {
    final map = layoutMap(group(4, layout: {
      'follows': {'c2': ''},
    }));
    expect(map.edges, [('c0', 'c1'), ('c2', 'c3')]);
    expect(map.rows, 2);
    expect(map.nodes['c0']!.y, 0.25);
    expect(map.nodes['c2']!.y, 0.75);
    expect(map.nodes['c2']!.x, map.nodes['c0']!.x);
  });

  test('loops, unknown targets and following oneself fall back safely', () {
    final map = layoutMap(group(3, layout: {
      'follows': {'c0': 'c2', 'c1': 'c1', 'c2': 'gone'},
    }));
    expect(map.nodes.keys, ['c0', 'c1', 'c2']);
    for (final point in map.nodes.values) {
      expect(point.x, inInclusiveRange(0, 1));
      expect(point.y, inInclusiveRange(0, 1));
    }
    // Every edge is drawn once and the graph has a beginning.
    expect(map.edges.length, lessThan(3));
  });

  test('a bubble placed by hand stays where it was put', () {
    final map = layoutMap(group(3, layout: {
      'nodes': {
        'c1': {'x': 0.9, 'y': 0.1},
        'c2': {'x': 5, 'y': -1},
      },
    }));
    expect(map.nodes['c1'], const MapPoint(0.9, 0.1));
    expect(map.nodes['c2'], const MapPoint(1, 0));
    expect(map.nodes['c0'], const MapPoint(1 / 6, 0.5));
  });

  test('decorations are read; broken ones are skipped', () {
    final map = layoutMap(group(1, layout: {
      'decorations': [
        {'type': 'title', 'text': 'Round 2', 'x': 0.5, 'y': 0.1, 'size': 2},
        {'type': 'image', 'image': 'logo.png', 'x': 0.1, 'y': 0.9},
        {'type': 'line', 'x1': 0, 'y1': 0, 'x2': 1, 'y2': 1},
        {'type': 'title', 'text': '', 'x': 0, 'y': 0},
        {'type': 'image', 'x': 0, 'y': 0},
        {'type': 'hologram'},
        'junk',
      ],
    }));
    expect(map.decorations, hasLength(3));
    expect((map.decorations[0] as MapTitle).size, 2);
    expect((map.decorations[1] as MapImage).width, 0.2);
    expect((map.decorations[2] as MapLine).to, const MapPoint(1, 1));
  });

  test('an empty group is an empty map', () {
    final map = layoutMap(group(0));
    expect(map.nodes, isEmpty);
    expect(map.edges, isEmpty);
  });

  test('label mode is read from the group', () {
    expect(mapShowsLabels(group(1)), isFalse);
    expect(mapShowsLabels(CategoryGroup(id: 'g', data: const {'mapLabels': 'label'})), isTrue);
  });
}
