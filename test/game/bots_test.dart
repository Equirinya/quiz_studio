import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'betting_fixture.dart';
import 'fixture.dart';
import 'rapid_fixture.dart';

void main() {
  /// Lets the bot for [teamId] move until it has nothing left to do.
  SessionState play(SessionState state, GameContent game, String teamId, {int seed = 1}) {
    final random = Random(seed);
    for (var i = 0; i < 10; i++) {
      final move = botMove(state, game, teamId, random);
      if (move == null || move is Buzz) break;
      expect(mayIssue(Sender(Role.player, teamId: teamId), move), isTrue);
      state = reduce(state, move, game).state;
    }
    return state;
  }

  test('a bot answers a round on the devices and locks in', () {
    final game = orderingGame();
    final state = play(reduce(fixtureState(), const OpenQuestion(orderingRound), game).state, game, 'red');
    final answer = state.answerRound!.answers['red']!;
    expect(answer.order!.toSet(), {0, 1, 2, 3});
    expect(answer.locked, isTrue);
    expect(state.answerRound!.answers['blue'], isNull);
  });

  test('a bot has an answer for every screen but word groups', () {
    final random = Random(3);
    const specs = [
      CompanionSpec(kind: CompanionKind.choice, options: ['a', 'b', 'c']),
      CompanionSpec(kind: CompanionKind.choice, options: ['a', 'b', 'c'], multiple: true),
      CompanionSpec(kind: CompanionKind.match, options: ['a', 'b'], targets: ['1', '2']),
      CompanionSpec(kind: CompanionKind.slider, min: 0, max: 50, step: 5),
      CompanionSpec(kind: CompanionKind.number, solution: 330),
      CompanionSpec(kind: CompanionKind.text),
      CompanionSpec(kind: CompanionKind.list, listRows: 3),
      CompanionSpec(kind: CompanionKind.whiteboard),
    ];
    for (final spec in specs) {
      final answer = botAnswer(spec, random);
      expect(answer == null || answer.isEmpty, isFalse, reason: spec.kind.name);
    }
    final slider = botAnswer(specs[3], random)!.number!;
    expect(slider >= 0 && slider <= 50 && slider % 5 == 0, isTrue);
    expect(botAnswer(const CompanionSpec(kind: CompanionKind.connections), random), isNull);
  });

  test('a bot bets within its limit, and buzzes now and then', () {
    final game = bettingGame();
    final betting = play(reduce(bettingState(), const OpenQuestion(buzzed), game).state, game, 'red');
    final bet = betting.betting!.bets['red'];
    expect(bet, isNotNull);
    expect(bet! <= maxBet(betting.team('red')!, game.question(buzzed)!), isTrue);

    final open = reduce(fixtureState(), const OpenQuestion(free), fixtureGame()).state;
    final random = Random(5);
    final moves = [for (var i = 0; i < 50; i++) botMove(open, fixtureGame(), 'red', random)];
    expect(moves.whereType<Buzz>(), isNotEmpty);
    expect(moves.where((m) => m == null), isNotEmpty);
  });
}
