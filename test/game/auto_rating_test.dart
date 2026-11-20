import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';
import 'top_answers_fixture.dart';

/// Answers on the teams' devices rated by themselves as soon as they are
/// final: ABCD from the options picked, top answers from the list.
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

  group('ABCD', () {
    test('closing answering rates every pick right or wrong, as if the gamemaster had tapped it', () {
      final game = abcdGame();
      var state = answered(game, const {'red': PlayerAnswer(choice: 1), 'blue': PlayerAnswer(choice: 2)});
      // Still open: nothing is final, nothing rated.
      expect(state.results.verdicts, isEmpty);
      state = run(state, const [LockAnswers()], game);
      expect(state.results.verdicts, {'red': true, 'blue': false});
      // Points as usual: given with "Give points", into the score log.
      state = run(state, const [GivePoints()], game);
      expect(state.team('red')!.points, 100);
      expect(state.team('blue')!.points, -100);
      expect([for (final change in state.scoreLog) change.delta], unorderedEquals([100, -100]));
    });

    test('a team that sent nothing is left for the gamemaster', () {
      final game = abcdGame();
      final state = run(answered(game, const {'red': PlayerAnswer(choice: 1)}), const [LockAnswers()], game);
      expect(state.results.verdicts, {'red': true});
    });

    test('the gamemaster can change a rating, and it stays', () {
      final game = abcdGame();
      var state = run(answered(game, const {'red': PlayerAnswer(choice: 2)}), const [LockAnswers()], game);
      expect(state.results.verdicts['red'], isFalse);
      state = run(state, const [RateAnswer('red', correct: true)], game);
      // Letting them edit again and closing again leaves it as the gamemaster said.
      state = run(state, const [UnlockAnswers(), LockAnswers()], game);
      expect(state.results.verdicts['red'], isTrue);
    });

    test('a team rated before answering closed keeps that rating', () {
      final game = abcdGame();
      final state = run(answered(game, const {'red': PlayerAnswer(choice: 2)}), const [
        RateAnswer('red', correct: true),
        LockAnswers(),
      ], game);
      expect(state.results.verdicts['red'], isTrue);
    });

    test('with the answer already on the big screen its points go up at once', () {
      final game = abcdGame();
      final result = reduce(answered(game, const {'red': PlayerAnswer(choice: 1)}), const RevealAnswer('red', show: true), game);
      // Showing it ends the time to change it: final, rated, given.
      expect(result.state.results.verdicts['red'], isTrue);
      expect(result.state.team('red')!.points, 100);
      expect([for (final effect in result.effects) if (effect is SoundEffect) effect.key], [effectAnswerCorrect]);
    });

    test('switched off in the editor, nothing is rated, but the button still is there', () {
      final game = abcdGame(autoRating: const {'off': true});
      final state = run(answered(game, const {'red': PlayerAnswer(choice: 1)}), const [LockAnswers()], game);
      expect(state.results.verdicts, isEmpty);
      final button = autoRating(state, state.answerRound!, game.question(ref)!);
      expect([for (final command in button) command.toJson()], [const RateAnswer('red', correct: true).toJson()]);
    });

    test('the played round keeps the ratings, and opened again it comes back as it was left', () {
      final game = abcdGame();
      var state = run(answered(game, const {'red': PlayerAnswer(choice: 1), 'blue': PlayerAnswer(choice: 3)}), const [
        LockAnswers(),
        // The gamemaster disagrees with one.
        RateAnswer('blue', correct: true),
      ], game);
      final closed = reduce(state, const CloseQuestion(), game);
      final kept = closed.rounds[ref.key]!;
      expect(kept.results.verdicts, {'red': true, 'blue': true});
      state = reduce(closed.state, const OpenQuestion(ref, restore: true), game, stored: {ref.key: kept}).state;
      expect(state.results.verdicts, {'red': true, 'blue': true});
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
    test('typed answers are matched with the list once answering closes, typos and all', () {
      final game = topAnswersGame(mode: TopAnswersMode.typed);
      var state = run(topTeams, const [
        OpenQuestion(films),
        SubmitAnswer('red', PlayerAnswer(items: ['Titanik', 'lion king', 'Shrek', '', ''])),
        SubmitAnswer('blue', PlayerAnswer(items: ['Frozen', '', '', '', ''])),
        LockAnswers(),
      ], game);
      expect(state.answerRound!.found, {'red': [0, 2], 'blue': <int>[]});
      expect(state.results.points, {'red': 400, 'blue': 0});
      expect(state.results.verdicts, {'red': true, 'blue': false});
      state = run(state, const [GivePoints()], game);
      expect(state.team('red')!.points, 400);
      // The gamemaster ticks one more: the points follow.
      state = run(state, const [MarkTopAnswers('blue', [4])], game);
      expect(state.results.points['blue'], 100);
    });

    test('switched off, the gamemaster ticks them by hand', () {
      final base = topAnswersGame(mode: TopAnswersMode.typed);
      final data = {...base.question(films)!.data, 'autoRating': const AutoRating(on: false).toMap()};
      final game = GameContent.assemble(
        id: 'tg',
        game: const {'name': 'Top answers'},
        groups: const {'g': {'name': 'Round', 'categoryGroupType': 'category_wheel', 'categoryGroupIndex': 0}},
        categories: const {'tc': {'name': 'Films', 'categoryGroup': 'g', 'categoryIndex': 0, 'active': true}},
        questions: {
          'tc': {'films': data},
        },
      );
      final state = run(topTeams, const [
        OpenQuestion(films),
        SubmitAnswer('red', PlayerAnswer(items: ['Titanic', '', '', '', ''])),
        LockAnswers(),
      ], game);
      expect(state.answerRound!.found, isEmpty);
      expect(state.results.isEmpty, isTrue);
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
