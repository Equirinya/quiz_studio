import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_music_visualizer/mini_music_visualizer.dart';
import 'package:quiz_show/features/games/widgets/question_preview.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

void main() {
  final game = fixtureGame();

  Future<void> preview(WidgetTester tester, QuestionRef ref) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(child: QuestionPreview(gameId: game.id, categoryId: ref.categoryId, question: game.question(ref)!)),
      ),
    ));
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Reveal next'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a plain question has nothing to step through', (tester) async {
    await preview(tester, free);
    expect(find.text('Capital of France?'), findsOneWidget);
    expect(find.byTooltip('Reveal next'), findsNothing);
    // The answer is for the gamemaster, never for the screen.
    expect(find.text('Paris'), findsNothing);
  });

  testWidgets('abcd uncovers its answers, then marks them', (tester) async {
    await preview(tester, abcd);
    expect(find.text('0 of 5 revealed'), findsOneWidget);
    expect(find.text('a'), findsNothing);
    await next(tester);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsNothing);
    for (var i = 0; i < 3; i++) {
      await next(tester);
    }
    expect(find.byIcon(Icons.check), findsNothing);
    await next(tester);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNWidgets(3));
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.navigate_next)).onPressed, isNull);

    await tester.tap(find.byTooltip('Hide one'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('feud uncovers answers with their values', (tester) async {
    await preview(tester, feud);
    expect(find.text('apple'), findsNothing);
    await next(tester);
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('banana'), findsNothing);
  });

  testWidgets('progressing reveal: the picture strip follows, and can be taken away', (tester) async {
    await preview(tester, reveal);
    // Two of the three hints have a picture.
    expect(find.text('?'), findsNWidgets(2));
    await next(tester);
    // Its file is not on this device: the number stands in for the picture.
    expect(find.text('?'), findsOneWidget);
    expect(find.text('hint 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Without the picture strip'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('?'), findsNothing);
    expect(find.text('hint 1'), findsOneWidget);
  });

  group('on the presenter', () {
    Future<SessionHost> present(WidgetTester tester, List<Command> commands) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final host = SessionHost(initial: fixtureState());
      final connection = SessionConnection.local(host, game: game);
      addTearDown(connection.dispose);
      commands.forEach(host.dispatch);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: PresenterView(connection: connection))));
      await tester.pump(const Duration(milliseconds: 300));
      return host;
    }

    testWidgets('the gamemaster switches the strip off and on', (tester) async {
      final host = await present(tester, const [OpenQuestion(reveal)]);
      expect(find.text('?'), findsNWidgets(2));
      host.dispatch(const SetThumbnails(false));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('?'), findsNothing);
      host.dispatch(const SetThumbnails(true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('?'), findsNWidgets(2));
    });

    testWidgets('no strip for questions without pictures to reveal', (tester) async {
      await present(tester, const [OpenQuestion(abcd)]);
      expect(find.text('?'), findsNothing);
    });

    testWidgets('the music bars move only while the sound plays', (tester) async {
      final host = await present(tester, const [OpenQuestion(song)]);
      MiniMusicVisualizer bars() => tester.widget(find.byType(MiniMusicVisualizer));
      expect(bars().animate, host.state.media == MediaPlayback.playing);
      host.dispatch(const SetMedia(MediaPlayback.playing));
      await tester.pump(const Duration(milliseconds: 300));
      expect(bars().animate, isTrue);
      host.dispatch(const SetMedia(MediaPlayback.paused));
      await tester.pump(const Duration(milliseconds: 300));
      expect(bars().animate, isFalse);
      // Stop, so nothing is left animating when the test ends.
      host.dispatch(const CloseQuestion());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MiniMusicVisualizer), findsNothing);
    });

    testWidgets('a question without sound has no bars', (tester) async {
      await present(tester, const [OpenQuestion(free)]);
      expect(find.byType(MiniMusicVisualizer), findsNothing);
    });
  });
}
