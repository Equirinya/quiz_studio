// Renders the session screens to PNG files for a quick look without a device:
//   flutter test tool/screenshot_test.dart --update-goldens
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quiz_show/features/assistant/assistant_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quiz_show/core/theme.dart';
import 'package:quiz_show/features/buzzers/buzzer_link.dart';
import 'package:quiz_show/features/buzzers/buzzers_page.dart';
import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/games/pages/category_editor_page.dart';
import 'package:quiz_show/features/games/widgets/cards_dialog.dart';
import 'package:quiz_show/features/games/widgets/question_preview.dart';
import 'package:quiz_show/features/games/widgets/map_editor.dart';
import 'package:quiz_show/features/player/pages/player_page.dart';
import 'package:quiz_show/features/session/pages/screen_overlays.dart';
import 'package:quiz_show/features/session/pages/sessions_page.dart';
import 'package:quiz_show/features/session/session_client.dart';
import 'package:quiz_show/features/settings/account_page.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/boards/map_board.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/presenter_window.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import '../test/fake_buzzer_port.dart';
import '../test/game/connections_fixture.dart';
import '../test/game/fixture.dart';

const _fonts = '/home/jacob/development/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  Future<ByteData> read(String name) => Future.value(ByteData.view(File('$_fonts/$name').readAsBytesSync().buffer));
  final roboto = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(read(name));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'));
  await icons.load();
}

