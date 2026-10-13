import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';

void main() {
  final game = fixtureGame();

  test('session state survives a JSON round trip', () {
    final s = run(fixtureState(), [
      const SetQueueBuzzers(true),
      const OpenQuestion(free),
      const CloseQuestion(),
      const OpenQuestion(reveal),
      const Reveal(1),
      const SetMusic(musicCalm),
      const OpenAnswers(AnswerKind.drawing),
      const SubmitAnswer('red', PlayerAnswer(drawing: 'strokes')),
      const Buzz('blue'),
      const AdjustPoints('red', -30),
    ]);
    final copy = SessionState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(copy.toJson(), s.toJson());
    expect(copy.current, reveal);
    expect(copy.answerRound!.answers['red']!.drawing, 'strokes');
  });

  test('every command survives a JSON round trip', () {
    const commands = <Command>[
      SetGame('g'),
      SetGame(null),
      SelectGroup('g1'),
      OpenQuestion(free),
      CloseQuestion(markPlayed: false),
      UnmarkPlayed(free),
      SetBuzzerTest(true),
      Buzz('red'),
      Judge(correct: false),
      SkipBuzzer(),
      ReopenQuestion(),
      Reveal(-1),
      ImageFocus(1),
      FeudToggle(2),
      FeudWrong(),
      FeudSteal(success: true),
      FeudResetWrong(),
      SetMedia(MediaPlayback.paused),
      SetMusic(null),
      PlayEffect('airhorn'),
      AdjustPoints('red', -10),
      SetPoints('red', 5),
      AddTeam('t', 'Team'),
      RenameTeam('t', 'Other'),
      RemoveTeam('t'),
      SetQueueBuzzers(true),
      OpenAnswers(AnswerKind.choice),
      SubmitAnswer('red', PlayerAnswer(choice: 2)),
      LockAnswers(),
      RevealAnswers(),
      ClearAnswers(),
    ];
    for (final command in commands) {
      final json = jsonDecode(jsonEncode(command.toJson())) as Map<String, dynamic>;
      final parsed = Command.fromJson(json);
      expect(parsed, isNotNull, reason: command.type);
      expect(parsed.runtimeType, command.runtimeType);
      expect(parsed!.toJson(), command.toJson());
    }
  });

  test('malformed commands parse to null instead of throwing', () {
    expect(Command.fromJson({'type': 'launchMissiles'}), isNull);
    expect(Command.fromJson({'type': 'buzz'}), isNull);
    expect(Command.fromJson({'type': 'openQuestion', 'ref': 'no-slash'}), isNull);
    expect(Command.fromJson({'type': 'setMedia', 'playback': 'rewind'}), isNull);
    expect(Command.fromJson({}), isNull);
  });

  test('players may only buzz and answer for their own team', () {
    const red = Sender(Role.player, teamId: 'red');
    expect(mayIssue(red, const Buzz('red')), isTrue);
    expect(mayIssue(red, const SubmitAnswer('red', PlayerAnswer(text: 'x'))), isTrue);
    expect(mayIssue(red, const Buzz('blue')), isFalse);
    expect(mayIssue(red, const SubmitAnswer('blue', PlayerAnswer(text: 'x'))), isFalse);
    expect(mayIssue(red, const AdjustPoints('red', 1000)), isFalse);
    expect(mayIssue(red, const Judge(correct: true)), isFalse);
    expect(mayIssue(red, const RevealAnswers()), isFalse);
    expect(mayIssue(const Sender(Role.player), const Buzz('red')), isFalse);
    expect(mayIssue(const Sender(Role.controller), const Judge(correct: true)), isTrue);
    expect(mayIssue(const Sender.host(), const SetGame('g')), isTrue);
  });

  group('player view', () {
    String view(SessionState s, [String team = 'red']) => jsonEncode(playerView(s, game, team));

    test('never contains the answer hint or other questions', () {
      final s = run(fixtureState(), [const OpenQuestion(free)]);
      expect(view(s), contains('Capital of France?'));
      expect(view(s), isNot(contains('Paris')));
      expect(view(s), isNot(contains('Name the song')));
      expect(view(fixtureState()), isNot(contains('Capital of France?')));
    });

    test('abcd answers appear as revealed, correctness only at the end', () {
      var s = run(fixtureState(), [const OpenQuestion(abcd), const Reveal(1), const Reveal(1)]);
      var q = playerView(s, game, 'red')['question'] as Map<String, dynamic>;
      expect(q['answers'], ['a', 'b']);
      expect(q.containsKey('answersCorrect'), isFalse);
      s = run(s, [const Reveal(1), const Reveal(1), const Reveal(1)]);
      q = playerView(s, game, 'red')['question'] as Map<String, dynamic>;
      expect(q['answersCorrect'], [false, true, false, false]);
    });

    test('progressing reveal and feud only show what is uncovered', () {
      var s = run(fixtureState(), [const OpenQuestion(reveal), const Reveal(1)]);
      expect(view(s), contains('hint 1'));
      expect(view(s), isNot(contains('hint 2')));
      s = run(fixtureState(), [const OpenQuestion(feud), const Buzz('red'), const FeudToggle(1)]);
      expect(view(s), contains('banana'));
      expect(view(s), isNot(contains('apple')));
    });

    test('other teams answers stay hidden until revealed', () {
      var s = run(fixtureState(), [
        const OpenQuestion(estimate),
        const OpenAnswers(AnswerKind.text),
        const SubmitAnswer('red', PlayerAnswer(text: 'red-secret')),
        const SubmitAnswer('blue', PlayerAnswer(text: 'blue-secret')),
      ]);
      expect(view(s, 'red'), contains('red-secret'));
      expect(view(s, 'red'), isNot(contains('blue-secret')));
      expect((playerView(s, game, 'red')['answerRound'] as Map)['submitted'], ['red', 'blue']);
      s = run(s, [const RevealAnswers()]);
      expect(view(s, 'red'), contains('blue-secret'));
    });

    test('canBuzz reflects the rules for this team', () {
      var s = run(fixtureState(), [const SetQueueBuzzers(true), const OpenQuestion(free)]);
      expect(playerView(s, game, 'red')['canBuzz'], isTrue);
      s = run(s, [const Buzz('red')]);
      expect(playerView(s, game, 'red')['canBuzz'], isFalse);
      expect(playerView(s, game, 'blue')['canBuzz'], isTrue);
      expect(playerView(fixtureState(), game, 'red')['canBuzz'], isFalse);
    });
  });
}
