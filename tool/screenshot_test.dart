// Renders the session screens to PNG files for a quick look without a device:
//   flutter test tool/screenshot_test.dart --update-goldens
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/core/theme.dart';
import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/player/pages/player_page.dart';
import 'package:quiz_show/features/session/pages/screen_overlays.dart';
import 'package:quiz_show/features/session/pages/sessions_page.dart';
import 'package:quiz_show/features/session/session_client.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/boards/map_board.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

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
}
