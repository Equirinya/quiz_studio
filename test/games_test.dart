import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

void main() {
  group('planCategoryMove', () {
    // g1: c1 (0), c2 (1) · g2: c3 (0)
    final game = fixtureGame();

    test('within a group only the swapped categories are written', () {
      expect(planCategoryMove(game, 'c1', 'g1', 1), {
        'c2': (groupId: 'g1', index: 0),
        'c1': (groupId: 'g1', index: 1),
      });
    });

    test('moving to where it already is writes nothing', () {
      expect(planCategoryMove(game, 'c1', 'g1', 0), isEmpty);
      expect(planCategoryMove(game, 'c2', 'g1', 99), isEmpty);
    });

    test('to another group: inserted there, the gap closed here', () {
      expect(planCategoryMove(game, 'c1', 'g2', 0), {
        'c1': (groupId: 'g2', index: 0),
        'c3': (groupId: 'g2', index: 1),
        'c2': (groupId: 'g1', index: 0),
      });
    });

    test('out of every group', () {
      expect(planCategoryMove(game, 'c3', null, 0), {'c3': (groupId: null, index: 0)});
      expect(planCategoryMove(game, 'c3', CategoryGroup.ungroupedId, 0), {'c3': (groupId: null, index: 0)});
    });

    test('unknown categories are ignored', () {
      expect(planCategoryMove(game, 'nope', 'g1', 0), isEmpty);
    });
  });

  group('media names', () {
    test('are random and keep the lower-cased extension', () {
      final a = newMediaName('/tmp/My Photo.PNG', random: Random(1));
      final b = newMediaName(r'C:\Users\me\song.mp3', random: Random(2));
      expect(a, matches(RegExp(r'^[a-z0-9]{20}\.png$')));
      expect(b, matches(RegExp(r'^[a-z0-9]{20}\.mp3$')));
      expect(newMediaName('noextension', random: Random(3)), matches(RegExp(r'^[a-z0-9]{20}$')));
      expect(newMediaName('a.png'), isNot(newMediaName('a.png')));
    });

    test('content types cover what the storage rules accept', () {
      expect(contentTypeForPath('a.JPG'), 'image/jpeg');
      expect(contentTypeForPath('b.m4a'), 'audio/mp4');
      expect(contentTypeForPath('c.exe'), isNull);
      expect(contentTypeForPath('noextension'), isNull);
    });
  });

  test('GameRole reads the three access arrays', () {
    final game = {'admin': ['a'], 'full': ['f'], 'limited': ['l']};
    expect(GameRole.of(game, 'a'), GameRole.admin);
    expect(GameRole.of(game, 'f'), GameRole.full);
    expect(GameRole.of(game, 'l'), GameRole.limited);
    expect(GameRole.of(game, 'x'), isNull);
    expect(GameRole.of({}, 'a'), isNull);
    expect(GameRole.limited.seesEverything, isFalse);
  });
}
