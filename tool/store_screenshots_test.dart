// Store listing images, and the screenshots the README and the website use:
//   flutter test tool/store_screenshots_test.dart --update-goldens
//
// Every store image is rendered at the exact pixel size its store asks for
// (see _specs), into screenshots/<spec>/<scene>.png, plus Google Play's
// feature graphic. The plain screens go to docs/images/. The content is the
// showcase quiz in tool/store/showcase.dart.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quiz_show/core/theme.dart';
import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/pages/game_editor_page.dart';
import 'package:quiz_show/features/player/pages/player_page.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_client.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import '../test/game/connections_fixture.dart';
import 'store/showcase.dart';

final _fonts = '${Platform.environment['FLUTTER_ROOT'] ?? '/home/jacob/development/flutter'}/bin/cache/artifacts/material_fonts';

late Uint8List _icon;

Future<void> _load() async {
  Future<ByteData> read(String name) => Future.value(ByteData.view(File('$_fonts/$name').readAsBytesSync().buffer));
  final roboto = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']) {
    roboto.addFont(read(name));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'))).load();
  _icon = File('assets/icon/icon.png').readAsBytesSync();
}

/// Output size in pixels per store.
const _specs = {
  'playstore_phone': Size(1080, 1920), // 9:16
  'playstore_tablet': Size(1800, 2560), // 10" tablet
  'appstore_iphone_6_5': Size(1284, 2778), // iPhone 6.5"
  'appstore_ipad_13': Size(2064, 2752), // iPad 13"
  'microsoft_store': Size(1920, 1080), // Windows, 16:9
};

// The app's onboarding colours.
const _mesh = [Color(0xFFF66C5D), Color(0xFFCC4CD8), Color(0xFFFF4800), Color(0xFFFFA144)];

// ── devices ─────────────────────────────────────────────────────────────────

/// One of the app's screens as on a device of [size] logical pixels.
Widget _screen(Size size, bool dark, Widget child) => SizedBox.fromSize(
      size: size,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(dark ? Brightness.dark : Brightness.light), home: child),
      ),
    );

/// [child] inside a device outline, [width] wide.
class Device extends StatelessWidget {
  const Device({super.key, required this.screen, required this.width, required this.child, this.dark = false, this.bezel = 0.025, this.radius = 0.07});

  final Size screen;
  final double width;
  final Widget child;
  final bool dark;
  final double bezel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final b = width * bezel;
    final inner = width - 2 * b;
    return Container(
      width: width,
      padding: EdgeInsets.all(b),
      decoration: BoxDecoration(
        color: const Color(0xFF16100E),
        borderRadius: BorderRadius.circular(width * radius),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: width * 0.06, offset: Offset(0, width * 0.025))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * radius - b),
        child: SizedBox(
          width: inner,
          height: inner * screen.height / screen.width,
          child: FittedBox(child: _screen(screen, dark, child)),
        ),
      ),
    );
  }
}

const _phone = Size(412, 892);
const _tv = Size(1600, 900);
const _tabletWide = Size(1180, 820);
const _tabletTall = Size(820, 1180);

Widget _tvDevice(Widget screen, double width) => Device(screen: _tv, width: width, dark: true, bezel: 0.012, radius: 0.012, child: screen);


/// The big screen with a smaller device of [screen] size over its lower corner.
(Size, Widget) _pair(bool wide, Widget tv, Size screen, Widget child, {required double width, bool left = false, bool dark = false, double drop = 0.62}) {
  final tvWidth = wide ? 1180.0 : 1000.0;
  final tvHeight = tvWidth * 0.988 * 9 / 16 + tvWidth * 0.024;
  final w = wide ? width * 0.75 : width;
  final radius = screen == _phone ? 0.07 : 0.04;
  final height = (w * 0.95) * screen.height / screen.width + w * 0.05;
  final top = tvHeight * (wide ? drop * 0.8 : drop);
  final canvas = Size(wide ? 1400 : 1000, top + height + 20);
  return (
    canvas,
    Stack(children: [
      Positioned(left: 0, top: 0, child: _tvDevice(tv, tvWidth)),
      Positioned(left: left ? 30 : null, right: left ? null : 30, top: top, child: Device(screen: screen, width: w, radius: radius, dark: dark, child: child)),
    ]),
  );
}

// ── scenes ──────────────────────────────────────────────────────────────────

class Scene {
  const Scene(this.headline, this.subtitle, this.build, {this.act});

  final String headline;
  final String subtitle;

  /// The devices, laid out on a canvas of the returned size; [wide] for a
  /// landscape image.
  final (Size, Widget) Function(WidgetTester tester, bool wide) build;

