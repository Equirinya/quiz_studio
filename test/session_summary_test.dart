import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/session_repository.dart';

void main() {
  test('a session counts as presented only while its presenter is heard from', () {
    const now = 1000000;
    expect(const SessionSummary(id: 's', name: '', hostDevice: 'pc', updatedAtMillis: now - 30000).presentingAt(now), isTrue);
    expect(const SessionSummary(id: 's', name: '', hostDevice: 'pc', updatedAtMillis: now - 600000).presentingAt(now), isFalse,
        reason: 'a presenter that went quiet is gone');
    expect(const SessionSummary(id: 's', name: '', updatedAtMillis: now).presentingAt(now), isFalse, reason: 'nobody claimed it');
  });
}
