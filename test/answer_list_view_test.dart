import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/companion/answer_view.dart';
import 'package:quiz_show/game/game.dart';

/// An answer list on the controller and the big screen shows the lines up
/// to the last one the team filled in, not every empty one after it.
void main() {
  testWidgets('of 20 lines with the 15th the last written, 1 to 15', (tester) async {
    final items = List.filled(20, '')
      ..[0] = 'Mercury'
      ..[14] = 'Pluto';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AnswerView(spec: const CompanionSpec(kind: CompanionKind.list, listRows: 20), answer: PlayerAnswer(items: items)),
        ),
      ),
    ));
    expect(find.text('1. Mercury'), findsOneWidget);
    expect(find.text('2. –'), findsOneWidget, reason: 'gaps before the last one stay');
    expect(find.text('15. Pluto'), findsOneWidget);
    expect(find.textContaining('16.'), findsNothing);
    expect(find.textContaining('20.'), findsNothing);
  });
}
