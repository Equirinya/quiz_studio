import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/settings/account_deletion.dart';

void main() {
  group('leaving games when the account is deleted', () {
    test('a game nobody else is in is deleted', () {
      expect(exitFor('me', {'admin': ['me'], 'full': [], 'limited': []}), isA<DeleteGame>());
    });

    test('an only admin hands the game to a full member, or else to a limited one', () {
      expect((exitFor('me', {'admin': ['me'], 'full': ['ann', 'bob'], 'limited': ['liz']}) as LeaveGame).promote, 'ann');
      expect((exitFor('me', {'admin': ['me'], 'full': [], 'limited': ['liz']}) as LeaveGame).promote, 'liz');
    });

    test('with another admin, or as a co-author, the account just leaves', () {
      expect((exitFor('me', {'admin': ['me', 'ada'], 'full': [], 'limited': []}) as LeaveGame).promote, isNull);
      expect((exitFor('me', {'admin': ['ada'], 'full': ['me'], 'limited': []}) as LeaveGame).promote, isNull);
      expect((exitFor('me', {'admin': ['ada'], 'limited': ['me']}) as LeaveGame).promote, isNull);
    });
  });
}
