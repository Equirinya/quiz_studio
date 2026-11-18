import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/boards/info_board.dart';
import 'package:quiz_show/game/game.dart';

void main() {
  testWidgets('the information screen shows its text and the time left', (tester) async {
    final group = CategoryGroup(id: 'break', name: 'Break', type: BoardType.info, text: 'Back soon', data: const {'timer': 300});
    final now = DateTime.now().millisecondsSinceEpoch;
    final state = SessionState(timer: QuestionTimer(openedAtMillis: now, endsAtMillis: now + 300 * 1000));
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: InfoBoard(group: group, state: state, unit: 9, imageFile: (_) => null)),
    ));
    expect(find.text('Back soon'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^[45]:\d\d$')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