void main() {
  // Real file I/O: has to happen outside the fake clock of testWidgets.
  setUpAll(_loadFonts);

  late SessionHost host;

  ThemeData theme(Brightness brightness) => buildAppTheme(brightness);

  /// The controller as on a phone.
  Future<void> phone(WidgetTester tester, List<Command> commands, {Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: fixtureState());
    final connection = SessionConnection.local(host, game: fixtureGame());
    addTearDown(connection.dispose);
    for (final command in commands) {
      host.dispatch(command);
    }
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(brightness),
      home: Scaffold(
        appBar: AppBar(title: const Text("Quiz night")),
        body: ControllerView(
          connection: connection,
          onConnectDevices: () {},
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The presenter as on a 16:9 screen.
  Future<void> screen(WidgetTester tester, List<Command> commands) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: fixtureState());
    final connection = SessionConnection.local(host, game: fixtureGame());
    addTearDown(connection.dispose);
    for (final command in commands) {
      host.dispatch(command);
    }
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.dark),
      home: Scaffold(body: PresenterView(connection: connection)),
    ));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> shot(String name) async {
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/$name.png'));
    // A round with a timer leaves it running; stop it before the test ends.
    try {
      host.dispatch(const ClearAnswers());
    } on Error catch (_) {
      // This screenshot has no session behind it.
    }
  }

  Future<void> tapText(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('controller: board', (tester) async {
    await phone(tester, const [AdjustPoints('red', 300), OpenQuestion(free), CloseQuestion(), AdjustPoints('blue', 100)]);
    await shot('controller_board');
  });

  testWidgets('controller: board sheet', (tester) async {
    await phone(tester, const [OpenQuestion(free), CloseQuestion()]);
    await tapText(tester, find.widgetWithText(TextButton, 'Board'));
    await tapText(tester, find.widgetWithText(FilledButton, '200').first);
    await shot('controller_board_sheet');
  });

  testWidgets('controller: answering', (tester) async {
    await phone(tester, const [SetQueueBuzzers(true), OpenQuestion(abcd), Reveal(1), Reveal(1), Buzz('red'), Buzz('blue')]);
    await shot('controller_answering');
  });

  testWidgets('controller: feud, dark', (tester) async {
    await phone(
      tester,
      const [OpenQuestion(feud), Buzz('blue'), FeudToggle(0), FeudToggle(2), FeudWrong()],
      brightness: Brightness.dark,
    );
    await shot('controller_feud');
  });

  testWidgets('controller: team sheet', (tester) async {
    await phone(tester, const [OpenQuestion(free)]);
    await tapText(tester, find.text('Red'));
    await shot('controller_team_sheet');
  });

  testWidgets('controller: setup sheet', (tester) async {
    await phone(tester, const []);
    await tapText(tester, find.widgetWithText(TextButton, 'Setup'));
    await shot('controller_setup_sheet');
  });

  testWidgets('presenter: board', (tester) async {
    await screen(tester, const [AdjustPoints('red', 300), OpenQuestion(free), CloseQuestion(), AdjustPoints('blue', 100)]);
    await shot('presenter_board');
  });

  testWidgets('presenter: abcd', (tester) async {
    await screen(tester, const [OpenQuestion(abcd), Reveal(1), Reveal(1), Reveal(1), Buzz('red')]);
    await shot('presenter_abcd');
  });

  testWidgets('presenter: feud', (tester) async {
    await screen(tester, const [OpenQuestion(feud), Buzz('blue'), FeudToggle(0), FeudToggle(2), FeudWrong()]);
    await shot('presenter_feud');
  });

  Future<void> player(WidgetTester tester, List<Command> commands) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: fixtureState(), game: fixtureGame());
    addTearDown(host.dispose);
    for (final command in commands) {
      host.dispatch(command);
    }
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      home: Scaffold(
        body: SafeArea(child: PlayerView(view: PublicView(host.publicState), teamId: 'red', send: (_) {}, onLeave: () {})),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('player: buzzer', (tester) async {
    await player(tester, const [AdjustPoints('red', 300), OpenQuestion(free)]);
    await shot('player_buzzer');
  });

  testWidgets('player: waiting', (tester) async {
    await player(tester, const [OpenQuestion(free), Buzz('blue')]);
    await shot('player_waiting');
  });

  testWidgets('player: choice', (tester) async {
    await player(tester, const [OpenQuestion(abcd), Reveal(1), Reveal(1), OpenAnswers(CompanionSpec(kind: CompanionKind.choice, options: ['a', 'b', 'c', 'd']))]);
    await shot('player_choice');
  });

  const games = [
    GameSummary(id: 'g1', name: 'Christmas quiz 2026', role: GameRole.admin),
    GameSummary(id: 'g2', name: 'Pub quiz', role: GameRole.full),
  ];

  Future<void> page(WidgetTester tester, Widget body) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      home: Scaffold(appBar: AppBar(title: const Text("Quiz Studio")), body: body),
    ));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('sessions: list', (tester) async {
    await page(
      tester,
      SessionsList(
        sessions: const [
          SessionSummary(id: 's1', name: 'Quiz night', gameId: 'g1'),
          SessionSummary(id: 's2', name: 'Birthday', gameId: null),
        ],
        gameNames: {for (final game in games) game.id: game.name},
        onControl: (_) {},
        onPresent: (_) {},
        onChangeGame: (_) {},
        onDelete: (_) {},
      ),
    );
    await shot('sessions_list');
  });

  testWidgets('sessions: new', (tester) async {
    await page(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(onPressed: () => showNewSessionSheet(context, games: games), child: const Text("open")),
        ),
      ),
    );
    await tapText(tester, find.text('open'));
    await tapText(tester, find.text('Pub quiz'));
    await shot('sessions_new');
  });

  testWidgets('presenter: card', (tester) async {
    await screen(tester, const [
      OpenQuestion(abcd),
      Reveal(1),
      ShowCard(OverlayCard(title: 'Short break', text: 'Grab a drink. We continue with the finale in ten minutes.')),
    ]);
    await shot('presenter_card');
  });

  testWidgets('presenter: confetti', (tester) async {
    await screen(tester, const [AdjustPoints('red', 900), AdjustPoints('blue', 700)]);
    tester.state<ScreenEffectLayerState>(find.byType(ScreenEffectLayer)).play(screenEffectConfetti);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await shot('presenter_confetti');
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('controller: effects sheet', (tester) async {
    await phone(tester, const [SetMusic(musicBackground), ShowCard(OverlayCard(text: 'Back in ten'))]);
    await tapText(tester, find.widgetWithText(TextButton, 'Effects'));
    await shot('controller_effects_sheet');
  });

  /// A map with a branch after the first bubble, labels on one category, and
  /// a title and a line added by hand.
  CategoryGroup mapGroup({bool labels = false, int count = 5}) {
    const names = ['Warm-up', 'Geography', 'History', 'Music', 'Finale', 'Science', 'Sports', 'Movies'];
    return CategoryGroup(
      id: 'm',
      type: BoardType.map,
      data: {
        'mapLabels': labels ? 'label' : 'points',
        'mapLayout': {
          'follows': count == 5 ? {'c2': 'c0', 'c3': 'c2', 'c4': 'c1'} : const <String, dynamic>{},
          'decorations': count == 5
              ? [
                  {'type': 'title', 'text': 'The road\nto the finale', 'x': 0.16, 'y': 0.12, 'size': 1.4},
                  {'type': 'line', 'x1': 0.05, 'y1': 0.24, 'x2': 0.27, 'y2': 0.24},
                ]
              : const <dynamic>[],
        },
      },
      categories: [
        for (var c = 0; c < count; c++)
          Category(
            id: 'c$c',
            name: names[c],
            index: c,
            questions: [
              for (var q = 0; q < 4; q++)
                Question(
                  id: 'q$q',
                  type: QuestionType.free,
                  pointsPlus: (q + 1) * 100,
                  description: const ['Capitals', 'Rivers', 'Flags', 'Borders'][q],
                ),
            ],
          ),
      ],
    );
  }

  Future<void> mapShot(WidgetTester tester, String name, CategoryGroup group, SessionState state) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.dark),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: MapBoard(group: group, state: state, imageFile: (_) => null),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await shot(name);
  }

  testWidgets('map: branching, points', (tester) async {
    await mapShot(
      tester,
      'map_branching',
      mapGroup(),
      const SessionState(played: {'c0/q0', 'c0/q1', 'c0/q2', 'c0/q3', 'c1/q0'}, current: QuestionRef('c2', 'q1'), phase: Phase.question),
    );
  });

  testWidgets('map: branching, labels', (tester) async {
    await mapShot(tester, 'map_labels', mapGroup(labels: true), const SessionState());
  });

  testWidgets('map: long chain', (tester) async {
    await mapShot(tester, 'map_chain', mapGroup(count: 8), const SessionState(played: {'c0/q0'}));
  });

  // ── the whiteboard scenario ───────────────────────────────────────────────

  /// "8", written by hand.
  String eight() => encodeDrawing([
        [
          for (var i = 0; i <= 40; i++)
            (0.5 + 0.11 * math.sin(i / 40 * 2 * math.pi), 0.33 - 0.16 * math.cos(i / 40 * 2 * math.pi)),
        ],
        [
          for (var i = 0; i <= 40; i++)
            (0.5 + 0.14 * math.sin(i / 40 * 2 * math.pi), 0.68 - 0.19 * math.cos(i / 40 * 2 * math.pi)),
        ],
      ]);

  /// "9", wrong.
  String nine() => encodeDrawing([
        [
          for (var i = 0; i <= 40; i++)
            (0.5 + 0.13 * math.sin(i / 40 * 2 * math.pi), 0.36 - 0.17 * math.cos(i / 40 * 2 * math.pi)),
        ],
        [(0.63, 0.36), (0.62, 0.6), (0.55, 0.82), (0.42, 0.86)],
      ]);

  List<Command> scenario() => [
        const OpenQuestion(sum),
        SubmitAnswer('red', PlayerAnswer(drawing: eight())),
        const LockAnswer('red'),
        SubmitAnswer('blue', PlayerAnswer(drawing: nine())),
      ];

  testWidgets('scenario: tablet whiteboard', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: fixtureState(), game: fixtureGame());
    addTearDown(host.dispose);
    host.dispatch(const OpenQuestion(sum));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      home: Scaffold(
        body: SafeArea(
          child: StreamBuilder<SessionState>(
            stream: host.states,
            builder: (context, _) => PlayerView(
              view: PublicView(host.publicState),
              teamId: 'red',
              send: (command) => host.dispatch(command, sender: const Sender(Role.player, teamId: 'red')),
              onLeave: () {},
              link: LinkStatus.lan,
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    // Write an 8 on the board, the way a finger would.
    final board = tester.getRect(find.descendant(of: find.byType(WhiteboardPad), matching: find.byType(CustomPaint)).first);
    for (final stroke in decodeDrawing(eight())) {
      final gesture = await tester.startGesture(board.topLeft + Offset(stroke.first.$1 * board.width, stroke.first.$2 * board.height));
      for (final point in stroke.skip(1)) {
        await gesture.moveTo(board.topLeft + Offset(point.$1 * board.width, point.$2 * board.height));
      }
      await gesture.up();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await shot('scenario_tablet');
  });

  testWidgets('scenario: controller while they write', (tester) async {
    await phone(tester, scenario());
    await shot('scenario_controller');
  });

  testWidgets('scenario: controller rating', (tester) async {
    await phone(tester, [
      ...scenario(),
      const RevealNextAnswer(),
      const RevealNextAnswer(),
      const RateAnswer('red', correct: true),
      const RateAnswer('blue', correct: false),
    ]);
    await shot('scenario_controller_rated');
  });

  testWidgets('scenario: big screen while they write', (tester) async {
    await screen(tester, scenario());
    await shot('scenario_screen_writing');
  });

  testWidgets('scenario: big screen, answers shown and rated', (tester) async {
    await screen(tester, [
      ...scenario(),
      const RevealNextAnswer(),
      const RevealNextAnswer(),
      const RateAnswer('red', correct: true),
      const RateAnswer('blue', correct: false),
    ]);
    await shot('scenario_screen_rated');
  });

  Future<void> companion(WidgetTester tester, String name, CompanionSpec spec, {PlayerAnswer? answer}) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: fixtureState(), game: fixtureGame());
    addTearDown(host.dispose);
    host
      ..dispatch(const OpenQuestion(estimate))
      ..dispatch(OpenAnswers(spec));
    if (answer != null) host.dispatch(SubmitAnswer('red', answer));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      home: Scaffold(
        body: SafeArea(child: PlayerView(view: PublicView(host.publicState), teamId: 'red', send: (_) {}, onLeave: () {})),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await shot(name);
  }

  testWidgets('companion: slider', (tester) async {
    await companion(tester, 'companion_slider', const CompanionSpec(kind: CompanionKind.slider, min: 0, max: 500, step: 10, unit: 'km', timerSeconds: 30));
  });

  testWidgets('companion: order', (tester) async {
    await companion(tester, 'companion_order', const CompanionSpec(kind: CompanionKind.order, options: ['Mercury', 'Venus', 'Earth', 'Mars']));
  });

  testWidgets('companion: match', (tester) async {
    await companion(
      tester,
      'companion_match',
      const CompanionSpec(kind: CompanionKind.match, options: ['France', 'Italy', 'Spain'], targets: ['Paris', 'Rome', 'Madrid']),
    );
  });

  testWidgets('companion: list whiteboard', (tester) async {
    await companion(tester, 'companion_list', const CompanionSpec(kind: CompanionKind.whiteboard, background: 'list', listRows: 5));
  });

  testWidgets('scenario: phone whiteboard', (tester) async {
    await companion(
      tester,
      'scenario_phone',
      const CompanionSpec(kind: CompanionKind.whiteboard, timerSeconds: 30),
      answer: PlayerAnswer(drawing: eight()),
    );
  });

  testWidgets('map editor', (tester) async {
    tester.view.physicalSize = const Size(1280, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      home: Scaffold(
        appBar: AppBar(title: const Text("Map · Round 2")),
        body: MapEditor(group: mapGroup(), imageFile: (_) => null, pickImage: () async => null, onSave: (_) {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    // Select the title, as after tapping it.
    await tester.tap(find.byKey(const ValueKey('decoration-0')));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/map_editor.png'));
  });

  Future<void> questionCard(WidgetTester tester, String name, Map<String, dynamic> data) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      home: Scaffold(
        appBar: AppBar(title: const Text("Maths")),
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            QuestionCard(gameId: 'g', categoryId: 'c', question: Question.fromMap('q', data), initiallyExpanded: true),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/$name.png'));
  }

  testWidgets('editor: question with a whiteboard', (tester) async {
    await questionCard(tester, 'editor_question_whiteboard', {
      'type': 'free',
      'question': 'What is 3+5?',
      'answerHint': '8',
      'noBuzzer': true,
      'pointsPlus': 400,
      'pointsMinus': 0,
      'companion': {'kind': 'whiteboard', 'timer': 30, 'background': 'list', 'listRows': 5},
    });
  });

  testWidgets('editor: question with pairs to match', (tester) async {
    await questionCard(tester, 'editor_question_match', {
      'type': 'free',
      'question': 'Which capital belongs to which country?',
      'pointsPlus': 300,
      'pointsMinus': 0,
      'companion': {
        'kind': 'match',
        'timer': 60,
        'options': ['France', 'Italy', 'Spain'],
        'targets': ['Paris', 'Rome', 'Madrid'],
      },
    });
  });

  /// A stand-in for a picture to draw on: an outline map with three dots.
  Uint8List outlineMap() {
    final image = img.Image(width: 800, height: 600)..clear(img.ColorRgb8(236, 244, 250));
    img.fillPolygon(
      image,
      vertices: [img.Point(150, 120), img.Point(520, 80), img.Point(680, 300), img.Point(560, 520), img.Point(240, 480), img.Point(110, 300)],
      color: img.ColorRgb8(200, 224, 190),
    );
    for (final (x, y) in [(260, 220), (470, 190), (480, 400)]) {
      img.fillCircle(image, x: x, y: y, radius: 14, color: img.ColorRgb8(190, 60, 50));
    }
    return img.encodePng(image);
  }

  testWidgets('companion: whiteboard on a picture', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final picture = MemoryImage(outlineMap());
    host = SessionHost(initial: fixtureState(), game: fixtureGame());
    addTearDown(host.dispose);
    host
      ..dispatch(const OpenQuestion(estimate))
      ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.whiteboard, background: 'image', backgroundImage: 'map.png')));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      home: Scaffold(
        body: SafeArea(
          child: PlayerView(view: PublicView(host.publicState), teamId: 'red', send: (_) {}, onLeave: () {}, backgroundImage: picture),
        ),
      ),
    ));
    await tester.runAsync(() => precacheImage(picture, tester.element(find.byType(PlayerView))));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // Circle one of the dots.
    final board = tester.getRect(find.descendant(of: find.byType(WhiteboardPad), matching: find.byType(CustomPaint)).first);
    final gesture = await tester.startGesture(board.center);
    for (var i = 0; i <= 30; i++) {
      await gesture.moveTo(board.center + Offset(70 * math.cos(i / 30 * 2 * math.pi), 70 * math.sin(i / 30 * 2 * math.pi)));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    await shot('companion_picture');
  });

  testWidgets('editor: whiteboard on a picture', (tester) async {
    await questionCard(tester, 'editor_question_picture', {
      'type': 'free',
      'question': 'Mark where the Eiffel Tower stands.',
      'noBuzzer': true,
      'pointsPlus': 300,
      'pointsMinus': 0,
      'companion': {'kind': 'whiteboard', 'timer': 45, 'background': 'image', 'backgroundImage': 'map.png'},
    });
  });

  testWidgets('map: wide canvas, mid game', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final group = CategoryGroup(
      id: 'm',
      type: BoardType.map,
      data: {
        'mapLayout': {
          'nodes': {
            'c4': {'scale': 1.35},
          },
        },
      },
      categories: mapGroup(count: 8).categories,
    );
    Widget board(SessionState state) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme(Brightness.dark),
          home: Scaffold(
            body: Padding(padding: const EdgeInsets.all(24), child: MapBoard(group: group, state: state, imageFile: (_) => null)),
          ),
        );
    await tester.pumpWidget(board(const SessionState()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(board(const SessionState(
      phase: Phase.question,
      current: QuestionRef('c4', 'q1'),
      played: {'c0/q0', 'c0/q1', 'c0/q2', 'c0/q3', 'c1/q0', 'c1/q1', 'c1/q2', 'c1/q3', 'c2/q0', 'c2/q1', 'c2/q2', 'c2/q3', 'c3/q0', 'c3/q1', 'c3/q2', 'c3/q3', 'c4/q0'},
    )));
    await tester.pumpAndSettle();
    await shot('map_wide_in_game');
  });

  testWidgets('map editor: wide canvas, bubble selected', (tester) async {
    tester.view.physicalSize = const Size(1280, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      home: Scaffold(
        appBar: AppBar(title: const Text("Map · Round 2")),
        body: MapEditor(group: mapGroup(count: 8), imageFile: (_) => null, pickImage: () async => null, onSave: (_) {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('bubble-c1')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Larger'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Larger'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/map_editor_wide.png'));
  });

  testWidgets('buzzers: test and teams', (tester) async {
    tester.view.physicalSize = const Size(900, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var now = 1000;
    final port = FakePort();
    final link = BuzzerLink(port, clock: () => now);
    link.use('COM3');
    const teams = [Team(id: 'red', name: 'Red'), Team(id: 'blue', name: 'Blue'), Team(id: 'green', name: 'Green'), Team(id: 'gold', name: 'Gold')];
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      home: Scaffold(
        appBar: AppBar(title: const Text("Buzzers")),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BuzzersView(
              link: link,
              teams: teams,
              assignments: const {3: 'red'},
              onPort: (_) {},
              onAssign: (_, _) {},
              onThreshold: (_, _) {},
            ),
          ],
        ),
      ),
    ));
    Future<void> send(String line, {int millis = 80}) async {
      port.send('$line\n');
      for (var i = 0; i < millis ~/ 10; i++) {
        now += 10;
        await tester.pump(const Duration(milliseconds: 10));
      }
    }

    // A minute of readings, then three presses in a row; the last still held.
    for (var i = 0; i < 12; i++) {
      await send('0:12,1:20,2:8,3:15,4:10', millis: 250);
    }
    await send('0:12,1:870,2:8,3:15,4:10');
    await send('0:12,1:20,2:8,3:15,4:10');
    await send('0:12,1:20,2:8,3:910,4:10');
    await send('0:12,1:20,2:8,3:15,4:10');
    await send('0:640,1:20,2:260,3:15,4:10', millis: 300);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/buzzers_page.png'));
    await tester.pumpWidget(const SizedBox());
    link.dispose();
  });

  testWidgets('buzzers: assigning', (tester) async {
    tester.view.physicalSize = const Size(900, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var now = 1000;
    final port = FakePort()..plugged = true;
    final link = BuzzerLink(port, clock: () => now);
    link.use('COM3');
    const teams = [Team(id: 'red', name: 'Red'), Team(id: 'blue', name: 'Blue'), Team(id: 'green', name: 'Green')];
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.dark),
      home: Scaffold(
        appBar: AppBar(title: const Text("Buzzers")),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BuzzersView(link: link, teams: teams, assignments: const {}, onPort: (_) {}, onAssign: (_, _) {}, onThreshold: (_, _) {}),
          ],
        ),
      ),
    ));
    port.send('0:12,1:20,2:8\n');
    for (var i = 0; i < 10; i++) {
      now += 10;
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.tap(find.text('Assign all by pressing'));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/buzzers_assigning.png'));
    await tester.pumpWidget(const SizedBox());
    link.dispose();
  });

  testWidgets('account: guest', (tester) async {
    await page(
      tester,
      AccountView(username: 'Jacob', email: null, guest: true, version: '2.0.0', onRename: () {}, onUpgrade: () {}, onSignOut: () {}),
    );
    await shot('account_guest');
  });

  testWidgets('account: with email', (tester) async {
    await page(
      tester,
      AccountView(
        username: 'Jacob',
        email: 'jacob@example.com',
        guest: false,
        version: '2.0.0',
        onRename: () {},
        onUpgrade: () {},
        onSignOut: () {},
      ),
    );
    await shot('account_email');
  });

  testWidgets('account: assistant on', (tester) async {
    await page(
      tester,
      AccountView(
        username: 'Jacob',
        email: 'jacob@example.com',
        guest: false,
        version: '2.0.0',
        onRename: () {},
        onUpgrade: () {},
        onSignOut: () {},
        assistant: AssistantCard(
          running: true,
          url: 'http://localhost:47820/mcp',
          command: 'claude mcp add --transport http quiz-studio http://localhost:47820/mcp',
          activity: const [
            'Added to "Capitals": Which city is the capital of Australia? (300)',
            'Added to "Capitals": Capital of France? (100)',
            'Added category "Capitals"',
          ],
          onChanged: (_) {},
        ),
      ),
    );
    await shot('account_assistant');
  });

  // ── brought back from v1 ───────────────────────────────────────────────────

  /// A game whose progressing reveal has a picture for every hint, with the
  /// files really on disk.
  GameContent pictureGame() {
    final root = Directory.systemTemp.createTempSync('quiz_shots');
    Directory('${root.path}/pics').createSync();
    const colors = [(200, 80, 60), (60, 140, 200), (90, 170, 90), (220, 180, 60), (140, 90, 190)];
    for (final (i, color) in colors.indexed) {
      final picture = img.Image(width: 320, height: 180);
      img.fill(picture, color: img.ColorRgb8(color.$1, color.$2, color.$3));
      img.fillCircle(picture, x: 60 + i * 50, y: 90, radius: 50, color: img.ColorRgb8(255, 255, 255));
      File('${root.path}/pics/$i.png').writeAsBytesSync(img.encodePng(picture));
    }
    MediaService.instance.debugRoot = root;
    return GameContent.assemble(
      id: 'pics',
      game: {'name': 'Pictures'},
      groups: {
        'g': {'name': 'Round', 'categoryGroupType': 'category_wheel', 'categoryGroupIndex': 0},
      },
      categories: {
        'c': {'name': 'Cities', 'categoryGroup': 'g', 'categoryIndex': 0, 'active': true},
      },
      questions: {
        'c': {
          'q': {
            'type': 'progressingReveal',
            'question': 'Which city is this?',
            'music': 'tune.mp3',
            'information': ['A river', 'A tower', 'A bridge', 'A square', 'The skyline'],
            'informationImage': ['0.png', '1.png', '2.png', '3.png', '4.png'],
            'informationMusic': ['', '', '', '', ''],
            'pointsPlus': 500,
          },
        },
      },
    );
  }

  Future<void> loadPictures(WidgetTester tester, GameContent game) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 5; i++) {
        await precacheImage(FileImage(MediaService.instance.localFile(game.id, '$i.png')), tester.element(find.byType(Scaffold).first));
      }
    });
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('presenter: picture strip and music bars', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = pictureGame();
    host = SessionHost(initial: fixtureState().copyWith(gameId: 'pics'));
    final connection = SessionConnection.local(host, game: game);
    addTearDown(connection.dispose);
    for (final command in const [OpenQuestion(QuestionRef('c', 'q')), Reveal(1), Reveal(1), Reveal(1), ImageFocus(-1)]) {
      host.dispatch(command);
    }
    // The pictures have to be in the image cache before a widget asks for
    // them: a load started under the test's fake clock never finishes.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await loadPictures(tester, game);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.dark),
      home: Scaffold(body: PresenterView(connection: connection)),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await shot('presenter_picture_strip');
    host.dispatch(const SetThumbnails(false));
    await tester.pump(const Duration(milliseconds: 400));
    await shot('presenter_picture_strip_off');
  });

  testWidgets('editor: question preview', (tester) async {
    tester.view.physicalSize = const Size(1100, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = pictureGame();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      home: Scaffold(
        appBar: AppBar(title: const Text("Cities")),
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showQuestionPreview(
                context,
                gameId: game.id,
                categoryId: 'c',
                question: game.question(const QuestionRef('c', 'q'))!,
              ),
              child: const Text("open"),
            ),
          ),
        ),
      ),
    ));
    await loadPictures(tester, game);
    await tapText(tester, find.text('open'));
    await tester.tap(find.byTooltip('Reveal next'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Reveal next'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    await shot('editor_question_preview');
  });

  testWidgets('buzzers: raw data and team sounds', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var now = 1000;
    final port = FakePort()..plugged = true;
    final link = BuzzerLink(port, clock: () => now);
    link.use('COM3');
    const teams = [Team(id: 'red', name: 'Red', sound: 'horn.mp3'), Team(id: 'blue', name: 'Blue'), Team(id: 'green', name: 'Green')];
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      home: Scaffold(
        appBar: AppBar(title: const Text("Buzzers")),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BuzzersView(link: link, teams: teams, assignments: const {}, onPort: (_) {}, onAssign: (_, _) {}, onThreshold: (_, _) {}),
            const Divider(height: 40),
            TeamSoundsList(teams: teams, uploading: const {'green'}, onChoose: (_) {}, onClear: (_) {}),
          ],
        ),
      ),
    ));
    for (var i = 0; i < 14; i++) {
      port.send('0:${12 + i % 3},1:${20 + i * 40},2:${8 + i % 2}\n');
      now += 10;
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/buzzers_raw_and_sounds.png'));
    await tester.pumpWidget(const SizedBox());
    link.dispose();
  });

  // ── Connections ────────────────────────────────────────────────────────────

  /// A picture without ending the round; [shot] clears it afterwards.
  Future<void> snap(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/$name.png'));

  const connectionTeams = [Team(id: 'red', name: 'Red', points: 300), Team(id: 'blue', name: 'Blue', points: 150), Team(id: 'green', name: 'Green')];

  SessionHost connectionsHost({int? timer = 120}) {
    final h = SessionHost(initial: const SessionState(gameId: 'cg', teams: connectionTeams), game: connectionsGame(timer: timer));
    h.dispatch(const OpenQuestion(puzzle));
    return h;
  }

  void guess(SessionHost h, String teamId, List<int> places) =>
      h.dispatch(GuessConnection(teamId, places), sender: Sender(Role.player, teamId: teamId));

  List<int> mixed(int i) => [placesOf(0)[i], placesOf(1)[i], placesOf(2)[i], placesOf(3)[i]];

  Future<void> tablet(WidgetTester tester, SessionHost h, {Brightness brightness = Brightness.light, Size size = const Size(820, 1180)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(brightness),
      home: Scaffold(
        body: SafeArea(
          child: StreamBuilder<SessionState>(
            stream: h.states,
            builder: (context, _) => PlayerView(
              view: PublicView(h.publicStateFor('red')),
              teamId: 'red',
              send: (command) => h.dispatch(command, sender: const Sender(Role.player, teamId: 'red')),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapWord(WidgetTester tester, SessionHost h, int place) async {
    await tester.tap(find.text(PublicView(h.publicStateFor('red')).connectionWords[place].toUpperCase()));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('connections: tablet, playing', (tester) async {
    final h = connectionsHost();
    host = h;
    guess(h, 'red', placesOf(2));
    guess(h, 'red', mixed(0));
    await tablet(tester, h);
    await tester.pump(const Duration(seconds: 2));
    for (final place in placesOf(3).take(3)) {
      await tapWord(tester, h, place);
    }
    await tester.pump(const Duration(milliseconds: 400));
    await shot('connections_tablet');
  });

  testWidgets('connections: tablet, a group sliding together', (tester) async {
    final h = connectionsHost();
    host = h;
    guess(h, 'red', placesOf(2));
    await tablet(tester, h, brightness: Brightness.dark);
    await tester.pump(const Duration(seconds: 2));
    for (final place in placesOf(0)) {
      await tapWord(tester, h, place);
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    await snap('connections_tablet_sliding');
    await tester.pump(const Duration(milliseconds: 1200));
    await shot('connections_tablet_found');
  });

  testWidgets('connections: phone, shaking after a wrong guess', (tester) async {
    final h = connectionsHost(timer: null);
    host = h;
    await tablet(tester, h, size: const Size(412, 892));
    for (final place in [...placesOf(1).take(3), placesOf(3)[0]]) {
      await tapWord(tester, h, place);
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    await shot('connections_phone_one_away');
    await tester.pump(const Duration(seconds: 3));
  });

  Future<void> bigScreen(WidgetTester tester, SessionHost h) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final connection = SessionConnection.local(h, game: h.game);
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.dark),
      home: Scaffold(body: PresenterView(connection: connection)),
    ));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('connections: big screen while teams play', (tester) async {
    final h = connectionsHost();
    host = h;
    guess(h, 'red', placesOf(2));
    guess(h, 'red', placesOf(0));
    guess(h, 'blue', placesOf(0));
    guess(h, 'blue', mixed(1));
    guess(h, 'green', mixed(0));
    guess(h, 'green', mixed(1));
    guess(h, 'green', mixed(2));
    await bigScreen(tester, h);
    await shot('connections_presenter_playing');
  });

  testWidgets('connections: big screen, groups revealed', (tester) async {
    final h = connectionsHost();
    host = h;
    guess(h, 'red', placesOf(2));
    await bigScreen(tester, h);
    h.dispatch(const Reveal(1));
    h.dispatch(const Reveal(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await shot('connections_presenter_revealed');
  });

  testWidgets('connections: controller', (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = connectionsHost();
    host = h;
    guess(h, 'red', placesOf(2));
    guess(h, 'red', placesOf(0));
    guess(h, 'blue', mixed(1));
    guess(h, 'green', placesOf(3));
    final connection = SessionConnection.local(h, game: h.game);
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      home: Scaffold(appBar: AppBar(title: const Text("Quiz night")), body: ControllerView(connection: connection)),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await snap('connections_controller');
    await tester.tap(find.widgetWithText(FilledButton, 'Reveal group'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await shot('connections_controller_confirm');
  });

  testWidgets('connections: editor', (tester) async {
    await questionCard(tester, 'connections_editor', {
      'type': 'connections',
      'question': 'Find four groups of four',
      'pointsPlus': 400,
      'connections': [
        {'name': 'Fruit', 'words': ['Apple', 'Pear', 'Plum', 'Fig']},
        {'name': 'Planets', 'words': ['Mars', 'Venus', 'Earth', 'Saturn']},
        {'name': 'Card games', 'words': ['Bridge', 'Poker', 'Snap', '']},
        {'name': '', 'words': ['', '', '', '']},
      ],
      'companion': {'timer': 120, 'mistakes': 3},
    });
  });

  // ── Cards: built-in pictures and animations ────────────────────────────────

  /// Asset pictures have to be in the cache before a widget asks for them.
  Future<void> loadBuiltins(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.runAsync(() async {
      for (final image in builtinImages) {
        await precacheImage(AssetImage(image.asset), tester.element(find.byType(Scaffold)));
      }
    });
  }

  testWidgets('cards: effects sheet with built-in pictures', (tester) async {
    await loadBuiltins(tester);
    await phone(tester, const [SetCardAnimation(CardAnimation.bounce)]);
    await tapText(tester, find.text('Effects'));
    await tester.pump(const Duration(milliseconds: 400));
    await shot('cards_effects_sheet');
  });

  Future<void> cardScreen(WidgetTester tester, CardAnimation animation, OverlayCard card, Duration after, String name) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await loadBuiltins(tester);
    host = SessionHost(initial: fixtureState());
    final connection = SessionConnection.local(host, game: fixtureGame());
    addTearDown(connection.dispose);
    host.dispatch(SetCardAnimation(animation));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.dark),
      home: Scaffold(body: PresenterView(connection: connection)),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    host.dispatch(ShowCard(card));
    await tester.pump();
    await tester.pump(after);
    await shot(name);
  }

  testWidgets('cards: built-in picture on screen', (tester) async {
    await cardScreen(tester, CardAnimation.fade, const OverlayCard(image: 'builtin:correct'), const Duration(seconds: 1), 'cards_builtin_on_screen');
  });

  testWidgets('cards: bouncing in', (tester) async {
    await cardScreen(tester, CardAnimation.bounce, const OverlayCard(image: 'builtin:times_up'), const Duration(milliseconds: 170), 'cards_bounce_midway');
  });

  testWidgets('cards: sliding in from the bottom', (tester) async {
    await cardScreen(tester, CardAnimation.slideUp, const OverlayCard(title: 'Round 2', text: 'Pictures and sounds'), const Duration(milliseconds: 140), 'cards_slide_midway');
  });

  testWidgets('cards: flipping in', (tester) async {
    await cardScreen(tester, CardAnimation.flip, const OverlayCard(image: 'builtin:final_round'), const Duration(milliseconds: 200), 'cards_flip_midway');
  });

  testWidgets('cards: editor list', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await loadBuiltins(tester);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      home: Scaffold(
        body: CardsDialog(
          gameId: 'g',
          cards: const [
            CueCard(title: 'Rules', text: 'No phones. Answers in by the buzzer only.'),
            CueCard(image: 'builtin:break'),
            CueCard(title: 'Intro', video: 'intro.mp4'),
            CueCard(image: 'builtin:winner', text: 'Drumroll please'),
          ],
          save: (_) {},
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await shot('cards_editor');
  });

  testWidgets('presenter window', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: fixtureState());
    final connection = SessionConnection.local(host, game: fixtureGame());
    addTearDown(connection.dispose);
    host.dispatch(const AdjustPoints('red', 200));
    await tester.pumpWidget(PresenterWindowApp(connection: connection, onFullscreen: (_) async {}));
    await tester.pump(const Duration(milliseconds: 400));
    await shot('presenter_window');
    await tester.pump(const Duration(seconds: 9));
  });
}

