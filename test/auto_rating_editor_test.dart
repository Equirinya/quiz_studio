import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/games/widgets/companion_editor.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/app_localizations.dart';

/// The editor's settings for rating answers ("Rate automatically" on the
/// controller), and the right answers of an answer list, saved with the
/// question.
void main() {
  Future<List<Map<String, dynamic>>> pump(WidgetTester tester, Question question) async {
    final saved = <Map<String, dynamic>>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: CompanionEditor(gameId: 'g', question: question, save: saved.add)),
      ),
    ));
    await tester.pumpAndSettle();
    return saved;
  }

  testWidgets('ABCD on the devices has no rating by itself any more; how several picks count is kept', (tester) async {
    final question = Question.fromMap('q', const {
      'type': 'abcd',
      'answers': ['a', 'b', 'c', 'd'],
      'companion': {'kind': 'choice', 'multiple': true},
    });
    await pump(tester, question);
    expect(find.text('Rate by itself'), findsNothing);
    // Several picks: how they count, all of them as before by default.
    expect(find.text('All right ones'), findsWidgets);
  });

  testWidgets('an answer list takes right answers, one per line', (tester) async {
    final question = Question.fromMap('q', const {'type': 'free', 'companion': {'kind': 'list', 'listRows': 4}});
    final saved = await pump(tester, question);
    expect(find.widgetWithText(SwitchListTile, 'Rate by itself'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Right answers'), 'Mercury\n\nVenus ');
    await tester.pump();
    final companion = saved.last['companion'] as Map<String, dynamic>;
    expect(companion['solutions'], ['Mercury', 'Venus']);
    expect(CompanionSpec.fromMap(companion)!.solutions, ['Mercury', 'Venus']);
  });
}
