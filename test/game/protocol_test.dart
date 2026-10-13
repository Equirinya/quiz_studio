import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';

void main() {
  final game = fixtureGame();

  test('session state survives a JSON round trip', () {
    final s = run(fixtureState(), [
      const SetQueueBuzzers(true),
      const SetThumbnails(false),
      const SetTeamSound('blue', 'horn.mp3'),
      const OpenQuestion(free),
      const CloseQuestion(),
      const OpenQuestion(reveal),
      const Reveal(1),
      const SetMusic(musicCalm),
      const OpenAnswers(CompanionSpec(kind: CompanionKind.whiteboard, timerSeconds: 30)),
      const SubmitAnswer('red', PlayerAnswer(drawing: 'strokes')),
      const Buzz('blue'),
      const AdjustPoints('red', -30),
      const ShowCard(OverlayCard(title: 'T', text: 'x', image: 'i.png')),
    ]);
    final copy = SessionState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(copy.toJson(), s.toJson());
    expect(copy.current, reveal);
    expect(copy.thumbnails, isFalse);
    expect(copy.team('blue')!.sound, 'horn.mp3');
    expect(copy.team('red')!.sound, isNull);
    expect(copy.answerRound!.answers['red']!.drawing, 'strokes');
    expect(copy.answerRound!.spec.timerSeconds, 30);
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
      SetThumbnails(false),
      SetTeamSound('red', 'horn.mp3'),
      SetTeamSound('red', null),
      OpenAnswers(CompanionSpec(kind: CompanionKind.slider, min: 0, max: 10, step: 0.5, unit: 'kg', solution: 4, timerSeconds: 20)),
      OpenAnswers(CompanionSpec(kind: CompanionKind.match, options: ['a', 'b'], targets: ['1', '2'])),
      SubmitAnswer('red', PlayerAnswer(choice: 2)),
      SubmitAnswer('red', PlayerAnswer(order: [2, 0, 1])),
      SubmitAnswer('red', PlayerAnswer(number: 3.5)),
      LockAnswer('red'),
      LockAnswers(),
      UnlockAnswers(),
      RevealAnswer('red', show: false),
      RevealNextAnswer(),
      RevealAnswers(),
      RateAnswer('red', correct: null),
      RateAnswer('red', correct: false),
      AwardAnswer('red', 250),
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

    test('answers stay hidden until shown, one team at a time; who has answered does not', () {
      var s = run(fixtureState(), [
        const OpenQuestion(estimate),
        const OpenAnswers(CompanionSpec(kind: CompanionKind.text)),
        const SubmitAnswer('red', PlayerAnswer(text: 'red-secret')),
        const SubmitAnswer('blue', PlayerAnswer(text: 'blue-secret')),
        const LockAnswer('red'),
      ]);
      expect(view(s), isNot(contains('secret')));
      expect(parsed(s).answerKind, CompanionKind.text);
      expect(parsed(s).answersOpen, isTrue);
      expect((parsed(s).hasSubmitted('red'), parsed(s).hasLocked('red'), parsed(s).hasLocked('blue')), (true, true, false));
      s = run(s, [const RevealAnswer('red')]);
      expect(view(s), contains('red-secret'));
      expect(view(s), isNot(contains('blue-secret')));
      expect(parsed(s).isRevealed('red'), isTrue);
      expect(parsed(s).answersOpen, isFalse);
    });

    test('the solution and the right order never reach a device', () {
      final order = run(fixtureState(), [
        const OpenQuestion(estimate),
        const OpenAnswers(CompanionSpec(kind: CompanionKind.order, options: ['first', 'second', 'third', 'fourth'])),
      ]);
      final items = (parsed(order).companion!['items'] as List).cast<Map>();
      expect(items.map((e) => e['t']).toSet(), {'first', 'second', 'third', 'fourth'});
      expect(items.map((e) => e['i']).toList(), isNot([0, 1, 2, 3]));
      // Each item still knows its original place, to answer with.
      expect({for (final e in items) e['t']: e['i']}, {'first': 0, 'second': 1, 'third': 2, 'fourth': 3});

      final slider = run(fixtureState(), [
        const OpenQuestion(estimate),
        const OpenAnswers(CompanionSpec(kind: CompanionKind.slider, min: 0, max: 100, solution: 42)),
      ]);
      expect(parsed(slider).companion!.containsKey('solution'), isFalse);
      expect(view(slider), isNot(contains('42')));
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
