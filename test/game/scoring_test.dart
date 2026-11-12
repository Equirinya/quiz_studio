import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';
import 'rapid_fixture.dart';
import 'scoring_fixture.dart';
import 'top_answers_fixture.dart';

SessionState play(List<Command> commands, {SessionState? from, int? now}) {
  var state = from ?? scoringState();
  for (final command in commands) {
    final result = reduce(state, command, scoringGame(), now: now);
    if (!result.accepted) throw StateError('rejected: ${command.toJson()}');
    state = result.state;
  }
  return state;
}

void main() {
  group('by order', () {
    test('right answers rank by when they locked in: first the points, each after 100 less', () {
      var s = play(const [OpenQuestion(raced)], now: 0);
      s = play(const [SubmitAnswer('blue', PlayerAnswer(text: 'Metropolis')), LockAnswer('blue')], from: s, now: 4000);
      s = play(const [SubmitAnswer('red', PlayerAnswer(text: 'Metropolis')), LockAnswer('red')], from: s, now: 9000);
      s = play(const [SubmitAnswer('green', PlayerAnswer(text: 'Nosferatu')), LockAnswer('green')], from: s, now: 12000);
      // Rated in team order; the order still follows the lock-in times.
      s = play(const [RateAnswer('red', correct: true), RateAnswer('blue', correct: true), RateAnswer('green', correct: false)], from: s);
      expect(rightInOrder(s), ['blue', 'red']);
      final question = scoringGame().question(raced)!;
      expect({for (final team in s.teams) team.id: pointsDue(s, question, team.id)}, {'red': 500, 'blue': 600, 'green': -50});
      s = play(const [GivePoints()], from: s);
      expect([for (final team in s.teams) team.points], [500, 600, -50]);
    });

    test('the gamemaster can put teams in order by hand, e.g. as they finish on stage', () {
      var s = play(const [OpenQuestion(mime), PlaceTeam('green'), PlaceTeam('red')]);
      expect(rightInOrder(s), ['green', 'red']);
      s = play(const [GivePoints()], from: s);
      expect([for (final team in s.teams) team.points], [200, 0, 300]);
      // Taking a team out moves the ones after it up; giving again only gives the difference.
      s = play(const [PlaceTeam('green'), GivePoints()], from: s);
      expect([for (final team in s.teams) team.points], [300, 0, 0]);
    });

    test('putting in order only fits "by order" questions', () {
      final s = play(const [OpenQuestion(free)]);
      expect(reduce(s, const PlaceTeam('red'), scoringGame()).accepted, isFalse);
    });

    test('never below zero', () {
      final question = scoringGame().question(mime)!;
      expect([for (var place = 0; place < 5; place++) placePoints(question, place)], [300, 200, 100, 0, 0]);
    });
  });

  group('giving points', () {
    test('ratings count even when the question closes before "Give points"', () {
      var s = play(const [OpenQuestion(mime), PlaceTeam('blue')]);
      s = play(const [CloseQuestion()], from: s);
      expect(s.team('blue')!.points, 300);
      expect(s.results.isEmpty, isTrue);
    });

    test('a question that is put away unplayed gives nothing', () {
      var s = play(const [OpenQuestion(mime), PlaceTeam('blue')]);
      s = play(const [CloseQuestion(markPlayed: false)], from: s);
      expect(s.team('blue')!.points, 0);
    });

    test('a corrected rating only moves the score by the difference', () {
      var s = play(const [OpenQuestion(raced), RateAnswer('red', correct: true), GivePoints()]);
      expect(s.team('red')!.points, 600);
      s = play(const [RateAnswer('red', correct: false), GivePoints()], from: s);
      expect(s.team('red')!.points, -50);
      s = play(const [AwardAnswer('red', 300), GivePoints()], from: s);
      expect(s.team('red')!.points, 300);
    });
  });

  group('the score log', () {
    test('every change to a score is logged, whatever caused it', () {
      var s = play(const [OpenQuestion(raced), RateAnswer('red', correct: true), RateAnswer('blue', correct: false), GivePoints()]);
      expect([for (final change in s.scoreLog) (change.id, change.teamId, change.delta)], [(1, 'red', 600), (2, 'blue', -50)]);
      s = play(const [AdjustPoints('green', 25)], from: s);
      expect(s.scoreLog.last.delta, 25);
      expect(s.scoreLog.last.id, 3);
    });

    test('buzzer verdicts are logged too', () {
      var s = play(const [OpenQuestion(free), Buzz('red'), Judge(correct: false)]);
      expect(s.scoreLog.single.delta, -50);
      s = play(const [Buzz('blue'), Judge(correct: true)], from: s);
      expect((s.scoreLog.last.teamId, s.scoreLog.last.delta), ('blue', 100));
    });

    test('it keeps only the latest changes, and travels to the devices', () {
      var s = scoringState();
      for (var i = 0; i < kScoreLogLength + 5; i++) {
        s = play([AdjustPoints('red', i + 1)], from: s);
      }
      expect(s.scoreLog, hasLength(kScoreLogLength));
      expect(s.scoreLog.last.id, kScoreLogLength + 5);
      final restored = SessionState.fromJson(s.toJson());
      expect(restored.scoreLog.last.delta, kScoreLogLength + 5);
      expect(PublicView(publicView(s, scoringGame())).scoreLog.last.id, kScoreLogLength + 5);
    });
  });

  test('results survive storage', () {
    final s = play(const [OpenQuestion(mime), PlaceTeam('green'), RateAnswer('red', correct: false), AwardAnswer('blue', 150)]);
    final restored = SessionState.fromJson(s.toJson()).results;
    expect(restored.order, ['green']);
    expect(restored.verdicts, {'red': false, 'blue': true});
    expect(restored.points, {'blue': 150});
  });

  group('on the boards', () {
    test('points given per item show everything there is to win', () {
      // Fragenhagel: 10 per item, three items.
      expect(rapidGame().question(buzzerRound)!.boardPoints, 30);
      // Top answers: 100 each, one worth 300 of its own.
      expect(topAnswersGame().question(const QuestionRef('tc', 'films'))!.boardPoints, 700);
      // Everything else: its points.
      expect(scoringGame().question(raced)!.boardPoints, 600);
    });

    test('and questions sort by it', () {
      final questions = [
        Question.fromMap('a', const {'type': 'free', 'pointsPlus': 200}),
        Question.fromMap('b', const {
          'type': 'rapidFire',
          'pointsPlus': 20,
          'rapidFire': {
            'items': [
              {'question': '1'},
              {'question': '2'},
              {'question': '3'},
              {'question': '4'},
              {'question': '5'},
              {'question': '6'},
              {'question': '7'},
              {'question': '8'},
              {'question': '9'},
              {'question': '10'},
              {'question': '11'},
              {'question': '12'},
            ],
          },
        }),
        Question.fromMap('c', const {'type': 'free', 'pointsPlus': 300}),
      ];
      sortQuestions(questions);
      expect([for (final q in questions) q.id], ['a', 'b', 'c'], reason: '12 × 20 = 240 sits between 200 and 300');
    });
  });
}
