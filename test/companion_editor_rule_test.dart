import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/games/widgets/companion_editor.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/app_localizations.dart';

/// How teams answer, tied to the scoring rule.
void main() {
  final question = Question.fromMap('q', {'type': 'free', 'question': 'How tall?', 'pointsPlus': 300});

  Future<List<Map<String, dynamic>>> pump(WidgetTester tester, GlobalKey<CompanionEditorState> key, {bool number = false, bool screen = false}) async {
    final saved = <Map<String, dynamic>>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: CompanionEditor(key: key, gameId: 'g', question: question, save: saved.add, needsNumber: number, needsScreen: screen),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return saved;
  }

  List<DropdownMenuEntry<String>> entries(WidgetTester tester) =>
      tester.widget<DropdownMenu<String>>(find.byType(DropdownMenu<String>).first).dropdownMenuEntries;

  testWidgets('by closeness greys out everything but a number or slider, and picks a number', (tester) async {
    final key = GlobalKey<CompanionEditorState>();
    final saved = await pump(tester, key, number: true);
    final enabled = {for (final entry in entries(tester)) entry.value: entry.enabled};
    expect(enabled, {'buzzer': false, 'nothing': false, 'whiteboard': false, 'text': false, 'number': true, 'slider': true, 'list': false});
    expect(find.text('By closeness needs a number or slider to answer with.'), findsOneWidget);

    key.currentState!.fitRule(number: true);
    await tester.pump();
    expect((saved.last['companion'] as Map)['kind'], 'number');
  });

  testWidgets('by speed greys out the buzzer and nothing, and picks a screen', (tester) async {
    final key = GlobalKey<CompanionEditorState>();
    final saved = await pump(tester, key, screen: true);
    final enabled = {for (final entry in entries(tester)) entry.value: entry.enabled};
    expect(enabled['buzzer'], isFalse);
    expect(enabled['nothing'], isFalse);
    expect(enabled['text'], isTrue);

    key.currentState!.fitRule(number: false);
    await tester.pump();
    expect(saved.last['companion'], isNotNull);
  });
}
