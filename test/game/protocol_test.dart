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
      const ShowCard(OverlayCard(title: 'T', text: 'x', image: 'i.png')),
    ]);
    final copy = SessionState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(copy.toJson(), s.toJson());
    expect(copy.current, reveal);
    expect(copy.answerRound!.answers['red']!.drawing, 'strokes');
    expect((copy.overlay!.title, copy.overlay!.text, copy.overlay!.image), ('T', 'x', 'i.png'));
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
      ShowCard(OverlayCard(title: 'Break', image: 'a.png')),
      HideCard(),
      ScreenEffect(screenEffectFlash),
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

  group('public view', () {
    String view(SessionState s) => jsonEncode(publicView(s, game));
    PublicView parsed(SessionState s) => PublicView(jsonDecode(view(s)) as Map<String, dynamic>);

    test('never contains the answer hint or other questions', () {
      final s = run(fixtureState(), [const OpenQuestion(free)]);
      expect(view(s), contains('Capital of France?'));
      expect(view(s), isNot(contains('Paris')));
      expect(view(s), isNot(contains('Name the song')));
      expect(view(fixtureState()), isNot(contains('Capital of France?')));
    });

    test('abcd answers appear as revealed, correctness only at the end', () {
      var s = run(fixtureState(), [const OpenQuestion(abcd), const Reveal(1), const Reveal(1)]);
      expect(parsed(s).question!['answers'], ['a', 'b']);
      expect(parsed(s).question!.containsKey('answersCorrect'), isFalse);
      s = run(s, [const Reveal(1), const Reveal(1), const Reveal(1)]);
      expect(parsed(s).question!['answersCorrect'], [false, true, false, false]);
    });

    test('progressing reveal and feud only show what is uncovered', () {
      var s = run(fixtureState(), [const OpenQuestion(reveal), const Reveal(1)]);
      expect(view(s), contains('hint 1'));
      expect(view(s), isNot(contains('hint 2')));
      s = run(fixtureState(), [const OpenQuestion(feud), const Buzz('red'), const FeudToggle(1)]);
      expect(view(s), contains('banana'));
      expect(view(s), isNot(contains('apple')));
    });

    test('submissions stay hidden until revealed; who has submitted does not', () {
      var s = run(fixtureState(), [
        const OpenQuestion(estimate),
        const OpenAnswers(AnswerKind.text),
        const SubmitAnswer('red', PlayerAnswer(text: 'red-secret')),
      ]);
      expect(view(s), isNot(contains('red-secret')));
      expect(parsed(s).answerKind, AnswerKind.text);
      expect(parsed(s).answersOpen, isTrue);
      expect(parsed(s).hasSubmitted('red'), isTrue);
      expect(parsed(s).hasSubmitted('blue'), isFalse);
      s = run(s, [const RevealAnswers()]);
      expect(view(s), contains('red-secret'));
      expect(parsed(s).answersOpen, isFalse);
    });

    test('canBuzz follows the rules for each team', () {
      var s = run(fixtureState(), [const SetQueueBuzzers(true), const OpenQuestion(free)]);
      expect(parsed(s).canBuzz('red'), isTrue);
      expect(parsed(s).canBuzz('green'), isFalse);
      s = run(s, [const Buzz('red')]);
      expect(parsed(s).phase, Phase.buzzered);
      expect(parsed(s).canBuzz('red'), isFalse);
      expect(parsed(s).canBuzz('blue'), isTrue);
      expect(parsed(fixtureState()).canBuzz('red'), isFalse);
      expect(parsed(run(fixtureState(), [const OpenQuestion(estimate)])).canBuzz('red'), isFalse);
    });
  });

  group('session host', () {
    test('applies commands, emits states in order and passes effects on', () async {
      final host = SessionHost(initial: fixtureState(), game: game);
      final seqs = <int>[];
      final effects = <Effect>[];
      host.states.listen((s) => seqs.add(s.seq));
      host.effects.listen(effects.add);

      expect(host.dispatch(const OpenQuestion(free)), isTrue);
      expect(host.dispatch(const Buzz('red')), isTrue);
      expect(host.dispatch(const Judge(correct: true)), isTrue);
      expect(seqs, [1, 2, 3]);
      expect(effects.map((e) => e.runtimeType), [BuzzerSound, SoundEffect]);
      expect(host.state.team('red')!.points, 100);
      await host.dispose();
    });

    test('enforces who may send what', () async {
      final host = SessionHost(initial: fixtureState(), game: game);
      const red = Sender(Role.player, teamId: 'red');
      expect(host.dispatch(const OpenQuestion(free), sender: red), isFalse);
      expect(host.dispatch(const OpenQuestion(free), sender: const Sender(Role.controller)), isTrue);
      expect(host.dispatch(const Buzz('blue'), sender: red), isFalse);
      expect(host.dispatch(const Buzz('red'), sender: red), isTrue);
      expect(host.dispatch(const AdjustPoints('red', 500), sender: red), isFalse);
      expect(host.state.buzzQueue, ['red']);
      await host.dispose();
    });

    test('rejected commands and pure effects emit no state', () async {
      final host = SessionHost(initial: fixtureState(), game: game);
      var states = 0;
      var effects = 0;
      host.states.listen((_) => states++);
      host.effects.listen((_) => effects++);
      expect(host.dispatch(const Judge(correct: true)), isFalse);
      expect(host.dispatch(const PlayEffect('airhorn')), isTrue);
      expect((states, effects), (0, 1));
      await host.dispose();
    });

    test('new content republishes; a question that vanished is closed unplayed', () async {
      final host = SessionHost(initial: fixtureState(), game: game)..dispatch(const OpenQuestion(free));
      var states = 0;
      host.states.listen((_) => states++);
      host.setGame(game);
      expect(states, 1);
      expect(host.state.current, free);

      host.setGame(GameContent(id: 'game'));
      expect(host.state.current, isNull);
      expect(host.state.phase, Phase.overview);
      expect(host.state.played, isEmpty);
      expect(host.publicState['question'], isNull);
      await host.dispose();
    });

    test('ignores commands after dispose', () async {
      final host = SessionHost(initial: fixtureState(), game: game);
      await host.dispose();
      expect(host.dispatch(const OpenQuestion(free)), isFalse);
    });
  });
}
