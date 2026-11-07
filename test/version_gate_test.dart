import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/core/version_gate.dart';

void main() {
  group('compareVersions', () {
    test('orders by numeric component, not by string', () {
      expect(compareVersions('2.0.0', '2.0.1'), lessThan(0));
      expect(compareVersions('2.10.0', '2.9.0'), greaterThan(0));
      expect(compareVersions('1.9.9', '2.0.0'), lessThan(0));
    });

    test('ignores the build number and missing components', () {
      expect(compareVersions('2.0.0+200', '2.0.0'), 0);
      expect(compareVersions('2.0', '2.0.0'), 0);
    });

    test('treats junk as zero instead of throwing', () {
      expect(compareVersions('abc', '0.0.0'), 0);
      expect(compareVersions('', '1.0.0'), lessThan(0));
    });
  });
}
