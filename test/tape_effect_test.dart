import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/pages/screen_overlays.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

void main() {
  late SessionHost host;

  Future<void> presenter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    host = SessionHost(initial: fixtureState());
    final connection = SessionConnection.local(host, game: fixtureGame());
    addTearDown(connection.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PresenterView(connection: connection))));
    await tester.pump();
  }

  test('fast forward is an effect the host lets through', () {
    expect(screenEffects, contains(screenEffectFastForward));
    final result = reduce(fixtureState(), const ScreenEffect(screenEffectFastForward), fixtureGame());
    expect((result.effects.single as VisualEffect).name, screenEffectFastForward);
  });

  testWidgets('the tape smears the screen for a moment, then it is clean again', (tester) async {
    await presenter(tester);
    expect(find.byType(TapeSmear), findsNothing);

    host.dispatch(const ScreenEffect(screenEffectFastForward));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TapeSmear), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets, reason: 'it works on the picture underneath');

    // Each frame of the effect builds without trouble.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pump(TapeSmear.duration);
    expect(find.byType(TapeSmear), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing, reason: 'nothing left over the screen');
    expect(tester.takeException(), isNull);
  });

  testWidgets('pressed twice quickly, it starts over and still ends', (tester) async {
    await presenter(tester);
    host.dispatch(const ScreenEffect(screenEffectFastForward));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    host.dispatch(const ScreenEffect(screenEffectFastForward));
    await tester.pump();
    host.dispatch(const ScreenEffect(screenEffectFastForward));
    await tester.pump();
    expect(find.byType(TapeSmear), findsOneWidget);

    // Still running where the first one would have ended.
    await tester.pump(TapeSmear.duration - const Duration(milliseconds: 600));
    expect(find.byType(TapeSmear), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TapeSmear), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tiny or empty screen does not trip it up', (tester) async {
    for (final size in [Size.zero, const Size(1, 1)]) {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox.fromSize(size: size, child: const TapeSmear(progress: 0.5, seed: 3))),
      ));
      expect(tester.takeException(), isNull);
    }
  });
}
