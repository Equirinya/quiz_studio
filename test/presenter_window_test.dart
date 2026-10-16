import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/lan/lan_client.dart';
import 'package:quiz_show/features/session/lan/lan_host_server.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/presenter_window.dart';
import 'package:quiz_show/features/session/session_client.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

void main() {
  group('starting a window', () {
    test('the arguments go there and back', () {
      const args = PresenterWindowArgs(sessionId: 's1', endpoint: '127.0.0.1:47800', token: 'abc');
      final parsed = PresenterWindowArgs.tryParse(['--something', ...args.toArgs()])!;
      expect((parsed.sessionId, parsed.endpoint, parsed.token), ('s1', '127.0.0.1:47800', 'abc'));
    });

    test('an ordinary start, or anything incomplete or elsewhere, is not a presenter window', () {
      expect(PresenterWindowArgs.tryParse(const []), isNull);
      expect(PresenterWindowArgs.tryParse(const ['--presenter-window', 'session=s', 'endpoint=127.0.0.1:1']), isNull);
      expect(
        PresenterWindowArgs.tryParse(const ['--presenter-window', 'session=s', 'endpoint=10.0.0.5:47800', 'token=t']),
        isNull,
        reason: 'only this computer',
      );
    });

    test('the window token lets in a controller; join tokens keep working; nothing else does', () {
      const tokens = <String, LanGrant>{'red': (role: Role.player, teamId: 'red')};
      expect(SessionConnection.grantFor('w', windowToken: 'w', tokens: tokens)?.role, Role.controller);
      expect(SessionConnection.grantFor('red', windowToken: 'w', tokens: tokens)?.teamId, 'red');
      expect(SessionConnection.grantFor('guess', windowToken: 'w', tokens: tokens), isNull);
    });
  });

  group('over the loopback', () {
    late SessionHost host;
    late LanHostServer server;
    late String endpoint;

    setUp(() async {
      host = SessionHost(initial: fixtureState(), game: fixtureGame());
      server = LanHostServer(
        host,
        authorize: (token) => SessionConnection.grantFor(token, windowToken: 'window', tokens: {'red': (role: Role.player, teamId: 'red')}),
      );
      endpoint = '127.0.0.1:${await server.start(port: 0, address: InternetAddress.loopbackIPv4)}';
    });

    tearDown(() async {
      await server.stop();
      await host.dispose();
    });

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 150));

    test('confetti reaches a controller, not a player', () async {
      final window = await LanClient.connect(endpoint, token: 'window');
      final player = await LanClient.connect(endpoint, token: 'red');
      final seen = <String>[];
      final playerSeen = <Effect>[];
      window.effects.listen((e) => seen.add((e as VisualEffect).name));
      player.effects.listen(playerSeen.add);
      host.dispatch(const ScreenEffect(screenEffectConfetti));
      host.dispatch(const PlayEffect('airhorn'));
      await settle();
      expect(seen, [screenEffectConfetti]);
      expect(playerSeen, isEmpty);
      await window.close();
      await player.close();
    });

    test('a window connection follows the show with the game, the state and the effects', () async {
      final connection = SessionConnection.window(sessionId: 's', endpoint: endpoint, token: 'window');
      final effects = <Effect>[];
      final sub = connection.effects!.listen(effects.add);
      await settle();
      expect(connection.link!.value, LinkStatus.lan);
      expect(connection.game.value?.question(free)?.text, 'Capital of France?');
      host.dispatch(const OpenQuestion(free));
      host.dispatch(const ScreenEffect(screenEffectFlash));
      await settle();
      expect(connection.state.value?.current, free);
      expect(effects.whereType<VisualEffect>().map((e) => e.name), [screenEffectFlash]);
      // It may take a finished video card off the screen.
      host.dispatch(const ShowCard(OverlayCard(video: 'clip.mp4')));
      connection.send(const HideCard());
      await settle();
      expect(host.state.overlay, isNull);
      await sub.cancel();
      await connection.dispose();
    });
  });

  group('the window', () {
    late SessionHost host;
    late SessionConnection connection;
    final fullscreen = <bool>[];

    Future<void> pumpWindow(WidgetTester tester, {VoidCallback? onQuit}) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      fullscreen.clear();
      host = SessionHost(initial: fixtureState());
      connection = SessionConnection.local(host, game: fixtureGame());
      addTearDown(connection.dispose);
      await tester.pumpWidget(PresenterWindowApp(
        connection: connection,
        onFullscreen: (on) async => fullscreen.add(on),
        onQuit: onQuit,
      ));
      await tester.pump();
    }

    testWidgets('shows the big screen, with a hint that goes away', (tester) async {
      await pumpWindow(tester);
      expect(find.byType(PresenterView), findsOneWidget);
      expect(find.textContaining('Drag this window to the projector'), findsOneWidget);
      host.dispatch(const OpenQuestion(free));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Capital of France?'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      expect(find.textContaining('Drag this window to the projector'), findsNothing);
    });

    testWidgets('F11, a double click or the button for full screen; Esc to leave it', (tester) async {
      await pumpWindow(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pump();
      expect(fullscreen, [true]);
      expect(find.textContaining('Drag this window'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(fullscreen, [true, false]);
      await tester.tap(find.byTooltip('Full screen (F11)'));
      await tester.pump();
      expect(fullscreen, [true, false, true]);
      // Esc again leaves; a second Esc does nothing.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(fullscreen, [true, false, true, false]);
      final center = tester.getCenter(find.byType(PresenterView));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 400));
      expect(fullscreen.last, isTrue);
    });
  });

  testWidgets('a window whose main window is gone closes itself', (tester) async {
    late SessionHost host;
    late LanHostServer server;
    late SessionConnection connection;
    await tester.runAsync(() async {
      host = SessionHost(initial: fixtureState(), game: fixtureGame());
      server = LanHostServer(host, authorize: (token) => token == 'window' ? (role: Role.controller, teamId: null) : null);
      final port = await server.start(port: 0, address: InternetAddress.loopbackIPv4);
      connection = SessionConnection.window(sessionId: 's', endpoint: '127.0.0.1:$port', token: 'window');
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    var quit = 0;
    await tester.pumpWidget(PresenterWindowApp(
      connection: connection,
      onFullscreen: (_) async {},
      onQuit: () => quit++,
      orphanAfter: const Duration(milliseconds: 800),
    ));
    expect(connection.link!.value, LinkStatus.lan);
    await tester.runAsync(() async {
      await server.stop();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    expect(connection.link!.value, LinkStatus.cloud);
    expect(quit, 0, reason: 'a short break is survived');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 900)));
    expect(quit, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await connection.dispose();
      await host.dispose();
    });
  });
}

