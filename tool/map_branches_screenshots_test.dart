// The map board with branches that split and join again, and bubbles of
// different sizes after "Tidy up". Writes tool/screenshots/map_branches/.
//
//   flutter test tool/map_branches_screenshots_test.dart --update-goldens

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/core/theme.dart';
import 'package:quiz_show/features/games/widgets/map_editor.dart';
import 'package:quiz_show/features/session/boards/map_board.dart';
import 'package:quiz_show/game/game.dart';

final _fonts = '${Platform.environment['FLUTTER_ROOT'] ?? '/home/jacob/development/flutter'}/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  Future<ByteData> read(String name) => Future.value(ByteData.view(File('$_fonts/$name').readAsBytesSync().buffer));
  final roboto = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(read(name));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'))).load();
}

const _names = ['Warm-up', 'Geography', 'History', 'Music', 'Movies', 'Science', 'Finale'];

/// Warm-up splits into Geography, History and Music; Geography and History
/// join again in Movies, Music goes on to Science, and both end in the
/// Finale. Some bubbles are larger or smaller than the others.
CategoryGroup branches({Map<String, dynamic> nodes = const {}}) => CategoryGroup(
  id: 'm',
  type: BoardType.map,
  data: {
    'mapLayout': {
      'after': {
        'c2': ['c0'],
        'c3': ['c0'],
        'c4': ['c1', 'c2'],
        'c5': ['c3'],
        'c6': ['c4', 'c5'],
      },
      'nodes': nodes,
    },
  },
  categories: [
    for (final (c, name) in _names.indexed)
      Category(
        id: 'c$c',
        name: name,
        index: c,
        questions: [for (var q = 0; q < 3; q++) Question(id: 'q$q', type: QuestionType.free, pointsPlus: (q + 1) * 100)],
      ),
  ],
);

/// A plain chain with bubbles of very different widths.
CategoryGroup sizes() => CategoryGroup(
  id: 's',
  type: BoardType.map,
  data: {
    'mapLayout': {
      'nodes': {
        'c1': {'scale': 1.8},
        'c2': {'scale': 0.6},
        'c3': {'scale': 1.4},
      },
    },
  },
  categories: [
    for (final (c, name) in _names.take(5).indexed)
      Category(
        id: 'c$c',
        name: name,
        index: c,
        questions: [for (var q = 0; q < 4; q++) Question(id: 'q$q', type: QuestionType.free, pointsPlus: (q + 1) * 100)],
      ),
  ],
);

void main() {
  setUpAll(_loadFonts);

  Future<void> shot(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/map_branches/$name.png'));

  Future<void> board(WidgetTester tester, String name, CategoryGroup group, SessionState state) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.dark),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: MapBoard(group: group, state: state, imageFile: (_) => null),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await shot(name);
  }

  Future<void> editor(WidgetTester tester, String name, CategoryGroup group) async {
    tester.view.physicalSize = const Size(1280, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          appBar: AppBar(title: const Text("Map · Round 2")),
          body: MapEditor(group: group, imageFile: (_) => null, pickImage: () async => null, onSave: (_) {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('board: split and join', (tester) async {
    await board(
      tester,
      'board_split_join',
      branches(
        nodes: {
          'c4': {'scale': 1.3},
        },
      ),
      const SessionState(played: {'c0/q0', 'c0/q1', 'c0/q2', 'c2/q0'}, current: QuestionRef('c2', 'q1'), phase: Phase.question),
    );
  });

  testWidgets('board: different sizes, tidied', (tester) async {
    await board(tester, 'board_sizes', sizes(), const SessionState());
  });

  testWidgets('editor: split and join, connecting', (tester) async {
    await editor(tester, 'editor_split_join', branches());
    await tester.tap(find.text('Connect'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bubble-c3')));
    await tester.pump(const Duration(milliseconds: 300));
    await shot('editor_split_join');
  });

  testWidgets('editor: different sizes after "Tidy up"', (tester) async {
    await editor(tester, 'editor_sizes', sizes());
    await shot('editor_sizes');
  });
}
