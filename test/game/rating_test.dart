import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';

SessionState withRound(CompanionSpec spec, Map<String, PlayerAnswer> answers) {
  var state = run(fixtureState(), const [OpenQuestion(estimate)]);
  state = reduce(state, OpenAnswers(spec), fixtureGame()).state;
  for (final entry in answers.entries) {
    state = reduce(state, SubmitAnswer(entry.key, entry.value), fixtureGame()).state;
  }
  return reduce(state, const LockAnswers(), fixtureGame()).state;
}

SessionState rated(SessionState state, List<Command> commands) {
  for (final command in commands) {
    state = reduce(state, command, fixtureGame()).state;
  }
  return state;
}

void main() {
  // The estimate question is worth 200.
  final question = fixtureGame().question(estimate)!;

  group('partial points', () {
    const order = CompanionSpec(kind: CompanionKind.order, options: ['a', 'b', 'c', 'd']);
    const match = CompanionSpec(kind: CompanionKind.match, options: ['a', 'b', 'c', 'd'], targets: ['1', '2', '3', '4']);

    test('count the items in the right place', () {
      expect(partialScore(order, const PlayerAnswer(order: [0, 1, 3, 2])), (right: 2, of: 4));
      expect(partialScore(match, const PlayerAnswer(pairs: [0, 1, 2, -1])), (right: 3, of: 4));
      expect(partialScore(match, null), isNull);
      expect(partialScore(const CompanionSpec(kind: CompanionKind.text), const PlayerAnswer(text: 'x')), isNull);
      expect(partialPoints((right: 3, of: 4), 200), 150);
    });

    test('rating automatically gives a share, everything, or rates wrong', () {
      final state = withRound(match, const {
        'red': PlayerAnswer(pairs: [0, 1, 2, -1]),
        'blue': PlayerAnswer(pairs: [0, 1, 2, 3]),
      });
      final after = rated(state, autoRating(state, state.answerRound!, question));
      expect(after.answerRound!.awarded, {'red': 150, 'blue': 200});
      expect(after.answerRound!.verdicts, {'red': true, 'blue': true});

      final none = withRound(order, const {
        'red': PlayerAnswer(order: [1, 0, 3, 2]),
      });
      final wrong = rated(none, autoRating(none, none.answerRound!, question));
      expect(wrong.answerRound!.verdicts['red'], isFalse);
    });
  });

  group('estimates', () {
    const spec = CompanionSpec(kind: CompanionKind.number, solution: 100);
    final answers = {
      'red': const PlayerAnswer(number: 90),
      'blue': const PlayerAnswer(number: 130),
      'green': const PlayerAnswer(number: 70),
      'yellow': const PlayerAnswer(number: 200),
    };

    test('closest wins', () {
      expect(estimatePoints(spec, answers, 200, EstimateScoring.closest), {'red': 200, 'blue': 0, 'green': 0, 'yellow': 0});
    });

    test('1st, 2nd and 3rd place get all, half and a quarter; equally close share a place', () {
      expect(estimatePoints(spec, answers, 200, EstimateScoring.podium), {'red': 200, 'blue': 100, 'green': 100, 'yellow': 50});
    });

    test('by distance: the closest all, the furthest nothing, the rest in proportion', () {
      // Off by 10, 30, 30 and 100.
      expect(estimatePoints(spec, answers, 200, EstimateScoring.distance), {'red': 200, 'blue': 156, 'green': 156, 'yellow': 0});
      expect(
        estimatePoints(spec, {'red': const PlayerAnswer(number: 5), 'blue': const PlayerAnswer(number: 5)}, 200, EstimateScoring.distance),
        {'red': 200, 'blue': 200},
      );
    });

    test('nothing without a solution, and teams without a number are left out', () {
      expect(estimatePoints(const CompanionSpec(kind: CompanionKind.number), answers, 200, EstimateScoring.podium), isEmpty);
      expect(estimatePoints(spec, {'red': const PlayerAnswer(text: 'x')}, 200, EstimateScoring.closest), isEmpty);
    });

    test('the scoring buttons rate the round without taking points away', () {
      final state = withRound(spec, const {'red': PlayerAnswer(number: 90), 'blue': PlayerAnswer(number: 130)});
      final after = rated(state, estimateRating(state.answerRound!, question, EstimateScoring.distance));
      expect(after.answerRound!.awarded, {'red': 200, 'blue': 0});
      expect(after.team('blue')!.points, 0);
    });

    test('a range around the solution still counts as right', () {
      const near = CompanionSpec(kind: CompanionKind.number, solution: 100, tolerance: 5);
      expect(autoVerdict(near, const PlayerAnswer(number: 104)), isTrue);
      expect(autoVerdict(near, const PlayerAnswer(number: 106)), isFalse);
      expect(autoVerdict(spec, const PlayerAnswer(number: 101)), isFalse);
      expect(CompanionSpec.fromMap(near.toMap())!.tolerance, 5);
      expect(CompanionSpec.fromMap({'kind': 'number', 'tolerance': 0})!.tolerance, isNull);
    });
  });

  test('rate automatically only offers what is final and would change something', () {
    const pick = CompanionSpec(kind: CompanionKind.order, options: ['a', 'b']);
    var state = run(fixtureState(), const [OpenQuestion(estimate)]);
    state = reduce(state, const OpenAnswers(pick), fixtureGame()).state;
    state = reduce(state, const SubmitAnswer('red', PlayerAnswer(order: [0, 1])), fixtureGame()).state;
    // Still being changed: nothing to rate yet.
    expect(autoRating(state, state.answerRound!, question), isEmpty);
    state = reduce(state, const LockAnswer('red'), fixtureGame()).state;
    final commands = autoRating(state, state.answerRound!, question);
    expect(commands, hasLength(1));
    state = rated(state, commands);
    // Done: the button has nothing left to do.
    expect(autoRating(state, state.answerRound!, question), isEmpty);
  });

  test('half points replace what a team had', () {
    final state = withRound(const CompanionSpec(kind: CompanionKind.text), const {'red': PlayerAnswer(text: 'Paris-ish')});
    final after = rated(state, const [RateAnswer('red', correct: true), AwardAnswer('red', 100)]);
    expect(after.team('red')!.points, 100);
  });
}
