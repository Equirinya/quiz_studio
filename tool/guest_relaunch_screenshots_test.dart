// The screens a team's device sees when the app opens again after joining a
// show from the welcome screen, and the name steps around them:
//   flutter test tool/guest_relaunch_screenshots_test.dart --update-goldens
// Writes tool/screenshots/guest_relaunch/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/auth/auth_gate.dart';
import 'package:quiz_show/features/auth/pages/onboarding_page.dart';

final _fonts = '${Platform.environment['FLUTTER_ROOT'] ?? '/home/jacob/development/flutter'}/bin/cache/artifacts/material_fonts';

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

/// A signed-in user without a profile, no Firebase.
class _NoProfile extends AuthGateBackend {
  const _NoProfile({required this.anonymous});

  final bool anonymous;

  @override
  GateUser? get currentUser => (uid: 'u', anonymous: anonymous);

  @override
  Stream<GateUser?> changes() => const Stream.empty();

  @override
  Future<String?> loadUsername() async => null;
}

void main() {
  setUpAll(_loadFonts);

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: home));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> shot(String name) =>
      expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/guest_relaunch/$name.png'));

  testWidgets('a guest opening the app again', (tester) async {
    await pump(tester, const AuthGate(backend: _NoProfile(anonymous: true), child: Text('home')));
    await shot('guest_relaunch');
  });

  testWidgets('the name step from "Create my own quizzes"', (tester) async {
    await pump(tester, WelcomePage(onFinished: () {}));
    await tester.tap(find.text('Create my own quizzes'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await shot('name_step');
  });

  testWidgets('an account without a name', (tester) async {
    await pump(tester, const AuthGate(backend: _NoProfile(anonymous: false), child: Text('home')));
    await shot('name_only');
  });
}
