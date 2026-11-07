import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';
import 'rapid_fixture.dart';

void main() {
  final game = rapidGame();
  Reduction apply(SessionState s, Command c, {int? now}) => reduce(s, c, game, now: now);
  SessionState play(List<Command> commands, {int now = 1000}) {
    var s = fixtureState();
    for (final command in commands) {
      final result = apply(s, command, now: now);
      expect(result.accepted, isTrue, reason: '${command.toJson()} was rejected');
      s = result.state;
    }
    return s;
  }

  int points(SessionState s, String team) => s.team(team)!.points;

  test('stored and read back, with its media cached', () {
    final question = game.question(buzzerRound)!;
    expect(question.type, QuestionType.rapidFire);
    expect(question.rapidFire!.progress, ProgressStyle.flux);
    expect(question.rapidFire!.items.map((i) => i.answer), ['Paris', 'Rome', 'Madrid']);
    expect(question.maxReveal, 3);
    expect(game.mediaPaths, containsAll(['marseillaise.mp3', 'rome.png']));
    expect(RapidFire.fromMap(question.rapidFire!.toMap()).toMap(), question.rapidFire!.toMap());
    expect(questionAsText(question), contains('2. Italy? – Rome [picture]'));
    expect(questionAsText(game.question(devicesRound)!), contains('2. Bats are birds – wrong'));
  });

  group('teams buzz', () {
    test('opening starts with the first item and plays its sound', () {
      final s = play(const [OpenQuestion(buzzerRound)]);
      expect((s.phase, s.revealed, s.media), (Phase.question, 0, MediaPlayback.playing));
      expect(buzzersOpen(s, game), isTrue);
    });

    test('a right answer scores and moves straight on; a wrong one costs and reopens', () {
      var s = play(const [OpenQuestion(buzzerRound), Buzz('red'), Judge(correct: true)]);
      expect((points(s, 'red'), s.revealed, s.phase), (10, 1, Phase.question));
      expect(s.buzzQueue, isEmpty);
      // The second item has no sound of its own.
      expect(s.media, MediaPlayback.stopped);
      s = run(s, const [Buzz('blue'), Judge(correct: false)], game);
      expect((points(s, 'blue'), s.revealed, s.phase), (-5, 1, Phase.question));
    });

    test('next skips an item nobody knew; after the last one the round is over', () {
      var s = play(const [OpenQuestion(buzzerRound), Reveal(1), Reveal(1)]);
      expect(s.revealed, 2);
      s = run(s, const [Buzz('red'), Judge(correct: true)], game);
      expect((s.revealed, s.phase, points(s, 'red')), (3, Phase.answerRevealed, 10));
      expect(buzzersOpen(s, game), isFalse);
      expect(apply(s, const Buzz('blue')).accepted, isFalse);
      expect(apply(s, const Reveal(1)).accepted, isFalse);
      // Going back is fine here: nothing is scored on the way.
      expect(apply(s, const Reveal(-1)).state.revealed, 2);
    });

    test('players see the item being asked, never its answer', () {
      final s = play(const [OpenQuestion(buzzerRound), Reveal(1)]);
      final view = publicView(s, game);
      final question = view['question'] as Map;
      expect((question['text'], question['itemIndex'], question['itemCount']), ('Italy?', 1, 3));
      expect(view.toString(), isNot(contains('Rome')));
    });
  });

  group('right or wrong on the devices', () {
    test('every item gets a fresh round with the two choices, and no buzzers', () {
      final s = play(const [OpenQuestion(devicesRound)]);
      expect(s.answerRound!.spec.kind, CompanionKind.choice);
      expect(s.answerRound!.spec.options, rapidChoices);
      expect(buzzersOpen(s, game), isFalse);
      expect(apply(s, const Judge(correct: true)).accepted, isFalse);
    });

    test('moving on scores the picks; no pick, no points', () {
      var s = play(const [
        OpenQuestion(devicesRound),
        SubmitAnswer('red', PlayerAnswer(choice: 0)), // "Right": correct
        SubmitAnswer('blue', PlayerAnswer(choice: 1)), // "Wrong": not
        Reveal(1),
      ]);
      expect((points(s, 'red'), points(s, 'blue')), (10, 0));
      expect(s.answerRound!.answers, isEmpty, reason: 'a fresh round for the next item');
      s = run(s, const [SubmitAnswer('blue', PlayerAnswer(choice: 1)), LockAnswer('blue'), Reveal(1)], game);
      expect((points(s, 'red'), points(s, 'blue')), (10, 10));
      expect((s.phase, s.answerRound), (Phase.answerRevealed, null));
    });

    test('there is no going back, so nothing is counted twice', () {
      final s = play(const [OpenQuestion(devicesRound), SubmitAnswer('red', PlayerAnswer(choice: 0)), Reveal(1)]);
      expect(apply(s, const Reveal(-1)).accepted, isFalse);
    });

    test('the statement goes to the devices, whether it is right does not', () {
      final s = play(const [OpenQuestion(devicesRound), Reveal(1)]);
      final view = publicView(s, game, teamId: 'red');
      expect((view['question'] as Map)['text'], 'Bats are birds');
      expect(view.toString(), isNot(contains('true: false')));
      expect(((view['answerRound'] as Map)['spec'] as Map)['options'], rapidChoices);
    });
  });
}
