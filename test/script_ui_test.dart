import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/games/pages/script_editor_page.dart';
import 'package:quiz_show/features/games/widgets/script_format.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/features/session/widgets/script_sheet.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

import 'game/fixture.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// Ten categories of five questions, each with a long script text.
GameContent _longGame() {
  final long = List.filled(12, 'A line of the script to read out.').join('\n');
  return GameContent.assemble(
    id: 'long',
    game: {
      GameScript.field: {
        for (var c = 0; c < 10; c++) ...{
          'c_c$c': long,
          for (var q = 0; q < 5; q++) 'q_c${c}q$q': long,
        },
      },
    },
    groups: {},
    categories: {for (var c = 0; c < 10; c++) 'c$c': {'name': 'Category $c', 'categoryIndex': c}},
    questions: {
      for (var c = 0; c < 10; c++)
        'c$c': {for (var q = 0; q < 5; q++) 'c${c}q$q': {'type': 'free', 'question': 'Question $c.$q', 'questionIndex': q}},
    },
  );
}

void main() {
  group('script sheet on the controller', () {
    Future<double> open(WidgetTester tester, {QuestionRef? current, double? lastOffset}) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const SizedBox()));
      await tester.pumpWidget(_app(Scaffold(
        body: ScriptSheet(key: UniqueKey(), game: _longGame(), current: current, lastOffset: lastOffset),
      )));
      await tester.pump();
      return tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    }

    double dividerTop(WidgetTester tester, String text) => tester.getTopLeft(find.textContaining(text)).dy;

    testWidgets('opens at the open question', (tester) async {
      final offset = await open(tester, current: const QuestionRef('c6', 'c6q2'));
      expect(offset, greaterThan(1000));
      final top = dividerTop(tester, 'Question: Question 6.2');
      // At the top of the sheet, just under its title row.
      expect(top, lessThan(150));
    });

    testWidgets('stays where it was left when the question is already in view', (tester) async {
      final jumped = await open(tester, current: const QuestionRef('c6', 'c6q2'));
      // Left a little above the question, its divider still in view.
      final stayed = await open(tester, current: const QuestionRef('c6', 'c6q2'), lastOffset: jumped - 200);
      expect(stayed, jumped - 200);
      // Left far away: it jumps again.
      final far = await open(tester, current: const QuestionRef('c6', 'c6q2'), lastOffset: 100);
      expect(far, jumped);
    });

    testWidgets('without an open question it opens at the intro the first time', (tester) async {
      expect(await open(tester), 0);
    });

    testWidgets('the controller has a Script tab showing the game\'s dividers', (tester) async {
      tester.view.physicalSize = const Size(460, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final host = SessionHost(initial: fixtureState());
      final connection = SessionConnection.local(host, game: fixtureGame());
      addTearDown(connection.dispose);
      await tester.pumpWidget(_app(Scaffold(body: ControllerView(connection: connection))));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Script'));
      await tester.pumpAndSettle();
      expect(find.byType(ScriptSheet), findsOneWidget);
      expect(find.textContaining('Category: '), findsWidgets);
      expect(find.textContaining('No script yet'), findsOneWidget);
    });
  });

  group('script editor', () {
    testWidgets('writes each section on its own, formatted with the toolbar', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saved = <Map<String, dynamic>>[];
      final game = fixtureGame();
      await tester.pumpWidget(_app(ScriptEditorView(game: game, save: (update) async => saved.add(update))));

      // One divider per category and question, in game order.
      final sections = GameScript.sections(game);
      expect(find.byType(ScriptDivider), findsNWidgets(sections.length));
      final firstCategory = sections.firstWhere((s) => s.kind == ScriptSectionKind.category);
      expect(find.text('Category: ${firstCategory.title}'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'Welcome everyone');
      await tester.pump(const Duration(seconds: 1));
      expect(saved, [
        {'script.${firstCategory.key}': 'Welcome everyone'},
      ]);

      final controller = tester.widget<TextField>(fields.at(1)).controller!;
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 7);
      await tester.tap(find.byTooltip('Bold'));
      await tester.pump();
      expect(controller.text, '**Welcome** everyone');
      await tester.tap(find.byTooltip('Heading'));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.text, '# **Welcome** everyone');
      expect(saved.last, {'script.${firstCategory.key}': '# **Welcome** everyone'});
    });

    test('text controller helpers', () {
      final c = ScriptTextController(text: 'one\ntwo');
      c.selection = const TextSelection.collapsed(offset: 5);
      c.toggleLinePrefix('- ');
      expect(c.text, 'one\n- two');
      c.toggleLinePrefix('## ');
      expect(c.text, 'one\n## two');
      c.toggleLinePrefix('## ');
      expect(c.text, 'one\ntwo');
      c.selection = const TextSelection(baseOffset: 4, extentOffset: 7);
      c.wrapSelection('{red}', '{/}');
      expect(c.text, 'one\n{red}two{/}');
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 6);
      c.clearFormatting();
      expect(c.text, 'one\ntwo');
    });
  });
}