  /// Done on the screens before the picture, as a person would.
  final Future<void> Function(WidgetTester tester)? act;
}

final _hosts = <SessionHost>[];

/// Hosts a connection disposes of itself.
final _owned = <SessionHost>{};

/// Stops the round timers before the test ends.
void _done() {
  for (final host in _hosts) {
    host.dispatch(const ClearAnswers());
  }
  for (final host in _hosts) {
    if (!_owned.contains(host)) host.dispose();
  }
  _hosts.clear();
  _owned.clear();
}

SessionHost _host(List<Command> commands, {GameContent? game, SessionState? state}) {
  final host = SessionHost(initial: state ?? showcaseState(), game: game ?? showcaseGame());
  _hosts.add(host);
  for (final command in commands) {
    host.dispatch(command);
  }
  return host;
}

SessionConnection _connect(SessionHost host) {
  _owned.add(host);
  final connection = SessionConnection.local(host, game: host.game);
  addTearDown(connection.dispose);
  return connection;
}

Widget _presenter(SessionHost host) => Scaffold(body: PresenterView(connection: _connect(host)));

Widget _controller(SessionHost host) => Scaffold(
      appBar: AppBar(title: const Text("Friday quiz night")),
      body: ControllerView(connection: _connect(host), onConnectDevices: () {}),
    );

Widget _player(SessionHost host, String teamId) => Scaffold(
      body: SafeArea(
        child: StreamBuilder<SessionState>(
          stream: host.states,
          builder: (context, _) => PlayerView(
            view: PublicView(host.publicStateFor(teamId)),
            teamId: teamId,
            send: (command) => host.dispatch(command, sender: Sender(Role.player, teamId: teamId)),
            onLeave: () {},
            link: LinkStatus.lan,
          ),
        ),
      ),
    );

const _abcd = [SetQueueBuzzers(true), OpenQuestion(science), Reveal(1), Reveal(1), Reveal(1), Reveal(1), Buzz('quizzards'), Buzz('owls')];

const _feud = [OpenQuestion(beach), Buzz('pants'), FeudToggle(0), FeudToggle(1), FeudToggle(3), FeudWrong()];

List<Command> _whiteboards() => [
      const OpenQuestion(spider),
      SubmitAnswer('owls', PlayerAnswer(drawing: drawnEight())),
      const LockAnswer('owls'),
      SubmitAnswer('quizzards', PlayerAnswer(drawing: drawnSix())),
      const LockAnswer('quizzards'),
      SubmitAnswer('pants', PlayerAnswer(drawing: drawnEight())),
    ];

List<Command> _rated() => [
      ..._whiteboards(),
      const LockAnswers(),
      const RevealNextAnswer(),
      const RevealNextAnswer(),
      const RevealNextAnswer(),
      const RateAnswer('owls', correct: true),
      const RateAnswer('quizzards', correct: false),
      const RateAnswer('pants', correct: true),
    ];

/// Writes an 8 on the first whiteboard, the way a finger would.
Future<void> _writeEight(WidgetTester tester) async {
  final board = tester.getRect(find.descendant(of: find.byType(WhiteboardPad), matching: find.byType(CustomPaint)).first);
  for (final stroke in decodeDrawing(drawnEight())) {
    final gesture = await tester.startGesture(board.topLeft + Offset(stroke.first.$1 * board.width, stroke.first.$2 * board.height));
    for (final point in stroke.skip(1)) {
      await gesture.moveTo(board.topLeft + Offset(point.$1 * board.width, point.$2 * board.height));
    }
    await gesture.up();
  }
  await tester.pump(const Duration(milliseconds: 300));
}

SessionHost _connections() {
  final h = _host(const [OpenQuestion(puzzle)], game: connectionsGame(timer: 120), state: const SessionState(gameId: 'cg', teams: showcaseTeams));
  void guess(String team, List<int> places) => h.dispatch(GuessConnection(team, places), sender: Sender(Role.player, teamId: team));
  guess('owls', placesOf(2));
  guess('owls', placesOf(0));
  guess('quizzards', placesOf(0));
  guess('quizzards', [placesOf(1)[0], placesOf(1)[1], placesOf(1)[2], placesOf(3)[0]]);
  return h;
}

Widget _editor() {
  final game = showcaseGame();
  return GameEditorView(
    snapshot: GameSnapshot(
      content: game,
      role: GameRole.admin,
      data: {
        ...game.data,
        'admin': ['me'],
        'full': ['ann', 'bob', 'kim'],
      },
    ),
  );
}

