import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';

void main() {
  final game = fixtureGame();
  Reduction apply(SessionState s, Command c) => reduce(s, c, game);

  group('board', () {
    test('opening a question selects its group and starts clean', () {
      final s = run(fixtureState(), [const OpenQuestion(feud)]);
      expect(s.phase, Phase.question);
      expect(s.current, feud);
      expect(s.groupId, 'g2');
      expect(s.played, isEmpty);
    });

    test('opening another question marks the previous one played', () {
      final s = run(fixtureState(), [const OpenQuestion(free), const Buzz('red'), const OpenQuestion(abcd)]);
      expect(s.played, {free.key});
      expect(s.phase, Phase.question);
      expect(s.buzzQueue, isEmpty);
    });

    test('closing marks played and plays the closed effect; cancelling does neither', () {
      final open = run(fixtureState(), [const OpenQuestion(free)]);
      final closed = apply(open, const CloseQuestion());
      expect(closed.state.phase, Phase.overview);
      expect(closed.state.current, isNull);
      expect(closed.state.played, {free.key});
      expect(closed.effects.single, isA<SoundEffect>().having((e) => e.key, 'key', effectAnswerClosed));

      final cancelled = apply(open, const CloseQuestion(markPlayed: false));
      expect(cancelled.state.played, isEmpty);
      expect(cancelled.effects, isEmpty);

      final again = run(closed.state, [const UnmarkPlayed(free)]);
      expect(again.played, isEmpty);
    });

    test('rejects unknown questions, group changes mid-question and unknown groups', () {
      expect(apply(fixtureState(), const OpenQuestion(QuestionRef('c1', 'nope'))).accepted, isFalse);
      expect(apply(fixtureState(), const SelectGroup('nope')).accepted, isFalse);
      expect(apply(fixtureState(), const SelectGroup('g2')).state.groupId, 'g2');
      final open = run(fixtureState(), [const OpenQuestion(free)]);
      expect(apply(open, const SelectGroup('g2')).accepted, isFalse);
      expect(apply(fixtureState(), const CloseQuestion()).accepted, isFalse);
    });

    test('a rejected command leaves the state and its seq untouched', () {
      final s = fixtureState();
      final result = apply(s, const Judge(correct: true));
      expect(result.accepted, isFalse);
      expect(identical(result.state, s), isTrue);
      expect(apply(s, const OpenQuestion(free)).state.seq, s.seq + 1);
    });

    test('loading another game resets the board but keeps teams and points', () {
      var s = run(fixtureState(), [const AdjustPoints('red', 100), const OpenQuestion(free), const CloseQuestion()]);
      s = run(s, [const SetGame('other')]);
      expect(s.gameId, 'other');
      expect(s.played, isEmpty);
      expect(s.groupId, isNull);
      expect(points(s, 'red'), 100);
    });
  });

  group('buzzing', () {
    test('first buzz wins; later ones are dropped without a queue', () {
      final open = run(fixtureState(), [const OpenQuestion(free)]);
      final first = apply(open, const Buzz('red'));
      expect(first.state.phase, Phase.buzzered);
      expect(first.state.buzzQueue, ['red']);
      expect(first.effects.single, isA<BuzzerSound>().having((e) => e.teamId, 'teamId', 'red'));
      expect(apply(first.state, const Buzz('blue')).accepted, isFalse);
    });

    test('with a queue later buzzes line up, once each', () {
      final s = run(fixtureState(), [
        const SetQueueBuzzers(true),
        const OpenQuestion(free),
        const Buzz('red'),
        const Buzz('blue'),
      ]);
      expect(s.buzzQueue, ['red', 'blue']);
      expect(apply(s, const Buzz('red')).accepted, isFalse);
    });

    test('no buzzing on the board, on no-buzzer questions, or for unknown teams', () {
      expect(apply(fixtureState(), const Buzz('red')).accepted, isFalse);
      final noBuzzer = run(fixtureState(), [const OpenQuestion(estimate)]);
      expect(apply(noBuzzer, const Buzz('red')).accepted, isFalse);
      final open = run(fixtureState(), [const OpenQuestion(free)]);
      expect(apply(open, const Buzz('green')).accepted, isFalse);
    });

    test('buzzer test shows the last team that buzzed and only starts from the board', () {
      var s = run(fixtureState(), [const SetBuzzerTest(true), const Buzz('red'), const Buzz('blue')]);
      expect(s.phase, Phase.buzzerTest);
      expect(s.buzzQueue, ['blue']);
      expect(apply(s, const OpenQuestion(free)).accepted, isFalse);
      s = run(s, [const SetBuzzerTest(false)]);
      expect(s.phase, Phase.overview);
      expect(s.buzzQueue, isEmpty);
      final open = run(fixtureState(), [const OpenQuestion(free)]);
      expect(apply(open, const SetBuzzerTest(true)).accepted, isFalse);
    });

    test('a buzz pauses the question sound and stops the music', () {
      final s = run(fixtureState(), [
        const OpenQuestion(song),
        const SetMusic(musicCalm),
        const SetMedia(MediaPlayback.playing),
        const Buzz('red'),
      ]);
      expect(s.media, MediaPlayback.paused);
      expect(s.music, isNull);
    });
  });

  group('judging', () {
    test('right: points, played, back to the board', () {
      final result = apply(run(fixtureState(), [const OpenQuestion(free), const Buzz('red')]), const Judge(correct: true));
      expect(points(result.state, 'red'), 100);
      expect(points(result.state, 'blue'), 0);
      expect(result.state.phase, Phase.overview);
      expect(result.state.played, {free.key});
      expect((result.effects.single as SoundEffect).key, effectAnswerCorrect);
    });

    test('wrong: minus points and the question reopens, resuming its sound', () {
      final result = apply(
        run(fixtureState(), [const OpenQuestion(song), const SetMedia(MediaPlayback.playing), const Buzz('red')]),
        const Judge(correct: false),
      );
      expect(points(result.state, 'red'), -150);
      expect(result.state.phase, Phase.question);
      expect(result.state.buzzQueue, isEmpty);
      expect(result.state.media, MediaPlayback.playing);
      expect((result.effects.single as SoundEffect).key, effectAnswerWrong);
    });

    test('wrong with a queue: the next team is up', () {
      final s = run(fixtureState(), [
        const SetQueueBuzzers(true),
        const OpenQuestion(free),
        const Buzz('red'),
        const Buzz('blue'),
        const Judge(correct: false),
      ]);
      expect(s.phase, Phase.buzzered);
      expect(s.buzzQueue, ['blue']);
      expect(points(s, 'red'), -50);
    });

    test('skip and reopen', () {
      final queued = run(fixtureState(), [
        const SetQueueBuzzers(true),
        const OpenQuestion(free),
        const Buzz('red'),
        const Buzz('blue'),
      ]);
      expect(run(queued, [const SkipBuzzer()]).buzzQueue, ['blue']);
      final reopened = run(queued, [const ReopenQuestion()]);
      expect(reopened.phase, Phase.question);
      expect(reopened.buzzQueue, isEmpty);
      expect(points(reopened, 'red'), 0);
      final single = run(fixtureState(), [const OpenQuestion(free), const Buzz('red')]);
      expect(apply(single, const SkipBuzzer()).accepted, isFalse);
    });

    test('generic judging is not available for feud or before a buzz', () {
      final open = run(fixtureState(), [const OpenQuestion(free)]);
      expect(apply(open, const Judge(correct: true)).accepted, isFalse);
      final feudBuzzed = run(fixtureState(), [const OpenQuestion(feud), const Buzz('red')]);
      expect(apply(feudBuzzed, const Judge(correct: true)).accepted, isFalse);
    });
  });

  group('reveals', () {
    test('abcd reveals one answer at a time, plus one step for the solution', () {
      var s = run(fixtureState(), [const OpenQuestion(abcd)]);
      expect(apply(s, const Reveal(-1)).accepted, isFalse);
      s = run(s, [for (var i = 0; i < 5; i++) const Reveal(1)]);
      expect(s.revealed, 5);
      expect(apply(s, const Reveal(1)).accepted, isFalse);
      expect(run(s, [const Reveal(-1)]).revealed, 4);
    });

    test('progressing reveal: the enlarged image follows reveals and can be stepped', () {
      var s = run(fixtureState(), [const OpenQuestion(reveal), const Reveal(1), const Reveal(1)]);
      expect((s.revealed, s.imageFocus), (2, 2));
      s = run(s, [const ImageFocus(-1)]);
      expect(s.imageFocus, 1);
      expect(apply(run(s, [const ImageFocus(1)]), const ImageFocus(1)).accepted, isFalse);
      // un-revealing pulls the focus back with it
      s = run(s, [const ImageFocus(1), const Reveal(-1)]);
      expect((s.revealed, s.imageFocus), (1, 1));
      s = run(s, [const ImageFocus(-1), const Reveal(-1)]);
      expect((s.revealed, s.imageFocus), (0, 0));
    });

    test('free questions have nothing to reveal', () {
      final s = run(fixtureState(), [const OpenQuestion(free)]);
      expect(apply(s, const Reveal(1)).accepted, isFalse);
      expect(apply(s, const ImageFocus(1)).accepted, isFalse);
    });
  });

  group('feud', () {
    SessionState buzzed() => run(fixtureState(), [const OpenQuestion(feud), const Buzz('red')]);

    test('uncovering every answer gives the answering team the full value', () {
      var s = run(buzzed(), [const FeudToggle(0), const FeudToggle(2)]);
      expect(s.phase, Phase.buzzered);
      expect(points(s, 'red'), 0);
      s = run(s, [const FeudToggle(2)]);
      expect(s.feudRevealed, [0]);
      s = run(s, [const FeudToggle(2), const FeudToggle(1)]);
      expect(s.phase, Phase.answerRevealed);
      expect(points(s, 'red'), 1000);
    });

    test('three strikes, then a successful steal pays the other team', () {
      var s = run(buzzed(), [const FeudToggle(0), const FeudWrong(), const FeudWrong()]);
      expect(apply(s, const FeudSteal(success: true)).accepted, isFalse);
      s = run(s, [const FeudWrong()]);
      expect(s.wrongAttempts, 3);
      expect(apply(s, const FeudWrong()).accepted, isFalse);
      final stolen = apply(s, const FeudSteal(success: true));
      expect(points(stolen.state, 'blue'), 500);
      expect(points(stolen.state, 'red'), 0);
      expect(stolen.state.phase, Phase.answerRevealed);
      expect(stolen.state.feudRevealed, [0, 1, 2]);
      expect((stolen.effects.single as SoundEffect).key, effectAnswerCorrect);
    });

    test('a failed steal leaves the points with the original team', () {
      final s = run(buzzed(), [
        const FeudToggle(1),
        const FeudWrong(),
        const FeudWrong(),
        const FeudWrong(),
        const FeudSteal(success: false),
      ]);
      expect(points(s, 'red'), 300);
      expect(points(s, 'blue'), 0);
    });

    test('with three teams the stealer is the next in the queue, or nobody', () {
      final three = fixtureState().copyWith(teams: [...fixtureState().teams, const Team(id: 'green', name: 'Green')]);
      final noQueue = run(three, [const OpenQuestion(feud), const Buzz('red')]);
      expect(feudOpponent(noQueue), isNull);
      final queued = run(three, [const SetQueueBuzzers(true), const OpenQuestion(feud), const Buzz('red'), const Buzz('green')]);
      expect(feudOpponent(queued), 'green');
    });

    test('strikes can be reset; feud commands need a feud question and a buzz', () {
      expect(run(buzzed(), [const FeudWrong(), const FeudResetWrong()]).wrongAttempts, 0);
      final open = run(fixtureState(), [const OpenQuestion(feud)]);
      expect(apply(open, const FeudToggle(0)).accepted, isFalse);
      final other = run(fixtureState(), [const OpenQuestion(free), const Buzz('red')]);
      expect(apply(other, const FeudToggle(0)).accepted, isFalse);
      expect(apply(buzzed(), const FeudToggle(3)).accepted, isFalse);
    });
  });

  group('audio', () {
    test('question sound needs a question that has one', () {
      final silent = run(fixtureState(), [const OpenQuestion(free)]);
      expect(apply(silent, const SetMedia(MediaPlayback.playing)).accepted, isFalse);
      expect(apply(fixtureState(), const SetMedia(MediaPlayback.playing)).accepted, isFalse);
      final s = run(fixtureState(), [const OpenQuestion(song), const SetMedia(MediaPlayback.playing)]);
      expect(run(s, [const SetMedia(MediaPlayback.stopped)]).media, MediaPlayback.stopped);
      expect(run(s, [const CloseQuestion()]).media, MediaPlayback.stopped);
    });

    test('music and question sound never play together', () {
      var s = run(fixtureState(), [const OpenQuestion(song), const SetMusic(musicCalm), const SetMedia(MediaPlayback.playing)]);
      expect(s.music, isNull);
      s = run(s, [const SetMusic(musicExciting)]);
      expect(s.media, MediaPlayback.paused);
      expect(apply(s, const SetMusic('polka')).accepted, isFalse);
    });

    test('effects are passed through without touching the state', () {
      final result = apply(fixtureState(), const PlayEffect('airhorn'));
      expect((result.effects.single as SoundEffect).key, 'airhorn');
      expect(result.state.seq, fixtureState().seq);
    });
  });

  group('teams', () {
    test('add, rename and remove, with unique non-empty names', () {
      var s = run(fixtureState(), [const AddTeam('green', ' Green ')]);
      expect(s.team('green')!.name, 'Green');
      expect(apply(s, const AddTeam('x', 'Green')).accepted, isFalse);
      expect(apply(s, const AddTeam('green', 'Other')).accepted, isFalse);
      expect(apply(s, const AddTeam('x', '  ')).accepted, isFalse);
      expect(apply(s, const RenameTeam('green', 'Red')).accepted, isFalse);
      s = run(s, [const RenameTeam('green', 'Lime'), const RemoveTeam('red')]);
      expect(s.teams.map((t) => t.name), ['Blue', 'Lime']);
    });

    test('points can be adjusted and set', () {
      final s = run(fixtureState(), [const AdjustPoints('red', 100), const AdjustPoints('red', -10), const SetPoints('blue', 42)]);
      expect(points(s, 'red'), 90);
      expect(points(s, 'blue'), 42);
      expect(apply(s, const AdjustPoints('green', 1)).accepted, isFalse);
    });

    test('removing the answering team reopens the question', () {
      final s = run(fixtureState(), [const OpenQuestion(free), const Buzz('red'), const RemoveTeam('red')]);
      expect(s.phase, Phase.question);
      expect(s.buzzQueue, isEmpty);
    });
  });

  group('answer rounds', () {
    SessionState round() => run(fixtureState(), [const OpenQuestion(estimate), const OpenAnswers(AnswerKind.text)]);

    test('teams submit while open and may overwrite; the kind must match', () {
      var s = run(round(), [
        const SubmitAnswer('red', PlayerAnswer(text: '40')),
        const SubmitAnswer('red', PlayerAnswer(text: '42')),
      ]);
      expect(s.answerRound!.answers['red']!.text, '42');
      expect(apply(s, const SubmitAnswer('blue', PlayerAnswer(choice: 1))).accepted, isFalse);
      expect(apply(s, const SubmitAnswer('green', PlayerAnswer(text: 'x'))).accepted, isFalse);
      s = run(s, [const LockAnswers()]);
      expect(apply(s, const SubmitAnswer('blue', PlayerAnswer(text: 'late'))).accepted, isFalse);
    });

    test('reveal locks; closing the question clears the round', () {
      var s = run(round(), [const SubmitAnswer('red', PlayerAnswer(text: '42')), const RevealAnswers()]);
      expect(s.answerRound!.revealed, isTrue);
      expect(s.answerRound!.open, isFalse);
      s = run(s, [const CloseQuestion()]);
      expect(s.answerRound, isNull);
    });

    test('needs an open question', () {
      expect(apply(fixtureState(), const OpenAnswers(AnswerKind.text)).accepted, isFalse);
      expect(apply(fixtureState(), const SubmitAnswer('red', PlayerAnswer(text: 'x'))).accepted, isFalse);
    });
  });
}
