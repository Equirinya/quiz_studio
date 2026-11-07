import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'top_answers_fixture.dart';

SessionState play(GameContent game, List<Command> commands, [SessionState state = topTeams]) {
  for (final command in commands) {
    final result = reduce(state, command, game);
    if (!result.accepted) throw StateError('rejected: ${command.toJson()} in phase ${state.phase.name}');
    state = result.state;
  }
  return state;
}

int points(SessionState state, String teamId) => state.team(teamId)!.points;

void main() {
  group('the question', () {
    test('reads its list and mode, and says how it is played', () {
      final buzzer = topAnswersGame().question(films)!;
      expect(buzzer.type, QuestionType.topAnswers);
      expect(buzzer.topAnswers!.items, hasLength(5));
      expect(buzzer.topAnswers!.pointsOf(2, buzzer.pointsPlus), 300);
      expect(buzzer.topAnswers!.pointsOf(0, buzzer.pointsPlus), 100);
      expect(buzzer.buzzerable, isTrue);
      expect(buzzer.companion, isNull);
      expect(buzzer.needsDevices, isFalse);

      final typed = topAnswersGame(mode: TopAnswersMode.typed, timer: 60).question(films)!;
      expect(typed.buzzerable, isFalse);
      expect(typed.needsDevices, isTrue);
      expect(typed.companion!.kind, CompanionKind.list);
      expect(typed.companion!.listRows, 5);
      expect(typed.companion!.timerSeconds, 60);

      final board = topAnswersGame(mode: TopAnswersMode.whiteboard).question(films)!.companion!;
      expect(board.kind, CompanionKind.whiteboard);
      expect(board.background, 'list');
      expect(board.listRows, 5);
    });

    test('the duel keeps its stored name but is shown as the survey duel', () {
      expect(QuestionType.fromString('feud'), QuestionType.feud);
      expect(QuestionType.feud.uiString, 'Survey duel');
      expect(QuestionType.topAnswers.uiString, 'Top answers');
    });
  });

  group('suggestions for typed answers', () {
    const top = TopAnswers(
      items: [
        TopAnswer(answer: 'Titanic'),
        TopAnswer(answer: 'Avatar'),
        TopAnswer(answer: 'The Lion King / Lion King'),
        TopAnswer(answer: 'Star Wars'),
      ],
    );

    test('match small typing slips, case, articles and alternatives', () {
      expect(top.suggest(['titanik', 'AVATAR', 'lion king', 'starwars']), [0, 1, 2, 3]);
      expect(top.suggest(['Der König der Löwen']), [null]);
      expect(top.suggest(['Titanic (1997)']), [0]);
    });

    test('count an answer once, and leave empty or unknown lines alone', () {
      expect(top.suggest(['Titanic', 'titanic', '', 'Frozen']), [0, null, null, null]);
    });

    test('do not stretch short words too far', () {
      expect(top.suggest(['Up']), [null]);
      expect(normalizeAnswer('  The Lion-King! '), 'lionking');
    });
  });

  group('with buzzers', () {
    test('tapping the answer the team named uncovers it and gives it its points', () {
      final game = topAnswersGame();
      var s = play(game, const [OpenQuestion(films), Buzz('red'), TopAnswerToggle(2)]);
      expect(s.feudRevealed, [2]);
      expect(s.foundBy, {2: 'red'});
      expect(points(s, 'red'), 300);
      // Everyone may buzz again.
      expect(s.phase, Phase.question);
      expect(s.buzzQueue, isEmpty);

      s = play(game, const [Buzz('blue'), Judge(correct: false)], s);
      expect(points(s, 'blue'), -50);
      s = play(game, const [Buzz('blue'), TopAnswerToggle(0)], s);
      expect(points(s, 'blue'), 50);
      expect(s.foundBy, {2: 'red', 0: 'blue'});
    });

    test('Right alone does nothing: the answer has to be picked', () {
      final s = play(topAnswersGame(), const [OpenQuestion(films), Buzz('red')]);
      expect(reduce(s, const Judge(correct: true), topAnswersGame()).accepted, isFalse);
    });

    test('covering an answer again takes its points back', () {
      final game = topAnswersGame();
      final s = play(game, const [OpenQuestion(films), Buzz('red'), TopAnswerToggle(1), TopAnswerToggle(1)]);
      expect(s.feudRevealed, isEmpty);
      expect(s.foundBy, isEmpty);
      expect(points(s, 'red'), 0);
    });

    test('without a team answering, an answer is just uncovered, and the last one ends the round', () {
      final game = topAnswersGame();
      var s = play(game, const [OpenQuestion(films), TopAnswerToggle(4)]);
      expect(s.feudRevealed, [4]);
      expect(points(s, 'red') + points(s, 'blue'), 0);
      s = play(game, const [TopAnswerToggle(0), TopAnswerToggle(1), TopAnswerToggle(2), TopAnswerToggle(3)], s);
      expect(s.phase, Phase.answerRevealed);
    });

    test('closing the question forgets who found what', () {
      final game = topAnswersGame();
      final s = play(game, const [OpenQuestion(films), Buzz('red'), TopAnswerToggle(2), CloseQuestion()]);
      expect(s.foundBy, isEmpty);
      expect(s.feudRevealed, isEmpty);
    });

    test('survives a trip through JSON', () {
      final s = play(topAnswersGame(), const [OpenQuestion(films), Buzz('red'), TopAnswerToggle(2)]);
      final back = SessionState.fromJson(s.toJson());
      expect(back.foundBy, {2: 'red'});
    });
  });

  group('on the devices', () {
    test('a typed list goes in, the gamemaster ticks what was found, points follow', () {
      final game = topAnswersGame(mode: TopAnswersMode.typed);
      var s = play(game, const [
        OpenQuestion(films),
        SubmitAnswer('red', PlayerAnswer(items: ['titanic', 'lion king', 'Frozen', '', ''])),
      ]);
      expect(s.answerRound!.kind, CompanionKind.list);
      expect(s.answerRound!.answers['red']!.items, ['titanic', 'lion king', 'Frozen', '', '']);

      s = play(game, const [
        MarkTopAnswers('red', [0, 2]),
      ], s);
      expect(points(s, 'red'), 400);
      expect(s.answerRound!.found['red'], [0, 2]);
      expect(s.answerRound!.verdicts['red'], isTrue);

      // Changing the ticks never counts twice.
      s = play(game, const [
        MarkTopAnswers('red', [0]),
      ], s);
      expect(points(s, 'red'), 100);
      s = play(game, const [MarkTopAnswers('red', [])], s);
      expect(points(s, 'red'), 0);
      expect(s.answerRound!.verdicts['red'], isFalse);
    });

    test('rating automatically ticks what the typed lines match', () {
      final game = topAnswersGame(mode: TopAnswersMode.typed);
      final s = play(game, const [
        OpenQuestion(films),
        SubmitAnswer('red', PlayerAnswer(items: ['Avatar', 'Star wars', 'x', '', ''])),
        SubmitAnswer('blue', PlayerAnswer(items: ['jurasic park', '', '', '', ''])),
        LockAnswers(),
      ]);
      final commands = autoRating(s, s.answerRound!, game.question(films)!);
      final rated = play(game, commands, s);
      expect(rated.answerRound!.found, {
        'red': [1, 3],
        'blue': [4],
      });
      expect(points(rated, 'red'), 200);
      expect(points(rated, 'blue'), 100);
    });

    test('a device can only send a list to a list round', () {
      expect(const PlayerAnswer(items: ['a']).matches(CompanionKind.list), isTrue);
      expect(const PlayerAnswer(text: 'a').matches(CompanionKind.list), isFalse);
      expect(const PlayerAnswer(items: ['', ' ']).isEmpty, isTrue);
      final back = PlayerAnswer.fromJson(const PlayerAnswer(items: ['a', '']).toJson());
      expect(back.items, ['a', '']);
    });

    test('ticks survive a trip through JSON, and a removed team takes its ticks along', () {
      final game = topAnswersGame(mode: TopAnswersMode.whiteboard);
      final s = play(game, const [
        OpenQuestion(films),
        MarkTopAnswers('blue', [1, 4]),
      ]);
      expect(AnswerRound.fromJson(s.answerRound!.toJson()).found, {
        'blue': [1, 4],
      });
      final removed = play(game, const [RemoveTeam('blue')], s);
      expect(removed.answerRound!.found, isEmpty);
    });

    test('uncovering on the big screen never gives points by itself', () {
      final game = topAnswersGame(mode: TopAnswersMode.typed);
      final s = play(game, const [OpenQuestion(films), TopAnswerToggle(0), TopAnswerToggle(1)]);
      expect(s.feudRevealed, [0, 1]);
      expect(s.foundBy, isEmpty);
      expect(points(s, 'red') + points(s, 'blue'), 0);
    });
  });

  test('players never see an answer that is still covered', () {
    final game = topAnswersGame();
    final s = play(game, const [OpenQuestion(films), Buzz('red'), TopAnswerToggle(2)]);
    final view = publicView(s, game);
    final question = view['question'] as Map;
    expect(question['informationCount'], 5);
    expect(question['information'], {'2': 'The Lion King / Lion King'});
  });
}