final _scenes = <String, Scene>{
  'board': Scene(
    "Your quiz show on the big screen",
    "Boards, scores, music and effects on the TV or projector. You control the show from your phone.",
    (tester, wide) {
      final controller = _host(const [OpenQuestion(QuestionRef('music', 'q2')), Buzz('quizzards')]);
      return _pair(wide, _presenter(_host(const [])), _phone, _controller(controller), width: 400);
    },
  ),
  'controller': Scene("Every button where you expect it", "Right, wrong, reveal: the controller never moves its buttons around.", (tester, wide) {
    final host = _host(_abcd);
    return _pair(wide, _presenter(host), _phone, _controller(host), width: 420, left: true);
  }),
  'whiteboards': Scene(
    "Phones become whiteboards",
    "Teams write or draw their answer. You show and rate them one by one.",
    (tester, wide) {
      final writing = _host(_whiteboards().take(1).toList());
      return _pair(wide, _presenter(_host(_rated())), _tabletWide, _player(writing, 'owls'), width: 760);
    },
    act: _writeEight,
  ),
  'connections': Scene("Puzzle rounds, beautifully animated", "Connections, matching, ordering, sliders and more, on every team's device.", (tester, wide) {
    final h = _connections();
    return _pair(wide, _presenter(h), _tabletTall, _player(h, 'owls'), width: 540);
  }),
  'feud': Scene("Buzz in!", "Phones as buzzers, or real USB buzzers. Survey rounds, quick-fire rounds and picture reveals.", (tester, wide) {
    final buzzer = _host(const [OpenQuestion(QuestionRef('music', 'q2'))]);
    return _pair(wide, _presenter(_host(_feud)), _phone, _player(buzzer, 'pants'), width: 340, drop: 0.92);
  }),
  'editor': Scene("Build quizzes together", "Write categories and questions with friends, then spin the wheel on the big screen.", (tester, wide) {
    return _pair(wide, _presenter(_host(const [SelectGroup('speed')])), _tabletTall, _editor(), width: 520, left: true, drop: 0.92);
  }),
};

// ── frames ──────────────────────────────────────────────────────────────────

/// The soft mesh of the onboarding colours, shifted per [index] so a set of
/// images reads as one strip.
class _Backdrop extends StatelessWidget {
  const _Backdrop(this.index);

  final int index;

  @override
  Widget build(BuildContext context) {
    final shift = index * 0.37;
    Alignment at(double x, double y) => Alignment(((x + shift) % 2.4) - 1.2, y);
    return Stack(fit: StackFit.expand, children: [
      const DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF6A2B), Color(0xFFE2552E)])),
      ),
      for (final (color, x, y, r) in [(_mesh[1], 0.2, -0.9, 1.1), (_mesh[3], 1.4, 0.9, 1.2), (_mesh[0], 0.9, -0.1, 0.9), (_mesh[2], 2.0, 0.2, 0.8)])
        DecoratedBox(
          decoration: BoxDecoration(gradient: RadialGradient(center: at(x, y), radius: r, colors: [color, color.withValues(alpha: 0)])),
        ),
      ColoredBox(color: Colors.black.withValues(alpha: 0.12)),
    ]);
  }
}

Widget _logo(double size) => Row(mainAxisSize: MainAxisSize.min, children: [
      ClipRRect(borderRadius: BorderRadius.circular(size * 0.3), child: Image.memory(_icon, width: size * 1.4, height: size * 1.4)),
      SizedBox(width: size * 0.45),
      Text("Quiz Studio", style: TextStyle(fontSize: size, fontWeight: FontWeight.bold, color: Colors.white)),
    ]);

/// Plain text outside any MaterialApp.
Widget _text(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(style: const TextStyle(fontFamily: 'Roboto', color: Colors.white), child: child),
    );

class _Frame extends StatelessWidget {
  const _Frame({required this.scene, required this.devices, required this.index});

  final Scene scene;
  final (Size, Widget) devices;
  final int index;

  @override
  Widget build(BuildContext context) {
    final (canvas, child) = devices;
    final art = FittedBox(child: SizedBox.fromSize(size: canvas, child: child));
    final headline = Text(scene.headline, style: const TextStyle(fontSize: 40, height: 1.1, fontWeight: FontWeight.w900));
    final subtitle = Text(scene.subtitle, style: TextStyle(fontSize: 19, height: 1.35, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.92)));
    return _text(Stack(fit: StackFit.expand, children: [
      _Backdrop(index),
      LayoutBuilder(builder: (context, size) {
        if (size.maxWidth > size.maxHeight) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(60, 40, 40, 40),
            child: Row(children: [
              SizedBox(
                width: 330,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _logo(22),
                  const SizedBox(height: 36),
                  headline,
                  const SizedBox(height: 18),
                  subtitle,
                ]),
              ),
              const SizedBox(width: 40),
              Expanded(child: art),
            ]),
          );
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(32, size.maxHeight * 0.045, 32, size.maxHeight * 0.03),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: _logo(20)),
            SizedBox(height: size.maxHeight * 0.03),
            headline,
            const SizedBox(height: 12),
            subtitle,
            SizedBox(height: size.maxHeight * 0.03),
            Expanded(child: art),
          ]),
        );
      }),
    ]));
  }
}

