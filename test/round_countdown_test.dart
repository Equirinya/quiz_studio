import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/companion/answer_view.dart';

void main() {
  testWidgets('a countdown shown again later goes on where it was, not from the start', (tester) async {
    final opened = DateTime.now().millisecondsSinceEpoch;
    Future<void> show(bool on) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: on ? RoundCountdown(openedAt: opened, endsAt: opened + 60000) : const SizedBox())),
    );
    await show(true);
    expect(find.text('60 s'), findsOneWidget);
    // The team sits part of the round out: no countdown for a while.
    await show(false);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500)));
    await show(true);
    await tester.pump();
    expect(find.text('60 s'), findsNothing);
    await show(false);
  });
}
