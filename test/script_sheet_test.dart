import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/widgets/script_sheet.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The script opens where it was left, also after the app was closed.
void main() {
  final long = List.filled(80, 'A line of the script to read out.').join('\n');
  final game = GameContent.assemble(
    id: 'g',
    game: {
      'name': 'Show',
      'script': {'intro': long, 'c_history': long, 'q_h1': 'Ask it slowly.', 'q_h2': long},
    },
    groups: const {
      'r1': {'name': 'Round 1', 'categoryGroupIndex': 0},
    },
    categories: const {
      'history': {'name': 'History', 'categoryGroup': 'r1', 'categoryIndex': 0},
    },
    questions: const {
      'history': {
        'h1': {'type': 'free', 'question': 'When was Rome founded?', 'pointsPlus': 100},
        'h2': {'type': 'free', 'question': 'Who crossed the Alps?', 'pointsPlus': 200},
      },
    },
  );

  Future<ScrollPosition> open(WidgetTester tester, {QuestionRef? current, Set<String> played = const {}}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ScriptSheet(key: UniqueKey(), game: game, current: current, played: played)),
    ));
    await tester.pumpAndSettle();
    // The script's own scroll view, the one around all its sections.
    return tester.state<ScrollableState>(find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).first).position;
  }

  testWidgets('the first time at the open question, then where it was left', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var position = await open(tester, current: const QuestionRef('history', 'h1'));
    expect(position.pixels, greaterThan(500), reason: 'jumped to the question');

    position.jumpTo(120);
    await tester.pump(const Duration(seconds: 1));
    // Closed and opened again, another question open: stays where it was read.
    await tester.pumpWidget(const SizedBox());
    position = await open(tester, current: const QuestionRef('history', 'h1'));
    expect(position.pixels, 120);
  });

  testWidgets('with no question open, "to current" goes to the end of the question played last', (tester) async {
    SharedPreferences.setMockInitialValues({'scriptOffset/g': 0.0});
    final position = await open(tester, played: {'history/h2', 'history/h1'});
    expect(position.pixels, 0, reason: 'opened where it was left');
    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(500), reason: 'not the start of the game');
    // Rome's last lines at the top, and what follows below them.
    final top = tester.getTopLeft(find.byType(SingleChildScrollView)).dy;
    final end = tester.getRect(find.text('Ask it slowly.'));
    expect(end.top, greaterThan(top - end.height));
    expect(end.bottom, lessThan(top + 100));
    expect(find.textContaining('Who crossed the Alps?'), findsOneWidget);
  });
}
