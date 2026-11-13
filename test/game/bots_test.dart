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

  test('a bot answers a round on the devices, and locks in where the scoring goes by time', () {
    final game = orderingGame();
    final state = play(reduce(fixtureState(), const OpenQuestion(orderingRound), game, now: 0).state, game, 'red');
    final answer = state.answerRound!.answers['red']!;
    expect(answer.order!.toSet(), {0, 1, 2, 3});
    expect(answer.locked, isFalse);
    final racing = play(reduce(fixtureState(), const OpenQuestion(race), fixtureGame(), now: 0).state, fixtureGame(), 'red');
    expect(racing.answerRound!.answers['red']!.locked, isTrue);
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

  test('a round only some teams answer: the others can neither answer nor lock, and nobody waits for them', () {
    final game = fixtureGame();
    var s = reduce(fixtureState(), const OpenQuestion(race), game).state;
    s = reduce(s, const OpenAnswers(CompanionSpec(kind: CompanionKind.text, timerSeconds: 60), teams: ['blue']), game, now: 0).state;
    final round = s.answerRound!;
    expect(round.teams, ['blue']);
    expect(s.roundTeams.map((t) => t.id), ['blue']);
    expect(reduce(s, const SubmitAnswer('red', PlayerAnswer(text: 'x')), game).accepted, isFalse);
    expect(reduce(s, const LockAnswer('red'), game).accepted, isFalse);
    expect(botMove(s, game, 'red', Random(1)), isNull);
    s = reduce(s, const SubmitAnswer('blue', PlayerAnswer(text: 'Bohemian Rhapsody 1200')), game).state;
    s = reduce(s, const LockAnswer('blue'), game, now: 1000).state;
    // Blue was the only one to wait for.
    expect(s.answerRound!.open, isFalse);
    s = reduce(s, const RevealAnswers(), game).state;
    expect(s.answerRound!.revealed, ['blue']);

    final red = PublicView(publicView(s, game, teamId: 'red'));
    expect((red.takesPart('red'), red.takesPart('blue')), (false, true));
    final json = AnswerRound.fromJson(s.answerRound!.toJson());
    expect(json.teams, ['blue']);
    final command = Command.fromJson(const OpenAnswers(CompanionSpec(kind: CompanionKind.text), teams: ['red']).toJson())! as OpenAnswers;
    expect(command.teams, ['red']);
  });
}
