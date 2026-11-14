import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/widgets/team_colors.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/app_localizations.dart';

void main() {
  Future<List<int?>> pumpPicker(WidgetTester tester, int? selected) async {
    final picked = <int?>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: SizedBox(width: 400, child: TeamColorPicker(selected: selected, onChanged: picked.add))),
    ));
    return picked;
  }

  testWidgets('a team can take any colour from the wheel, not only the row', (tester) async {
    final picked = await pumpPicker(tester, null);
    await tester.tap(find.byTooltip('Own colour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(picked.single, isNotNull);
    expect(picked.single! >> 24, 0xFF, reason: 'never see-through');
  });

  testWidgets('a colour of its own shows as picked, the row\'s still pick as before', (tester) async {
    const own = 0xFF123456;
    expect(teamColors, isNot(contains(own)));
    final picked = await pumpPicker(tester, own);
    final dot = tester.widget<Container>(
      find.descendant(of: find.byTooltip('Own colour'), matching: find.byType(Container)).first,
    );
    expect((dot.decoration! as BoxDecoration).color, const Color(own));
    await tester.tap(find.byTooltip('Use this colour').first);
    expect(picked, [teamColors.first]);
  });
}
