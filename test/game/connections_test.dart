import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'connections_fixture.dart';

void main() {
  const teams = [Team(id: 'red', name: 'Red'), Team(id: 'blue', name: 'Blue')];
  const red = Sender(Role.player, teamId: 'red');

  SessionHost host({int? timer, int mistakes = 3, bool lock = true, int Function()? clock}) {
    final h = SessionHost(
      initial: const SessionState(gameId: 'cg', teams: teams),
      game: connectionsGame(timer: timer, mistakes: mistakes, lock: lock),
      clock: clock,
    );
    h.dispatch(const OpenQuestion(puzzle));
    return h;
  }

  ConnectionsProgress? progressOf(SessionHost h, String teamId) => h.state.answerRound!.answers[teamId]?.connections;

  group('the puzzle', () {
    test('a stored question becomes four groups on the teams\' devices', () {
      final q = connectionsGame(timer: 90, mistakes: 4).question(puzzle)!;
      expect(q.type, QuestionType.connections);
      expect(q.buzzerable, isFalse);
      expect(q.defaultJudging, isFalse);
      expect(q.maxReveal, 4);
      final spec = q.companion!;
      expect(spec.kind, CompanionKind.connections);
      expect((spec.timerSeconds, spec.mistakes, spec.lockable), (90, 4, true));
      expect(spec.groups.map((g) => g.name), ['Fruit', 'Planets', 'Card games', '___ Pie']);
      expect(spec.groups.every((g) => g.isComplete), isTrue);
      // The spec survives the session state's JSON.
      final copy = CompanionSpec.fromMap(jsonDecode(jsonEncode(spec.toMap())))!;
      expect(copy.groups[3].words, ['Cherry', 'Humble', 'Shepherd', 'Pork']);
    });

    test('the shown order is the same every time, mixes all words and keeps no group in a row', () {
      final order = connectionsOrder('cx/puzzle');
      expect(order, connectionsOrder('cx/puzzle'));
      expect(order.toSet(), Set.of(List.generate(16, (i) => i)));
      expect(connectionsOrder('cx/other'), isNot(order));
      for (final seed in ['a', 'b', 'c', 'cx/puzzle', 'round 7']) {
        final o = connectionsOrder(seed);
        for (var row = 0; row < 4; row++) {
          expect({for (var c = 0; c < 4; c++) o[row * 4 + c] ~/ 4}.length, greaterThan(1), reason: seed);
        }
      }
    });

    test('devices get the words in the shown order and nothing about the groups', () {
      final h = host();
      final view = h.publicStateFor('blue');
      final text = jsonEncode(view);
      for (final secret in ['Fruit', 'Planets', 'Card games', '___ Pie']) {
        expect(text, isNot(contains(secret)));
      }
      final shown = PublicView(view).connectionWords;
      final order = connectionsOrder('cx/puzzle');
      final spec = h.game!.question(puzzle)!.companion!;
      expect(shown, [for (final i in order) spec.wordAt(i)]);
    });
  });

  group('guessing', () {
    test('a right guess finds the group; the device sees it with its name', () {
      final h = host();
      expect(h.dispatch(GuessConnection('red', placesOf(2)), sender: red), isTrue);
      expect(progressOf(h, 'red')!.solved, [2]);
      final own = PublicView(h.publicStateFor('red')).ownConnections!;
      expect(own.solved.single.name, 'Card games');
      expect(own.solved.single.positions..sort(), placesOf(2)..sort());
      expect(own.mistakes, 0);
    });

    test('a wrong guess costs a try; three of four is "one away"', () {
      final h = host();
      final oneAway = [...placesOf(0).take(3), placesOf(1).first];
      final wayOff = [placesOf(0)[0], placesOf(1)[0], placesOf(2)[0], placesOf(3)[0]];
      h.dispatch(GuessConnection('red', oneAway), sender: red);
      h.dispatch(GuessConnection('red', wayOff), sender: red);
      final p = progressOf(h, 'red')!;
      expect(p.mistakes, 2);
      expect(p.oneAway, [true, false]);
      final own = PublicView(h.publicStateFor('red')).ownConnections!;
      expect(own.oneAway, [true, false]);
      expect(own.wrong.first..sort(), [...oneAway]..sort());
    });

    test('the same wrong guess again, in any order, is not counted', () {
      final h = host();
      final guess = [placesOf(0)[0], placesOf(1)[0], placesOf(2)[0], placesOf(3)[0]];
      h.dispatch(GuessConnection('red', guess), sender: red);
      expect(h.dispatch(GuessConnection('red', guess.reversed.toList()), sender: red), isFalse);
      expect(progressOf(h, 'red')!.mistakes, 1);
    });

    test('nonsense is refused: too few, twice the same, out of range, words already found', () {
      final h = host();
      final p = placesOf(0);
      expect(h.dispatch(GuessConnection('red', p.take(3).toList()), sender: red), isFalse);
      expect(h.dispatch(GuessConnection('red', [p[0], p[0], p[1], p[2]]), sender: red), isFalse);
      expect(h.dispatch(GuessConnection('red', [p[0], p[1], p[2], 16]), sender: red), isFalse);
      h.dispatch(GuessConnection('red', p), sender: red);
      expect(h.dispatch(GuessConnection('red', p), sender: red), isFalse);
      expect(progressOf(h, 'red')!.mistakes, 0);
    });

    test('a team only guesses for itself', () {
      final h = host();
      expect(h.dispatch(GuessConnection('blue', placesOf(0)), sender: red), isFalse);
      expect(h.state.answerRound!.answers, isEmpty);
    });

    test('out of tries: the team is done, locked in, with its time', () {
      var now = 10000;
      final h = host(mistakes: 2, clock: () => now);
      final wrong1 = [placesOf(0)[0], placesOf(1)[0], placesOf(2)[0], placesOf(3)[0]];
      final wrong2 = [placesOf(0)[1], placesOf(1)[1], placesOf(2)[1], placesOf(3)[1]];
      now += 4000;
      h.dispatch(GuessConnection('red', wrong1), sender: red);
      now += 3500;
      h.dispatch(GuessConnection('red', wrong2), sender: red);
      final answer = h.state.answerRound!.answers['red']!;
      expect(answer.locked, isTrue);
      expect(answer.secondsTaken(h.state.answerRound!), 7.5);
      expect(PublicView(h.publicStateFor('red')).ownConnections!.finished, isTrue);
      expect(h.dispatch(GuessConnection('red', placesOf(0)), sender: red), isFalse);
      expect(h.state.answerRound!.open, isTrue, reason: 'blue is still playing');
    });

    test('everyone done closes the round', () {
      final h = host();
      for (var level = 0; level < 4; level++) {
        h.dispatch(GuessConnection('red', placesOf(level)), sender: red);
      }
      expect(h.state.answerRound!.answers['red']!.locked, isTrue);
      h.dispatch(const LockAnswer('blue'), sender: const Sender(Role.player, teamId: 'blue'));
      expect(h.state.answerRound!.open, isFalse);
    });
  });

  group('what others see', () {
    test('another team sees how far red got, never which words', () {
      final h = host();
      h.dispatch(GuessConnection('red', placesOf(3)), sender: red);
      h.dispatch(GuessConnection('red', [placesOf(0)[0], placesOf(1)[0], placesOf(2)[0], placesOf(2)[1]]), sender: red);
      final blue = PublicView(h.publicStateFor('blue'));
      expect(blue.ownConnections, isNull);
      expect(blue.progressOf('red')!.solved, [3]);
      expect(blue.progressOf('red')!.mistakes, 1);
      final text = jsonEncode(h.publicStateFor('blue'));
      expect(text, isNot(contains('___ Pie')));
      // The shared view, as written for everyone, has no team's own part.
      expect(jsonEncode(h.publicState), isNot(contains('"own"')));
    });

    test('a revealed team answer shows counts only', () {
      final h = host();
      h.dispatch(GuessConnection('red', placesOf(1)), sender: red);
      h.dispatch(const RevealAnswer('red'));
      final text = jsonEncode(h.publicStateFor('blue'));
      expect(text, isNot(contains('wrong')));
      expect(text, isNot(contains('Planets')));
    });
  });

  group('revealing and points', () {
    test('groups come up on the big screen easiest first, and end the teams\' time', () {
      final h = host(timer: 60);
      expect(h.state.answerRound!.endsAtMillis, isNotNull);
      h.dispatch(const Reveal(1));
      expect(h.state.answerRound!.open, isFalse);
      expect(h.state.answerRound!.endsAtMillis, isNull);
      final shown = PublicView(h.publicStateFor('blue')).revealedGroups;
      expect(shown.single.name, 'Fruit');
      expect(shown.single.positions..sort(), placesOf(0)..sort());
      h.dispatch(const Reveal(3));
      expect(PublicView(h.publicState).revealedGroups.map((g) => g.name), ['Fruit', 'Planets', 'Card games', '___ Pie']);
      expect(h.dispatch(const Reveal(1)), isFalse);
    });

    test('each team gets a quarter of the points per group, once', () {
      final h = host();
      h.dispatch(GuessConnection('red', placesOf(0)), sender: red);
      h.dispatch(GuessConnection('red', placesOf(3)), sender: red);
      h.dispatch(GuessConnection('red', placesOf(1)), sender: red);
      h.dispatch(GuessConnection('blue', placesOf(2)), sender: const Sender(Role.player, teamId: 'blue'));
      h.dispatch(const LockAnswers());
      expect(h.dispatch(const AwardConnections()), isTrue);
      expect(h.state.team('red')!.points, 300);
      expect(h.state.team('blue')!.points, 100);
      expect(h.dispatch(const AwardConnections()), isFalse, reason: 'nothing changed');
      expect(h.state.team('red')!.points, 300);
      expect(h.dispatch(const AwardConnections(), sender: red), isFalse);
    });

    test('a connections round cannot be answered with an ordinary answer', () {
      final h = host();
      expect(h.dispatch(const SubmitAnswer('red', PlayerAnswer(text: 'x')), sender: red), isFalse);
      expect(
        h.dispatch(const SubmitAnswer('red', PlayerAnswer(connections: ConnectionsProgress(solved: [0, 1, 2, 3]))), sender: red),
        isFalse,
      );
    });
  });

  group('locking in, for every companion screen', () {
    test('the time of locking in is kept, and cleared when unlocked', () {
      var now = 50000;
      final h = SessionHost(initial: const SessionState(gameId: 'cg', teams: teams), game: connectionsGame(), clock: () => now);
      h.dispatch(const OpenQuestion(puzzle));
      h.dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.text, timerSeconds: 30)));
      h.dispatch(const SubmitAnswer('red', PlayerAnswer(text: 'Paris')), sender: red);
      now += 12300;
      h.dispatch(const LockAnswer('red'), sender: red);
      final round = h.state.answerRound!;
      expect(round.answers['red']!.secondsTaken(round), closeTo(12.3, 1e-9));
      expect(PublicView(h.publicStateFor('red')).ownLockedAt, 62300);
      // Survives the session state's JSON.
      final copy = SessionState.fromJson(jsonDecode(jsonEncode(h.state.toJson())) as Map<String, dynamic>);
      expect(copy.answerRound!.answers['red']!.lockedAtMillis, 62300);
      h.dispatch(const UnlockAnswers());
      expect(h.state.answerRound!.answers['red']!.lockedAtMillis, isNull);
      h.dispatch(const LockAnswers());
    });

    test('where locking in is switched off, teams cannot', () {
      final h = host(lock: false);
      expect(PublicView(h.publicStateFor('red')).lockable, isFalse);
      expect(h.dispatch(const LockAnswer('red'), sender: red), isFalse);
      expect(h.dispatch(const LockAnswer('red')), isFalse);
    });
  });

  test('every view says which app version it needs', () {
    final h = host();
    expect(PublicView(h.publicState).minAppVersion, kMinCompanionVersion);
  });

  test('the commands survive JSON', () {
    for (final command in [const GuessConnection('red', [1, 5, 9, 12]), const AwardConnections()]) {
      final copy = Command.fromJson(jsonDecode(jsonEncode(command.toJson())) as Map<String, dynamic>)!;
      expect(copy.toJson(), command.toJson());
    }
    expect(mayIssue(red, const GuessConnection('red', [0, 1, 2, 3])), isTrue);
    expect(mayIssue(red, const GuessConnection('blue', [0, 1, 2, 3])), isFalse);
  });
}