/// [child] laid out [logicalWidth] wide and scaled to fill the test window,
/// so the picture has the window's full pixel size.
Widget _scaled(double logicalWidth, Size px, Widget child) => RepaintBoundary(
      child: FittedBox(child: SizedBox(width: logicalWidth, height: logicalWidth * px.height / px.width, child: child)),
    );

Future<void> _window(WidgetTester tester, Size px) async {
  tester.view.physicalSize = px;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpWithIcon(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.runAsync(() => precacheImage(MemoryImage(_icon), tester.element(find.byType(Directionality).first)));
  await tester.pumpWidget(widget);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 2));
}

/// The stores refuse pictures with an alpha channel.
void _dropAlpha() {
  for (final file in Directory('screenshots').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.png'))) {
    final image = img.decodePng(file.readAsBytesSync());
    if (image == null || image.numChannels == 3) continue;
    file.writeAsBytesSync(img.encodePng(image.convert(numChannels: 3)));
  }
}

void main() {
  setUpAll(_load);
  tearDownAll(_dropAlpha);

  final names = _scenes.keys.toList();
  for (final MapEntry(key: spec, value: px) in _specs.entries) {
    for (final name in names) {
      testWidgets('$spec: $name', (tester) async {
        await _window(tester, px);
        final wide = px.width > px.height;
        final scene = _scenes[name]!;
        final frame = _Frame(scene: scene, devices: scene.build(tester, wide), index: names.indexOf(name));
        await _pumpWithIcon(tester, _scaled(wide ? 1100 : 540, px, frame));
        await scene.act?.call(tester);
        await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('../screenshots/$spec/$name.png'));
        _done();
      });
    }
  }

  // Google Play's feature graphic: 1024 x 500, no transparency.
  testWidgets('playstore feature graphic', (tester) async {
    const px = Size(1024, 500);
    await _window(tester, px);
    final graphic = _text(Stack(fit: StackFit.expand, children: [
      const _Backdrop(1),
      Padding(
        padding: const EdgeInsets.fromLTRB(56, 40, 40, 40),
        child: Row(children: [
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _logo(30),
              const SizedBox(height: 26),
              const Text("Host your own quiz show", style: TextStyle(fontSize: 36, height: 1.1, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text("Big screen, phone buzzers, music and effects.", style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha: 0.92))),
            ]),
          ),
          const SizedBox(width: 24),
          _tvDevice(_presenter(_host(const [])), 470),
        ]),
      ),
    ]));
    await _pumpWithIcon(tester, _scaled(1024, px, graphic));
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('../screenshots/playstore_feature_graphic.png'));
    _done();
  });

  // Plain screens for the README and the website.
  final plain = <String, (Size, double, bool, Widget Function())>{
    'big_screen_board': (_tv, 1.2, true, () => _presenter(_host(const []))),
    'big_screen_abcd': (_tv, 1.2, true, () => _presenter(_host(_abcd))),
    'big_screen_whiteboards': (_tv, 1.2, true, () => _presenter(_host(_rated()))),
    'big_screen_feud': (_tv, 1.2, true, () => _presenter(_host(_feud))),
    'big_screen_connections': (_tv, 1.2, true, () => _presenter(_connections())),
    'phone_controller': (_phone, 2, false, () => _controller(_host(_abcd))),
    'phone_buzzer': (_phone, 2, false, () => _player(_host(const [OpenQuestion(QuestionRef('music', 'q2'))]), 'pants')),
    'tablet_connections': (_tabletTall, 1.5, false, () => _player(_connections(), 'owls')),
    'tablet_editor': (_tabletTall, 1.5, false, _editor),
  };
  for (final MapEntry(key: name, value: (size, ratio, dark, build)) in plain.entries) {
    testWidgets('plain: $name', (tester) async {
      final px = size * ratio;
      await _window(tester, px);
      await tester.pumpWidget(_scaled(size.width, px, _screen(size, dark, build())));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('../docs/images/$name.png'));
      _done();
    });
  }
}
