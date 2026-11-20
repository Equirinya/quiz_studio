import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/features/session/widgets/media_controls.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

/// The controller's sound controls: effects that stop when tapped again,
/// their volume, and the question's sound with its bar and volume.
void main() {
  late SessionHost host;

  Future<void> pumpController(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(460, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: fixtureState(), game: fixtureGame());
    final connection = SessionConnection.local(host, game: fixtureGame());
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ControllerView(connection: connection))));
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('an effect chip lights up while its sound plays, and stops it when tapped again', (tester) async {
    await pumpController(tester);
    await tap(tester, find.widgetWithText(TextButton, 'Effects'));
    final buzzer = find.byKey(const ValueKey('effect-builtin:buzzer/buzzer'));
    expect(buzzer, findsOneWidget, reason: 'the buzzer is at hand');
    expect(find.byKey(const ValueKey('effect-builtin:wrong_answer/bwomp')), findsOneWidget);
    await tap(tester, buzzer);
    expect(host.state.effectsPlaying, ['builtin:buzzer/buzzer']);
    expect(tester.widget<FilterChip>(buzzer).selected, isTrue);
    await tap(tester, buzzer);
    expect(host.state.effectsPlaying, isEmpty);
    expect(find.byType(MediaControls), findsNothing, reason: 'the question sound is on the play button only');
    expect(find.byKey(const ValueKey('effectsVolume')), findsOneWidget);
  });

  testWidgets("the play button opens the question sound's bar and volume", (tester) async {
    await pumpController(tester);
    expect(find.byKey(const ValueKey('soundControls')), findsNothing, reason: 'no question with a sound');
    host
      ..dispatch(const OpenQuestion(song))
      ..dispatch(const SetMedia(MediaPlayback.playing))
      ..dispatch(const MediaLoaded(200000));
    await tester.pump();
    // The right quarter of the play button opens them.
    final more = tester.getRect(find.byKey(const ValueKey('soundControls')));
    final play = tester.getRect(find.ancestor(of: find.byKey(const ValueKey('soundControls')), matching: find.byType(Stack)).first);
    expect(more.width, moreOrLessEquals(play.width / 4, epsilon: 1));
    expect(more.right, moreOrLessEquals(play.right, epsilon: 1));
    expect(more.height, greaterThan(40), reason: 'the whole height of the button');
    await tap(tester, find.byKey(const ValueKey('soundControls')));
    expect(find.byType(MediaControls), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('0:00 / 3:20'), findsOneWidget, reason: 'on the host clock, this device being the host');

    // Dragged to the middle: the sound jumps there.
    await tester.tap(find.byKey(const ValueKey('mediaPosition')));
    await tester.pump();
    expect(host.state.mediaSeek, 1);
    expect(host.state.mediaClock!.positionMs, closeTo(100000, 5000));

    await tap(tester, find.byKey(const ValueKey('mediaPlay')));
    expect(host.state.media, MediaPlayback.paused);
    expect(find.byKey(const ValueKey('mediaVolume')), findsOneWidget);
  });

  testWidgets('the cards stay where they were scrolled to when the panel is closed and opened again', (tester) async {
    await pumpController(tester);
    final effects = find.widgetWithText(TextButton, 'Effects');
    await tap(tester, effects);
    final cards = find.byKey(const ValueKey('effect-cards'));
    ScrollPosition position() => tester.state<ScrollableState>(find.descendant(of: cards, matching: find.byType(Scrollable))).position;
    expect(position().maxScrollExtent, greaterThan(200), reason: 'more cards than fit');
    position().jumpTo(200);
    await tester.pump();
    await tap(tester, effects);
    expect(cards, findsNothing, reason: 'closed');
    await tap(tester, effects);
    expect(position().pixels, 200);
  });
}
