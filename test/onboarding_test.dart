import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/auth/auth_gate.dart';
import 'package:quiz_show/features/auth/pages/onboarding_page.dart';

/// Someone signed in (or not), with a name stored (or not); no Firebase.
class _FakeBackend extends AuthGateBackend {
  _FakeBackend(this.currentUser, {this.username});

  @override
  GateUser? currentUser;

  String? username;

  final StreamController<GateUser?> _changes = StreamController.broadcast();

  @override
  Stream<GateUser?> changes() => _changes.stream;

  @override
  Future<String?> loadUsername() async => username;

  @override
  Future<void> onLogin(String username) async {}

  void signIn(GateUser? user) {
    currentUser = user;
    _changes.add(user);
  }
}

void main() {
  Future<void> pumpWelcome(WidgetTester tester, {bool nameOnly = false}) async {
    await tester.pumpWidget(MaterialApp(home: WelcomePage(onFinished: () {}, nameOnly: nameOnly)));
    await tester.pump(const Duration(milliseconds: 100));
  }

  FilledButton startButton(WidgetTester tester) => tester.widget(find.widgetWithText(FilledButton, "Let's play"));

  testWidgets('showcase leads to the name step, which needs three characters', (tester) async {
    await pumpWelcome(tester);
    expect(find.text('I already have an account'), findsOneWidget);

    expect(find.text('Join a show'), findsOneWidget, reason: 'a team device needs no account');
    await tester.tap(find.text('Create my own quizzes'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(startButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'ab ');
    await tester.pump();
    expect(startButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(startButton(tester).onPressed, isNotNull);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Create my own quizzes'), findsOneWidget);
  });

  testWidgets('name-only mode starts on the name step with no way back', (tester) async {
    await pumpWelcome(tester, nameOnly: true);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    // Signed in for playing along only: still no name needed for that.
    expect(find.text('Just join a show'), findsOneWidget);
    expect(find.text('Use a different account'), findsOneWidget);
    expect(find.text('I already have an account'), findsNothing);
  });

  testWidgets('the name step offers the login and a way back', (tester) async {
    await pumpWelcome(tester);
    await tester.tap(find.text('Create my own quizzes'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.text('I already have an account'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('login step shows the credential form', (tester) async {
    await pumpWelcome(tester);
    await tester.tap(find.text('I already have an account'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Login'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  group('AuthGate', () {
    Future<void> pumpGate(WidgetTester tester, _FakeBackend backend) async {
      await tester.pumpWidget(MaterialApp(home: AuthGate(backend: backend, child: const Text('home'))));
      // The profile read, then the screen it leads to, whose background
      // starts a timer of its own.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('a guest who joined a show gets the whole welcome screen on the next launch', (tester) async {
      await pumpGate(tester, _FakeBackend((uid: 'guest', anonymous: true)));
      expect(find.text('Join a show'), findsOneWidget);
      expect(find.text('Create my own quizzes'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
      expect(find.byType(TextField), findsNothing, reason: 'not stuck on the name step');
    });

    testWidgets('a guest signing in to an account stays in the login until it is done', (tester) async {
      final backend = _FakeBackend((uid: 'guest', anonymous: true));
      await pumpGate(tester, backend);
      await tester.tap(find.text('I already have an account'));
      await tester.pump(const Duration(milliseconds: 100));
      backend
        ..username = 'Quizmaster'
        ..signIn((uid: 'account', anonymous: false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('an account without a name is asked for the name only', (tester) async {
      await pumpGate(tester, _FakeBackend((uid: 'account', anonymous: false)));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Use a different account'), findsOneWidget);
    });

    testWidgets('a guest who has a name, and an account with one, go straight in', (tester) async {
      await pumpGate(tester, _FakeBackend((uid: 'guest', anonymous: true), username: 'Team Blue'));
      expect(find.text('home'), findsOneWidget);
      await pumpGate(tester, _FakeBackend((uid: 'account', anonymous: false), username: 'Quizmaster'));
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('nobody signed in sees the welcome screen', (tester) async {
      await pumpGate(tester, _FakeBackend(null));
      expect(find.text('Join a show'), findsOneWidget);
    });
  });
}
