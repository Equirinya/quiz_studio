import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'betting_fixture.dart';
import 'fixture.dart';

SessionState play(List<Command> commands, {SessionState? from, int? now}) {
  var state = from ?? bettingState();
  for (final command in commands) {
    final result = reduce(state, command, bettingGame(), now: now);
    if (!result.accepted) throw StateError('rejected: ${command.toJson()}');
    state = result.state;
  }
  return state;
}

bool accepts(SessionState state, Command command) => reduce(state, command, bettingGame()).accepted;

void main() {
  group('the question option', () {
    test('is read from the stored question and only counts where it fits', () {
      final game = bettingGame();
      expect(game.question(buzzed)!.betting, isTrue);
      expect(game.question(feudBet)!.wager, isTrue);
      expect(game.question(feudBet)!.betting, isFalse);
      expect(fixtureGame().question(free)!.betting, isFalse);
    });

    test('bet limits: own points, or the question points (at least 100) when fewer', () {
      final question = bettingGame().question(buzzed)!;
      expect(maxBet(const Team(id: 'a', name: 'A', points: 500), question), 500);
      expect(maxBet(const Team(id: 'a', name: 'A'), question), 200);
      expect(maxBet(const Team(id: 'a', name: 'A', points: -300), question), 200);
      expect(maxBet(const Team(id: 'a', name: 'A'), bettingGame().question(guessed)!), kMinBetLimit);
    });
  });

  group('betting', () {
    test('opening a question with bets waits for them; buzzers stay shut', () {
      final open = play(const [OpenQuestion(buzzed)]);
      expect(open.placingBets, isTrue);
      expect(open.phase, Phase.question);
      expect(buzzersOpen(open, bettingGame()), isFalse);
      expect(accepts(open, const Buzz('red')), isFalse);
      expect(accepts(open, const Reveal(1)), isFalse);

      final started = play(const [CloseBets(), StartQuestion()], from: open);
      expect(started.placingBets, isFalse);
      expect(buzzersOpen(started, bettingGame()), isTrue);
    });

    test('closed bets go up on the big screen before the question starts', () {
      final shown = play(const [OpenQuestion(picked), PlaceBet('red', 300), PlaceBet('blue', 100), CloseBets()], now: 0);
      expect(shown.betsShown, isTrue);
      expect(shown.waitingForBets, isTrue);
      expect(shown.answerRound, isNull);
      expect(accepts(shown, const PlaceBet('red', 10)), isFalse);
      expect(accepts(shown, const Reveal(1)), isFalse);
      final blue = PublicView(publicView(shown, bettingGame(), teamId: 'blue'));
      expect(blue.betsShown, isTrue);
      expect(blue.bets, {'red': 300, 'blue': 100});
      expect(blue.question!['text'], '');

      final result = reduce(shown, const StartQuestion(), bettingGame(), now: 2000);
      expect(result.effects.whereType<SoundEffect>().single.key, effectQuestionOpen);
      expect(result.state.waitingForBets, isFalse);
      expect(result.state.answerRound!.endsAtMillis, 22000);
      expect(accepts(result.state, const StartQuestion()), isFalse);
      expect(accepts(play(const [OpenQuestion(picked)]), const StartQuestion()), isFalse);
    });

    test('bets on an amount are judged only once the question runs', () {
      final shown = play(const [OpenQuestion(pushUps), PlaceBet('red', 20), CloseBets()]);
      expect(accepts(shown, const JudgeBet('red', reached: true)), isFalse);
      expect(shown.timer, isNull);
    });

    test('a question without bets has no betting', () {
      final open = run(fixtureState(), const [OpenQuestion(free)]);
      expect(open.betting, isNull);
      expect(reduce(open, const PlaceBet('red', 10), fixtureGame()).accepted, isFalse);
      expect(reduce(open, const CloseBets(), fixtureGame()).accepted, isFalse);
    });

    test('bets are kept between nothing and the limit, and can change until closed', () {
      final state = play(const [OpenQuestion(buzzed), PlaceBet('red', 900), PlaceBet('blue', 150), PlaceBet('green', -20)]);
      expect(state.betting!.bets, {'red': 500, 'blue': 150, 'green': 0});
      final changed = play(const [PlaceBet('blue', 200), CloseBets(), StartQuestion()], from: state);
      expect(changed.betting!.bets['blue'], 200);
      expect(accepts(changed, const PlaceBet('blue', 100)), isFalse);
    });

    test('players may only bet for their own team', () {
      const player = Sender(Role.player, teamId: 'red');
      expect(mayIssue(player, const PlaceBet('red', 10)), isTrue);
      expect(mayIssue(player, const PlaceBet('blue', 10)), isFalse);
      expect(mayIssue(player, const CloseBets()), isFalse);
      expect(mayIssue(const Sender(Role.controller), const PlaceBet('blue', 10)), isTrue);
    });

    test('commands and state survive JSON', () {
      for (final command in const [PlaceBet('red', 120), CloseBets(), StartQuestion()]) {
        expect(Command.fromJson(jsonDecode(jsonEncode(command.toJson())) as Map<String, dynamic>)!.toJson(), command.toJson());
      }
      final state = play(const [OpenQuestion(buzzed), PlaceBet('red', 120)]);
      final back = SessionState.fromJson(jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>);
      expect(back.betting!.open, isTrue);
      expect(back.betting!.bets, {'red': 120});
    });

    test('closing the question clears the bets', () {
      final state = play(const [OpenQuestion(buzzed), PlaceBet('red', 100), CloseQuestion()]);
      expect(state.betting, isNull);
    });
  });

  group('buzzer answers', () {
    test('right wins the bet, wrong loses it, a team without a bet plays for nothing', () {
      final bets = play(const [OpenQuestion(buzzed), PlaceBet('red', 300), PlaceBet('blue', 200), CloseBets(), StartQuestion()]);
      final wrong = play(const [Buzz('red'), Judge(correct: false)], from: bets);
      expect(points(wrong, 'red'), 200);
      final right = play(const [Buzz('blue'), Judge(correct: true)], from: wrong);
      expect(points(right, 'blue'), 200);
      expect(right.betting, isNull);

      final green = play(const [Buzz('green'), Judge(correct: true)], from: bets);
      expect(points(green, 'green'), -50);
    });
  });

  group('device answers', () {
    test('the answer round starts when the bets are closed, with its timer from then', () {
      final open = play(const [OpenQuestion(picked)], now: 1000);
      expect(open.answerRound, isNull);
      expect(accepts(open, const OpenAnswers(CompanionSpec(kind: CompanionKind.text))), isFalse);
      final started = play(const [CloseBets(), StartQuestion()], from: open, now: 5000);
      expect(started.answerRound!.kind, CompanionKind.choice);
      expect(started.answerRound!.endsAtMillis, 25000);
    });

    test('rating wins or loses each team its own bet, and changing a ruling never counts twice', () {
      var state = play(const [OpenQuestion(picked), PlaceBet('red', 400), PlaceBet('blue', 100), CloseBets(), StartQuestion()]);
      state = play(const [
        SubmitAnswer('red', PlayerAnswer(choice: 1)),
        SubmitAnswer('blue', PlayerAnswer(choice: 0)),
        LockAnswers(),
      ], from: state);
      final question = bettingGame().question(picked)!;
      final auto = autoRating(state, state.answerRound!, question);
      state = play([...auto, const GivePoints()], from: state);
      expect(points(state, 'red'), 900);
      expect(points(state, 'blue'), -100);
      expect(state.results.given, {'red': 400, 'blue': -100});
      expect(autoRating(state, state.answerRound!, question), isEmpty);

      state = play(const [RateAnswer('red', correct: false), GivePoints()], from: state);
      expect(points(state, 'red'), 100);
      expect(pointsIfRight(state, question, 'red'), 400);
      expect(pointsIfWrong(state, question, 'blue'), 100);
    });

    test('estimates share out each team\'s own bet; the furthest loses it', () {
      var state = play(const [
        OpenQuestion(guessed),
        PlaceBet('red', 400),
        PlaceBet('blue', 100),
        PlaceBet('green', 100),
        CloseBets(), StartQuestion(),
        SubmitAnswer('red', PlayerAnswer(number: 100)),
        SubmitAnswer('blue', PlayerAnswer(number: 150)),
        SubmitAnswer('green', PlayerAnswer(number: 200)),
        LockAnswers(),
      ]);
      final question = bettingGame().question(guessed)!;
      state = play([...estimateRating(state, state.answerRound!, question, EstimateScoring.distance), const GivePoints()], from: state);
      expect(points(state, 'red'), 900);
      expect(points(state, 'blue'), 50);
      expect(points(state, 'green'), -150);
    });
  });

  group('what devices see', () {
    test('while betting: no question text, nobody else\'s bet, own bet and limit', () {
      final state = play(const [OpenQuestion(buzzed), PlaceBet('red', 300)]);
      final red = PublicView(publicView(state, bettingGame(), teamId: 'red'));
      final blue = PublicView(publicView(state, bettingGame(), teamId: 'blue'));
      expect(red.placingBets, isTrue);
      expect(red.ownBet, 300);
      expect(red.ownMaxBet, 500);
      expect(red.betCategory, 'All in');
      expect(blue.ownBet, isNull);
      expect(blue.ownMaxBet, 200);
      expect(blue.hasBet('red'), isTrue);
      expect(blue.bets, isEmpty);
      final shared = jsonEncode(publicView(state, bettingGame(), teamId: 'blue'));
      expect(shared, isNot(contains('300')));
      expect(shared, isNot(contains('Peru')));
    });

    test('once closed: the question and every bet', () {
      final state = play(const [OpenQuestion(buzzed), PlaceBet('red', 300), CloseBets(), StartQuestion()]);
      final blue = PublicView(publicView(state, bettingGame(), teamId: 'blue'));
      expect(blue.placingBets, isFalse);
      expect(blue.bets, {'red': 300});
      expect(blue.question!['text'], 'Capital of Peru?');
    });
  });

  group('bets on an amount', () {
    test('only free questions take them; they replace bets of points and buzzers', () {
      final game = bettingGame();
      expect(game.question(films)!.amountBet!.max, 10);
      expect(game.question(films)!.hasBets, isTrue);
      expect(game.question(films)!.betting, isFalse);
      expect(game.question(films)!.buzzerable, isFalse);
      expect(Question.fromMap('q', const {'type': 'abcd', 'amountBet': {'max': 3}}).amountBet, isNull);
      expect(maxBet(const Team(id: 'a', name: 'A', points: 900), game.question(pushUps)!), 50);
    });

    test('first the prompt, then the question with a list long enough for the boldest bet', () {
      final open = play(const [OpenQuestion(films)], now: 0);
      expect(open.placingBets, isTrue);
      expect(open.answerRound, isNull);
      final blue = PublicView(publicView(open, bettingGame(), teamId: 'blue'));
      expect(blue.betsOnAmount, isTrue);
      expect(blue.betPrompt, 'How many science fiction films can you name?');
      expect(blue.ownMaxBet, 10);
      expect(jsonEncode(publicView(open, bettingGame())), isNot(contains('Name science fiction films')));

      final started = play(const [PlaceBet('red', 7), PlaceBet('blue', 2), PlaceBet('green', 99), CloseBets(), StartQuestion()], from: open, now: 1000);
      expect(started.betting!.bets, {'red': 7, 'blue': 2, 'green': 10});
      expect(started.answerRound!.spec.listRows, 10);
      expect(started.answerRound!.endsAtMillis, 61000);
      expect(started.timer, isNull);
    });

    test('reached: the points times the bet; missed: minus points times the bet; rulings can change', () {
      var state = play(const [OpenQuestion(pushUps), PlaceBet('red', 20), PlaceBet('blue', 5), CloseBets(), StartQuestion()], now: 0);
      expect(state.answerRound, isNull);
      expect(state.timer!.endsAtMillis, 30000);
      state = play(const [JudgeBet('red', reached: true), JudgeBet('blue', reached: false), GivePoints()], from: state);
      expect(points(state, 'red'), 700);
      expect(points(state, 'blue'), -50);
      state = play(const [JudgeBet('red', reached: false), GivePoints()], from: state);
      expect(points(state, 'red'), 300);
      state = play(const [JudgeBet('red', reached: null), GivePoints()], from: state);
      expect(points(state, 'red'), 500);
      expect(accepts(state, const JudgeBet('blue', reached: false)), isFalse);
      final view = PublicView(publicView(state, bettingGame()));
      expect(view.betVerdict('blue'), isFalse);
      expect(view.bets, {'red': 20, 'blue': 5});
    });

    test('without minus points a missed bet costs nothing', () {
      final state = play(const [OpenQuestion(films), PlaceBet('red', 4), CloseBets(), StartQuestion(), JudgeBet('red', reached: false)]);
      expect(points(state, 'red'), 500);
      expect(state.results.verdicts['red'], isFalse);
    });

    test('rating the answer cards judges the bet, with no double counting', () {
      var state = play(const [
        OpenQuestion(films),
        PlaceBet('red', 4),
        CloseBets(), StartQuestion(),
        SubmitAnswer('red', PlayerAnswer(items: ['Alien', 'Dune', 'Brazil', 'Solaris'])),
        LockAnswers(),
      ]);
      expect(autoRating(state, state.answerRound!, bettingGame().question(films)!), isEmpty);
      state = play(const [RateAnswer('red', correct: true), GivePoints()], from: state);
      expect(points(state, 'red'), 700);
      expect(state.results.verdicts['red'], isTrue);
      state = play(const [AwardAnswer('red', 100), GivePoints()], from: state);
      expect(points(state, 'red'), 600);
      expect(state.results.given['red'], 100);
    });

    test('judging waits for the bets to be in, and only fits amount bets', () {
      expect(accepts(play(const [OpenQuestion(films)]), const JudgeBet('red', reached: true)), isFalse);
      expect(accepts(play(const [OpenQuestion(buzzed), CloseBets(), StartQuestion()]), const JudgeBet('red', reached: true)), isFalse);
    });
  });

  group('a question\'s own timer', () {
    test('starts with the question when the devices have no screen, and ends once', () {
      final open = play(const [OpenQuestion(timed)], now: 5000);
      expect(open.timer!.endsAtMillis, 25000);
      expect(PublicView(publicView(open, bettingGame())).questionTimer!.endsAt, 25000);
      final result = reduce(open, const TimeUp(), bettingGame());
      expect(result.state.timer!.running, isFalse);
      expect(result.effects.whereType<SoundEffect>().single.key, effectTimesUp);
      expect(accepts(result.state, const TimeUp()), isFalse);
      expect(play(const [CloseQuestion()], from: result.state).timer, isNull);
    });

    test('a screen on the devices keeps its own timer instead', () {
      expect(bettingGame().question(picked)!.questionTimer, isNull);
      expect(play(const [OpenQuestion(picked), CloseBets(), StartQuestion()], now: 0).timer, isNull);
    });

    test('the host stops it when the time is up', () {
      fakeAsync((async) {
        var clock = 0;
        final host = SessionHost(initial: bettingState(), game: bettingGame(), clock: () => clock);
        final effects = <Effect>[];
        host.effects.listen(effects.add);
        host.dispatch(const OpenQuestion(timed));
        clock = 20000;
        async.elapse(const Duration(seconds: 20));
        expect(host.state.timer!.running, isFalse);
        expect(effects.whereType<SoundEffect>().map((e) => e.key), contains(effectTimesUp));
        host.dispose();
      });
    });
  });
}
