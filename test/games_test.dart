import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/games/widgets/ranker_import.dart';
import 'package:quiz_show/features/player/recent_sessions.dart';
import 'package:quiz_show/features/session/session_links.dart';
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

  group('invite links', () {
    test('round-trip, and a bare gameId/inviteId works too', () {
      final link = buildInviteLink('Game123', 'Invite_456-x');
      expect(parseInviteLink(link), (gameId: 'Game123', inviteId: 'Invite_456-x'));
      expect(parseInviteLink('  Game123/Invite456 \n'), (gameId: 'Game123', inviteId: 'Invite456'));
    });

    test('anything else is rejected', () {
      expect(parseInviteLink(''), isNull);
      expect(parseInviteLink('quiz-studio://join/onlygame'), isNull);
      expect(parseInviteLink('a/b/c'), isNull);
      expect(parseInviteLink('game/../invite'), isNull);
      expect(parseInviteLink('https://example.com/a/b'), isNull);
    });

    test('expiry', () {
      const invite = GameInvite(gameId: 'g', id: 'i', role: GameRole.limited, gameName: 'G', expiresAtMillis: 1000);
      expect(invite.isExpired(DateTime.fromMillisecondsSinceEpoch(999)), isFalse);
      expect(invite.isExpired(DateTime.fromMillisecondsSinceEpoch(1000)), isTrue);
    });
  });

  group('ranker import', () {
    test('recognises list URLs and finds the list id', () {
      expect(isRankerListUrl('https://www.ranker.com/list/best-smells/jacob-shelton'), isTrue);
      expect(isRankerListUrl('https://ranker.com/crowdranked-list/best-movies'), isTrue);
      expect(isRankerListUrl('https://example.com/list/a/b'), isFalse);
      expect(rankerListId('<script>{"listId": 12345,"x":1}</script>'), '12345');
      expect(rankerListId('<img src="https://imgix.ranker.com/list_img_v2/77/9876/original/x">'), '9876');
      expect(rankerListId('<html></html>'), isNull);
    });

    test('top ten become answers, weighted by score above the eleventh', () {
      final result = buildRankerImport(
        title: 'Best things',
        source: 'Ranker: url',
        items: [for (var i = 0; i < 12; i++) (name: 'item $i', score: 120.0 - i * 10)],
      );
      expect(result.answers, [for (var i = 0; i < 10; i++) 'item $i']);
      expect(result.percentages.reduce((a, b) => a + b), closeTo(100, 1e-9));
      // scores above the baseline of 20: 100, 90, ... 10
      expect(result.percentages.first, closeTo(100 / 550 * 100, 1e-9));
      expect(result.percentages.last, closeTo(10 / 550 * 100, 1e-9));
      expect(result.answerHint, contains('11. item 10'));
      expect(result.answerHint, contains('12. item 11'));
    });

    test('short lists keep one entry back as the baseline; equal scores split evenly', () {
      final result = buildRankerImport(
        title: 't',
        source: 's',
        items: [for (var i = 0; i < 4; i++) (name: 'n$i', score: 5.0)],
      );
      expect(result.answers, ['n0', 'n1', 'n2']);
      expect(result.percentages, everyElement(closeTo(100 / 3, 1e-9)));
    });
  });

  group('session join links', () {
    test('round-trip for controllers and players', () {
      const controller = SessionJoinLink(sessionId: 'S1', token: 'tok', role: Role.controller);
      const player = SessionJoinLink(sessionId: 'S1', token: 'tok', role: Role.player, teamId: 'red');
      expect(controller.link, 'quiz-studio://session/S1/controller/tok');
      expect(player.link, 'quiz-studio://session/S1/player/tok/red');
      final parsed = SessionJoinLink.tryParse(player.link)!;
      expect((parsed.sessionId, parsed.token, parsed.role, parsed.teamId), ('S1', 'tok', Role.player, 'red'));
      expect(SessionJoinLink.tryParse(controller.link)!.teamId, isNull);
    });

    test('rejects other links, unknown roles and a missing or surplus team', () {
      expect(SessionJoinLink.tryParse('quiz-studio://join/g/i'), isNull);
      expect(SessionJoinLink.tryParse('quiz-studio://session/S1/host/tok'), isNull);
      expect(SessionJoinLink.tryParse('quiz-studio://session/S1/player/tok'), isNull);
      expect(SessionJoinLink.tryParse('quiz-studio://session/S1/controller/tok/red'), isNull);
      expect(SessionJoinLink.tryParse('quiz-studio://session/S1/player/t ok/red'), isNull);
      expect(SessionJoinLink.tryParse(''), isNull);
    });
  });

  group('session join links with local addresses', () {
    test('carry them and read them back', () {
      const link = SessionJoinLink(sessionId: 'S1', token: 'tok', role: Role.player, teamId: 'red');
      final withLan = link.withLan(['192.168.1.5:47800', '10.0.0.2:47800']);
      expect(withLan.link, 'quiz-studio://session/S1/player/tok/red?lan=192.168.1.5:47800,10.0.0.2:47800');
      final parsed = SessionJoinLink.tryParse(withLan.link)!;
      expect(parsed.lan, ['192.168.1.5:47800', '10.0.0.2:47800']);
      expect((parsed.sessionId, parsed.token, parsed.teamId), ('S1', 'tok', 'red'));
    });

    test('ignore anything that is not ip:port', () {
      final parsed = SessionJoinLink.tryParse('quiz-studio://session/S1/controller/tok?lan=evil.example.com:80,192.168.1.5:47800,x')!;
      expect(parsed.lan, ['192.168.1.5:47800']);
      expect(SessionJoinLink.tryParse('quiz-studio://session/S1/controller/tok?other=1')!.lan, isEmpty);
    });
  });

  group('recent sessions', () {
    const red = SessionJoinLink(sessionId: 'S1', token: 't1', role: Role.player, teamId: 'red', lan: ['192.168.1.5:47800']);
    const controller = SessionJoinLink(sessionId: 'S1', token: 't2', role: Role.controller);

    test('are remembered newest first, with their local address', () {
      var stored = encodeRecentSessions(const [], red, 1000);
      stored = encodeRecentSessions(decodeRecentSessions(stored), controller, 2000);
      final recent = decodeRecentSessions(stored);
      expect(recent.map((r) => (r.link.role, r.joinedAtMillis)), [(Role.controller, 2000), (Role.player, 1000)]);
      expect(recent.last.link.lan, ['192.168.1.5:47800']);
    });

    test('joining the same session again replaces the old entry', () {
      var stored = encodeRecentSessions(const [], red, 1000);
      stored = encodeRecentSessions(decodeRecentSessions(stored), red.withLan(['10.0.0.9:47800']), 5000);
      final recent = decodeRecentSessions(stored);
      expect(recent, hasLength(1));
      expect(recent.single.joinedAtMillis, 5000);
      expect(recent.single.link.lan, ['10.0.0.9:47800']);
    });

    test('only a handful are kept, and junk is skipped', () {
      var stored = <String>[];
      for (var i = 0; i < 9; i++) {
        stored = encodeRecentSessions(
          decodeRecentSessions(stored),
          SessionJoinLink(sessionId: 'S$i', token: 't', role: Role.controller),
          i,
        );
      }
      expect(decodeRecentSessions(stored).map((r) => r.link.sessionId), ['S8', 'S7', 'S6', 'S5', 'S4']);
      expect(decodeRecentSessions(['not json', '{"link":"nope","at":1}', '{}']), isEmpty);
      expect(decodeRecentSessions(null), isEmpty);
    });
  });
}
