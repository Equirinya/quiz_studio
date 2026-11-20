import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/companion/answer_view.dart';

/// The countdown wakes only when it looks different, not every frame: on
/// the big screen every frame is the whole window drawn again.
void main() {
  testWidgets('a running countdown asks for no frame until its seconds or bar change', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 300, child: RoundCountdown(openedAt: now, endsAt: now + 30000, hostClock: true)),
      ),
    ));
    expect(find.text('30 s'), findsOneWidget);
    // No ticker running: nothing asks for the next frame on every frame.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
    }
  });
}
