import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';
import 'top_answers_fixture.dart';

/// Answers on the teams' devices are rated only when the gamemaster taps
/// "Rate automatically": ABCD from the options picked, top answers from the
/// list. Until then the controller shows what it would give (looks right,
/// looks wrong).
void main() {
  const ref = QuestionRef('c2', 'abcd');

  /// The fixture's ABCD question (100 points, 100 off when wrong) picked on
  /// the devices; [correct] says which of a–d are right.
  GameContent abcdGame({
    bool multiple = false,
    List<bool> correct = const [false, true, false, false],
    Map<String, dynamic>? autoRating,
  }) {
    final question = {
      ...fixtureGame().question(ref)!.data,
      'answersCorrect': correct,
      'companion': {'kind': 'choice', if (multiple) 'multiple': true},
      'autoRating': ?autoRating,
    };
    return GameContent.assemble(
      id: 'game',
      game: const {'name': 'Fixture'},
      groups: const {'g1': {'name': 'Round 1', 'categoryGroupType': 'category_wheel', 'categoryGroupIndex': 0}},
      categories: const {'c2': {'name': 'Second', 'categoryGroup': 'g1', 'categoryIndex': 0, 'active': true}},
      questions: {
        'c2': {'abcd': question},
      },
    );
  }

  /// The question open with every option up and [answers] sent in.
  SessionState answered(GameContent game, Map<String, PlayerAnswer> answers) => run(fixtureState(), [
        const OpenQuestion(ref),
        for (var i = 0; i < 4; i++) const Reveal(1),
        for (final MapEntry(key: team, value: answer) in answers.entries) SubmitAnswer(team, answer),
      ], game);

  /// What tapping "Rate automatically" now does.
  SessionState tapAutoRate(SessionState state, GameContent game, QuestionRef ref) =>
      run(state, autoRating(state, state.answerRound!, game.question(ref)!), game);

  group('ABCD', () {
    test('nothing is rated as picks come in, nor when answering closes', () {
      final game = abcdGame();
      var state = answered(game, const {'red': PlayerAnswer(choice: 1), 'blue': PlayerAnswer(choice: 2)});
      expect(state.results.isEmpty, isTrue);
      state = run(state, const [LockAnswers()], game);
      expect(state.results.isEmpty, isTrue);
      expect(canAutoRate(state, state.answerRound!, game.question(ref)!), isTrue);
    });

    test('the button rates the picks as they are, open or closed; points wait for "Give points"', () {
      final game = abcdGame();
      var state = answered(game, const {'red': PlayerAnswer(choice: 1), 'blue': PlayerAnswer(choice: 2)});
      state = tapAutoRate(state, game, ref);
      expect(state.results.verdicts, {'red': true, 'blue': false});
      expect(state.team('red')!.points, 0);
      expect(autoRating(state, state.answerRound!, game.question(ref)!), isEmpty, reason: 'nothing left to change: greyed out');
      state = run(state, const [GivePoints()], game);
      expect(state.team('red')!.points, 100);
      expect(state.team('blue')!.points, -100);
    });

    test('a team that sent nothing is left for the gamemaster', () {
      final game = abcdGame();
      final state = tapAutoRate(answered(game, const {'red': PlayerAnswer(choice: 1)}), game, ref);
      expect(state.results.verdicts, {'red': true});
    });

    test('a changed pick is not followed: tapping again rates it anew', () {
      final game = abcdGame();
      var state = tapAutoRate(answered(game, const {'red': PlayerAnswer(choice: 2)}), game, ref);
      expect(state.results.verdicts['red'], isFalse);
      state = run(state, const [SubmitAnswer('red', PlayerAnswer(choice: 1))], game);
      expect(state.results.verdicts['red'], isFalse);
      state = tapAutoRate(state, game, ref);
      expect(state.results.verdicts['red'], isTrue);
    });

    group('several picks', () {
      const correct = [true, true, false, false];
      const answers = {
        'red': PlayerAnswer(choices: [0, 1]),
        'blue': PlayerAnswer(choices: [0]),
        'green': PlayerAnswer(choices: [0, 2]),
      };

      SessionState closed(MultipleChoiceScoring scoring) {
        final game = abcdGame(multiple: true, correct: correct, autoRating: AutoRating(multiple: scoring).toMap());
        final teams = fixtureState().copyWith(teams: [...fixtureState().teams, const Team(id: 'green', name: 'Green')]);
        var state = run(teams, [
          const OpenQuestion(ref),
          for (var i = 0; i < 4; i++) const Reveal(1),
          for (final MapEntry(key: team, value: answer) in answers.entries) SubmitAnswer(team, answer),
          const LockAnswers(),
        ], game);
        state = tapAutoRate(state, game, ref);
        state = run(state, const [GivePoints()], game);
        return state;
      }

      test('all: right only with exactly the right options', () {
        final state = closed(MultipleChoiceScoring.all);
        expect(state.results.verdicts, {'red': true, 'blue': false, 'green': false});
      });

      test('at least one: right with a right option and no wrong one', () {
        final state = closed(MultipleChoiceScoring.any);
        expect(state.results.verdicts, {'red': true, 'blue': true, 'green': false});
      });

      test('partial: a share for every right option, less for every wrong one', () {
        final state = closed(MultipleChoiceScoring.partial);
        // Both right: all 100. One of two: half. One right, one wrong: nothing.
        expect(state.results.verdicts, {'red': true, 'blue': true, 'green': false});
        expect(state.results.points, {'blue': 50});
        expect({for (final team in state.teams) team.id: team.points}, {'red': 100, 'blue': 50, 'green': -100});
      });

      test('the scores behind it', () {
        const right = [true, true, false, false];
        ({int right, int of})? score(List<int> picks, MultipleChoiceScoring scoring) =>
            multipleChoiceScore(PlayerAnswer(choices: picks), right, scoring);
        expect(score([0, 1], MultipleChoiceScoring.all), (right: 1, of: 1));
        expect(score([0, 1, 2], MultipleChoiceScoring.all), (right: 0, of: 1));
        expect(score([1], MultipleChoiceScoring.any), (right: 1, of: 1));
        expect(score([], MultipleChoiceScoring.any), (right: 0, of: 1));
        expect(score([0, 1, 2], MultipleChoiceScoring.partial), (right: 1, of: 2));
        expect(score([2, 3], MultipleChoiceScoring.partial), (right: 0, of: 2));
        // A single pick, or no right options set: nothing to say.
        expect(multipleChoiceScore(const PlayerAnswer(choice: 1), right, MultipleChoiceScoring.all), isNull);
        expect(multipleChoiceScore(const PlayerAnswer(choices: [1]), const [], MultipleChoiceScoring.all), isNull);
      });
    });
  });

  group('top answers', () {
    test('typed answers are matched with the list only by the button, typos and all', () {
      final game = topAnswersGame(mode: TopAnswersMode.typed);
      var state = run(topTeams, const [
        OpenQuestion(films),
        SubmitAnswer('red', PlayerAnswer(items: ['Titanik', 'lion king', 'Shrek', '', ''])),
        SubmitAnswer('blue', PlayerAnswer(items: ['Frozen', '', '', '', ''])),
        LockAnswers(),
      ], game);
      expect(state.answerRound!.found, isEmpty);
      expect(state.results.isEmpty, isTrue);
      state = tapAutoRate(state, game, films);
      expect(state.answerRound!.found['red'], [0, 2]);
      expect(state.results.points['red'], 400);
      state = run(state, const [GivePoints()], game);
      expect(state.team('red')!.points, 400);
    });
  });

  group('answer lists with right answers', () {
    const spec = CompanionSpec(kind: CompanionKind.list, listRows: 4, solutions: ['Mercury', 'Venus', 'Earth', 'Mars']);

    test('mark the lines that match one, near-misses too, each right answer once', () {
      expect(listMatches(spec, const PlayerAnswer(items: ['venus', 'Merkur', 'Pluto', 'Venus'])), [1, 0, null, null]);
      expect(listMatches(spec, null), isEmpty);
      expect(listMatches(const CompanionSpec(kind: CompanionKind.list), const PlayerAnswer(items: ['Mars'])), isEmpty);
    });

    test('are only a help: nothing is rated by itself', () {
      var state = run(fixtureState(), const [OpenQuestion(estimate), OpenAnswers(spec)]);
      state = run(state, const [SubmitAnswer('red', PlayerAnswer(items: ['Mars', 'Venus', 'Earth', 'Mercury'])), LockAnswers()]);
      expect(state.results.isEmpty, isTrue);
      expect(autoRating(state, state.answerRound!, fixtureGame().question(estimate)!), isEmpty);
    });
  });

  group('stored with the question', () {
    test('the defaults store nothing, so older questions read as before', () {
      expect(const AutoRating().toMap(), isNull);
      expect(AutoRating.fromMap(null), const AutoRating());
      expect(Question.fromMap('q', const {'type': 'abcd'}).autoRating, const AutoRating());
    });

    test('switched off and the way several picks count come back as they were saved', () {
      for (final setting in [
        const AutoRating(on: false),
        const AutoRating(multiple: MultipleChoiceScoring.any),
        const AutoRating(on: false, multiple: MultipleChoiceScoring.partial),
      ]) {
        final stored = setting.toMap();
        expect(AutoRating.fromMap(stored), setting);
        expect(Question.fromMap('q', {'type': 'abcd', 'autoRating': stored}).autoRating, setting);
      }
      expect(const AutoRating(on: false, multiple: MultipleChoiceScoring.partial).toMap(), {'off': true, 'multiple': 'partial'});
      // Something this version does not know reads as the default.
      expect(AutoRating.fromMap(const {'multiple': 'most'}).multiple, MultipleChoiceScoring.all);
    });

    test('an answer list keeps its right answers, and the devices never get them', () {
      const spec = CompanionSpec(kind: CompanionKind.list, listRows: 3, solutions: ['Mercury', 'Venus']);
      final stored = spec.toMap();
      expect(stored['solutions'], ['Mercury', 'Venus']);
      expect(CompanionSpec.fromMap(stored)!.solutions, ['Mercury', 'Venus']);
      expect(CompanionSpec.fromMap(stored)!.withListRows(6).solutions, ['Mercury', 'Venus']);
      expect(spec.toPublicMap('seed').containsKey('solutions'), isFalse);
      // Empty lines are dropped; other screens have none.
      expect(CompanionSpec.fromMap(const {'kind': 'list', 'solutions': ['Mars', ' ']})!.solutions, ['Mars']);
      expect(CompanionSpec.fromMap(const {'kind': 'text', 'solutions': ['Mars']})!.solutions, isEmpty);
    });
  });
}
