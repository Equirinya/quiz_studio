import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/core/host_clock.dart';
import 'package:quiz_show/features/companion/answer_view.dart';

/// Countdowns on other devices end when the host's does.
void main() {
  setUp(HostClock.reset);
  tearDown(HostClock.reset);

  test('the quickest state to arrive tells the offset; late ones do not move it', () {
    expect(HostClock.offset, isNull);
    // This device is 5 s ahead; states take 300, 80 and 2000 ms to arrive.
    HostClock.sample(10000, now: 15300);
    HostClock.sample(20000, now: 25080);
    HostClock.sample(30000, now: 37000);
    expect(HostClock.offset, 5080);
    HostClock.sample(null);
    expect(HostClock.offset, 5080);
  });

  testWidgets('a countdown that comes up late still shows the time the host has left', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // The host's clock is 60 s behind this device's. The round opened on the
    // host 40 s ago and has 20 s to go; the countdown only comes up now (the
    // controller opened its panel late).
    final host = now - 60000;
    HostClock.sample(host, now: now);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RoundCountdown(openedAt: host - 40000, endsAt: host + 20000)),
      ),
    );
    expect(find.text('20 s'), findsOneWidget);
  });
}
