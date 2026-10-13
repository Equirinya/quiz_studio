import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/auth/pages/onboarding_page.dart';

void main() {
  Future<void> pumpWelcome(WidgetTester tester, {bool nameOnly = false}) async {
    await tester.pumpWidget(MaterialApp(home: WelcomePage(onFinished: () {}, nameOnly: nameOnly)));
    await tester.pump(const Duration(milliseconds: 100));
  }

  FilledButton startButton(WidgetTester tester) => tester.widget(find.widgetWithText(FilledButton, "Let's play"));

  testWidgets('showcase leads to the name step, which needs three characters', (tester) async {
    await pumpWelcome(tester);
    expect(find.text('I already have an account'), findsOneWidget);

    await tester.tap(find.text('Get started'));
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
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('name-only mode starts on the name step with no way back', (tester) async {
    await pumpWelcome(tester, nameOnly: true);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('login step shows the credential form', (tester) async {
    await pumpWelcome(tester);
    await tester.tap(find.text('I already have an account'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Login'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });
}
