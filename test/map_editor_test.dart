import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/games/widgets/map_editor.dart';
import 'package:quiz_show/game/game.dart';

CategoryGroup group({Map<String, dynamic> layout = const {}, int count = 3}) => CategoryGroup(
      id: 'g',
      name: 'Round',
      type: BoardType.map,
      categories: [
        for (final (i, name) in ['Alpha', 'Beta', 'Gamma', 'Delta'].take(count).indexed) Category(id: 'c$i', name: name, index: i),
      ],
      data: {'mapLayout': layout},
    );

void main() {
  late Map<String, dynamic> saved;
  late int saves;

  Future<void> pumpEditor(WidgetTester tester, {Map<String, dynamic> layout = const {}, int count = 3}) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    saves = 0;
    saved = {};
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MapEditor(
          group: group(layout: layout, count: count),
          imageFile: (_) => null,
          pickImage: () async => 'picked.png',
          onSave: (next) {
            saved = next;
            saves++;
          },
        ),
      ),
    ));
    await tester.pump();
  }

  Finder bubble(String id) => find.byKey(ValueKey('bubble-$id'));

  testWidgets('dragging a bubble places it by hand and saves once, at the end', (tester) async {
    await pumpEditor(tester);
    final before = layoutMap(group()).nodes['c1']!;
    await tester.drag(bubble('c1'), const Offset(0, 150));
    await tester.pump();
    expect(saves, 1);
    final node = (saved['nodes'] as Map)['c1'] as Map;
    expect(node['x'], closeTo(before.x, 0.03));
    expect(node['y'], greaterThan(before.y + 0.1));
    // The others stay where the automatic layout puts them.
    expect((saved['nodes'] as Map).keys, ['c1']);
  });

  testWidgets('"Tidy up" hands every bubble back to the automatic layout', (tester) async {
    await pumpEditor(tester, layout: {
      'nodes': {
        'c0': {'x': 0.9, 'y': 0.9},
      },
    });
    await tester.tap(find.text('Tidy up'));
    await tester.pump();
    expect(saved['nodes'], isEmpty);
  });

  testWidgets('connecting: first bubble, then the one it leads to; again to take the arrow away', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('Connect'));
    await tester.pump();
    expect(find.text('Tap the bubble that comes first.'), findsOneWidget);
    await tester.tap(bubble('c0'));
    await tester.pump();
    await tester.tap(bubble('c2'));
    await tester.pump();
    // An arrow is added next to the one c2 had by default.
    expect(saved['after'], {
      'c2': ['c1', 'c0'],
    });
    expect(layoutMap(group(layout: saved)).edges.toSet(), {('c0', 'c1'), ('c1', 'c2'), ('c0', 'c2')});

    // The same two again take that arrow away.
    await tester.tap(bubble('c1'));
    await tester.pump();
    await tester.tap(bubble('c2'));
    await tester.pump();
    expect(saved['after'], {
      'c2': ['c0'],
    });
    // Both c1 (by default) and c2 now come after c0: a branch.
    expect(layoutMap(group(layout: saved)).edges.toSet(), {('c0', 'c1'), ('c0', 'c2')});

    // Tapping one bubble twice takes every arrow into it away: it starts a chain.
    await tester.tap(bubble('c1'));
    await tester.pump();
    await tester.tap(bubble('c1'));
    await tester.pump();
    expect(saved['after'], {
      'c2': ['c0'],
      'c1': <String>[],
    });
  });

  testWidgets('a branch can split and join again', (tester) async {
    await pumpEditor(tester, count: 4);
    await tester.tap(find.text('Connect'));
    await tester.pump();
    Future<void> connect(String from, String to) async {
      await tester.tap(bubble(from));
      await tester.pump();
      await tester.tap(bubble(to));
      await tester.pump();
    }

    // c0 -> c1 -> c2 -> c3 by default; make it c0 -> c1, c0 -> c2, both -> c3.
    await connect('c0', 'c2');
    await connect('c1', 'c2');
    await connect('c1', 'c3');
    final map = layoutMap(group(layout: saved, count: 4));
    expect(map.edges.toSet(), {('c0', 'c1'), ('c0', 'c2'), ('c1', 'c3'), ('c2', 'c3')});
    expect(map.nodes['c3']!.y, map.nodes['c0']!.y);
  });

  testWidgets('an arrow that would go round in a circle is refused', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('Connect'));
    await tester.pump();
    await tester.tap(bubble('c2'));
    await tester.pump();
    await tester.tap(bubble('c0'));
    await tester.pump();
    expect(saves, 0);
    expect(find.text('That arrow would go round in a circle.'), findsOneWidget);
  });

  testWidgets('a layout saved with "follows" is kept and saved as "after"', (tester) async {
    await pumpEditor(tester, layout: {
      'follows': {'c2': 'c0'},
    });
    await tester.tap(find.text('Wider'));
    await tester.pump();
    expect(saved.containsKey('follows'), isFalse);
    expect(saved['after'], {
      'c2': ['c0'],
    });
  });

  testWidgets('a title is added, selected, resized, renamed and removed', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('Title'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Finale');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Finale'), findsOneWidget);
    final added = (saved['decorations'] as List).single as Map;
    expect((added['type'], added['text']), ('title', 'Finale'));

    final size = added['size'] as num;
    await tester.tap(find.byTooltip('Larger'));
    await tester.pump();
    expect(((saved['decorations'] as List).single as Map)['size'], greaterThan(size));

    await tester.drag(find.byKey(const ValueKey('decoration-0')), const Offset(100, 200));
    await tester.pump();
    final moved = (saved['decorations'] as List).single as Map;
    expect(moved['x'], greaterThan(0.5));
    expect(moved['y'], greaterThan(0.2));

    await tester.tap(find.byTooltip('Remove'));
    await tester.pump();
    expect(saved['decorations'], isEmpty);
    expect(find.text('Finale'), findsNothing);
  });

  testWidgets('a line is moved by its ends; a picture is uploaded and added', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('Line'));
    await tester.pump();
    final line = Map.of((saved['decorations'] as List).single as Map);
    await tester.drag(find.byKey(const ValueKey('line-0-2')), const Offset(0, -200));
    await tester.pump();
    final moved = (saved['decorations'] as List).single as Map;
    expect(moved['y2'], lessThan(line['y2'] as num));
    expect((moved['x1'], moved['y1']), (line['x1'], line['y1']));

    await tester.tap(find.text('Picture'));
    await tester.pump();
    await tester.pump();
    final picture = (saved['decorations'] as List).last as Map;
    expect((picture['type'], picture['image']), ('image', 'picked.png'));
  });

  testWidgets('the canvas can be made wider than the screen, and is then moved with a slider', (tester) async {
    await pumpEditor(tester);
    expect(find.byType(Slider), findsNothing);
    await tester.tap(find.text('Wider'));
    await tester.pump();
    expect(saved['width'], 1.5);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('1.5 screens wide'), findsOneWidget);
    await tester.tap(find.text('Narrower'));
    await tester.pump();
    expect(saved['width'], 1.0);
  });

  testWidgets('a wide map can be moved with the slider straight away, without touching the stage first', (tester) async {
    await pumpEditor(tester, layout: {'width': 2.0});
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);
  });

  testWidgets('a tapped bubble can be made larger or smaller, and keeps its size when tidied', (tester) async {
    await pumpEditor(tester);
    await tester.tap(bubble('c1'));
    await tester.pump();
    await tester.tap(find.byTooltip('Larger'));
    await tester.pump();
    final scale = ((saved['nodes'] as Map)['c1'] as Map)['scale'] as num;
    expect(scale, greaterThan(1));
    // Sized, but still placed by the automatic layout.
    expect(((saved['nodes'] as Map)['c1'] as Map).containsKey('x'), isFalse);
    expect(layoutMap(group(layout: saved)).scaleOf('c1'), scale);

    await tester.drag(bubble('c1'), const Offset(0, 120));
    await tester.pump();
    expect(((saved['nodes'] as Map)['c1'] as Map).containsKey('x'), isTrue);
    await tester.tap(find.text('Tidy up'));
    await tester.pump();
    expect((saved['nodes'] as Map)['c1'], {'scale': scale});
  });

  testWidgets('the tools that need a selection are off without one', (tester) async {
    await pumpEditor(tester);
    expect(tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.delete_outline), matching: find.byType(IconButton))).onPressed, isNull);
    expect(tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.edit_outlined), matching: find.byType(IconButton))).onPressed, isNull);
  });
}
