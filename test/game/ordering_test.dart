import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';
import 'rapid_fixture.dart';

void main() {
  final game = orderingGame();
  final question = game.question(orderingRound)!;

  test('read back with its entries, pictures cached, and only playable on devices', () {
    expect(question.type, QuestionType.ordering);
    expect(question.ordering!.items, hasLength(4));
    expect(question.needsDevices, isTrue);
    expect(question.buzzerable, isFalse);
    expect(question.type.wagerable, isTrue);
    expect(question.maxReveal, 4);
    expect(game.mediaPaths, contains('iphone.png'));
    expect(Ordering.fromMap(question.ordering!.toMap()).toMap(), question.ordering!.toMap());
    expect(questionAsText(question), contains('1. Moon landing – 1969'));
  });

  test('opening it starts an order round on the devices; a picture alone gets a name that gives nothing away', () {
    final s = reduce(fixtureState(), const OpenQuestion(orderingRound), game, now: 1000).state;
    final spec = s.answerRound!.spec;
    expect((spec.kind, spec.timerSeconds, spec.options.first), (CompanionKind.order, 60, 'Moon landing'));
    expect(spec.options[2], matches(RegExp(r'^Picture [1-4]$')));
    expect(spec.pictures, ['iphone.png']);
    final items = spec.toPublicMap(s.current!.key)['items'] as List;
    expect(items.firstWhere((item) => item['i'] == 2)['img'], 'iphone.png');
    // What each is sorted by stays with the gamemaster.
    expect(publicView(s, game, teamId: 'red').toString(), isNot(contains('1969')));
  });

  test('the three ways of scoring', () {
    const swapped = [1, 0, 2, 3];
    const shifted = [3, 0, 1, 2];
    expect(orderScore(swapped, 4, OrderScoring.places), (right: 2, of: 4));
    expect(orderScore(shifted, 4, OrderScoring.places), (right: 0, of: 4));
    // One entry out of place costs only the pairs it is in.
    expect(orderScore(shifted, 4, OrderScoring.pairs), (right: 3, of: 6));
    expect(orderScore(swapped, 4, OrderScoring.pairs), (right: 5, of: 6));
    expect(orderScore([0, 1, 2, 3], 4, OrderScoring.pairs), (right: 6, of: 6));
    expect(orderScore(swapped, 4, OrderScoring.exact), (right: 0, of: 1));
    expect(orderScore([0, 1, 2, 3], 4, OrderScoring.exact), (right: 1, of: 1));
  });

  test('rating automatically follows the scoring of the question', () {
    SessionState played(GameContent game) {
      var s = reduce(fixtureState(), const OpenQuestion(orderingRound), game).state;
      s = reduce(s, const SubmitAnswer('red', PlayerAnswer(order: [3, 0, 1, 2])), game).state;
      s = reduce(s, const LockAnswers(), game).state;
      for (final command in [...autoRating(s, s.answerRound!, game.question(orderingRound)!), const GivePoints()]) {
        s = reduce(s, command, game).state;
      }
      return s;
    }

    expect(played(orderingGame()).results.verdicts['red'], isFalse);
    expect(played(orderingGame(scoring: 'pairs')).results.given['red'], 30);
    expect(played(orderingGame(scoring: 'exact')).results.verdicts['red'], isFalse);
  });

  test('the big screen puts one entry in place per step, the last two together, and back', () {
    var s = reduce(fixtureState(), const OpenQuestion(orderingRound), game).state;
    s = reduce(s, const LockAnswers(), game).state;
    // The last of four goes in with the third: it has only one place left.
    for (final expected in [1, 2, 4]) {
      s = reduce(s, const Reveal(1), game).state;
      expect(s.revealed, expected);
    }
    expect(reduce(s, const Reveal(1), game).accepted, isFalse);
    expect(reduce(s, const Reveal(-1), game).state.revealed, 2);
  });

  test('a free question that sorted on the devices brings its entries along when it becomes one', () {
    final old = Ordering.fromMap(null, companion: {'kind': 'order', 'options': ['a', 'b', 'c']});
    expect([for (final item in old.items) item.text], ['a', 'b', 'c']);
    final pairs = Matching.fromMap(null, companion: {'kind': 'match', 'options': ['a', 'b'], 'targets': ['1', '2']});
    expect(pairs.pairs.map((p) => '${p.left.text}=${p.right.text}'), ['a=1', 'b=2']);
  });

  test('the order teams start from gives less than half away, and is the same in every copy of the app', () {
    const spec = CompanionSpec(kind: CompanionKind.order, options: ['a', 'b', 'c', 'd', 'e', 'f', 'g']);
    const match = CompanionSpec(kind: CompanionKind.match, options: ['a', 'b', 'c', 'd', 'e'], targets: ['1', '2', '3', '4', '5']);
    for (var seed = 0; seed < 40; seed++) {
      final shown = [for (final item in spec.toPublicMap('q$seed')['items'] as List) item['i'] as int];
      expect(orderScore(shown, 7, OrderScoring.pairs).right * 2, lessThan(21), reason: 'seed $seed: $shown');
      final targets = [for (final item in match.toPublicMap('q$seed')['items'] as List) item['i'] as int];
      expect([for (var i = 0; i < 5; i++) if (targets[i] == i) i].length * 2, lessThan(5), reason: 'seed $seed: $targets');
    }
    // Pinned: a hash that changed between runs would put the big screen and
    // the devices out of step.
    expect([for (final item in spec.toPublicMap('fixed')['items'] as List) item['i']], const [5, 1, 6, 3, 2, 4, 0]);
  });
}
