import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/pages/rapid_progress.dart';

void main() {
  testWidgets('the travelling light only ever moves forward, also while the charge grows', (tester) async {
    Future<void> show(double value) => tester.pumpWidget(
      MaterialApp(home: FluxCapacitor(value: value, unleashed: false, size: 300)),
    );
    double travel() =>
        (tester.widget<CustomPaint>(find.descendant(of: find.byType(FluxCapacitor), matching: find.byType(CustomPaint))).painter! as FluxPainter)
            .travel;

    await show(0.3);
    var last = travel();
    var steps = 0;
    for (var frame = 0; frame < 240; frame++) {
      // The charge glides up now and then, as it does after every item.
      if (frame % 40 == 0) await show(0.3 + frame / 600);
      await tester.pump(const Duration(milliseconds: 16));
      final now = travel();
      final step = now >= last ? now - last : now + 1 - last;
      expect(step, lessThan(0.1), reason: 'frame $frame: from $last to $now');
      if (step > 0) steps++;
      last = now;
    }
    expect(steps, greaterThan(200));
  });
}
