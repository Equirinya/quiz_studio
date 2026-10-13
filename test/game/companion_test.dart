import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';

void main() {
  final game = fixtureGame();
  Reduction apply(SessionState s, Command c, {int? now}) => reduce(s, c, game, now: now);

  group('the whiteboard question', () {
    test('opening it starts the round on the screen and timer it was set up with', () {
      final s = apply(fixtureState(), const OpenQuestion(sum), now: 1000).state;
      final round = s.answerRound!;
      expect((round.kind, round.open, round.openedAtMillis, round.endsAtMillis), (CompanionKind.whiteboard, true, 1000, 31000));
      expect(buzzersOpen(s, game), isFalse);
    });

    test('a question without one starts none', () {
      expect(run(fixtureState(), [const OpenQuestion(free)]).answerRound, isNull);
    });

    test('teams keep updating their board until they lock it', () {
      var s = run(fixtureState(), [
        const OpenQuestion(sum),
        const SubmitAnswer('red', PlayerAnswer(drawing: 'a')),
        const SubmitAnswer('red', PlayerAnswer(drawing: 'ab')),
        const LockAnswer('red'),
      ]);
      expect((s.answerRound!.answers['red']!.drawing, s.answerRound!.answers['red']!.locked), ('ab', true));
      expect(apply(s, const SubmitAnswer('red', PlayerAnswer(drawing: 'abc'))).accepted, isFalse);
      expect(apply(s, const LockAnswer('red')).accepted, isFalse);
      // The other team is still writing.
      expect(s.answerRound!.open, isTrue);
      s = run(s, [const SubmitAnswer('blue', PlayerAnswer(drawing: 'x'))]);
      expect(s.answerRound!.answers['blue']!.locked, isFalse);
    });

    test('a device cannot lock itself by sending "locked" along', () {
      final s = run(fixtureState(), [const OpenQuestion(sum), const SubmitAnswer('red', PlayerAnswer(drawing: 'a', locked: true))]);
      expect(s.answerRound!.answers['red']!.locked, isFalse);
    });

    test('once everyone has locked in the round closes by itself', () {
      final s = run(fixtureState(), [const OpenQuestion(sum), const LockAnswer('red'), const LockAnswer('blue')]);
      expect(s.answerRound!.open, isFalse);
      expect(s.answerRound!.endsAtMillis, isNull);
    });

    test('locking closes it for everyone; unlocking lets them edit again', () {
      var s = run(fixtureState(), [const OpenQuestion(sum), const SubmitAnswer('red', PlayerAnswer(drawing: 'a')), const LockAnswers()]);
      expect(apply(s, const SubmitAnswer('red', PlayerAnswer(drawing: 'b'))).accepted, isFalse);
      expect(apply(s, const LockAnswer('blue')).accepted, isFalse);
      s = run(s, [const UnlockAnswers(), const SubmitAnswer('red', PlayerAnswer(drawing: 'b'))]);
      expect(s.answerRound!.answers['red']!.drawing, 'b');
    });

    test('answers are shown one by one, in team order, and can be taken off again', () {
      var s = run(fixtureState(), [const OpenQuestion(sum), const SubmitAnswer('blue', PlayerAnswer(drawing: 'b'))]);
      s = run(s, [const RevealNextAnswer()]);
      // Red is first even without an answer: an empty board is an answer too.
      expect(s.answerRound!.revealed, ['red']);
      expect(s.answerRound!.open, isFalse, reason: 'showing answers ends the writing');
      s = run(s, [const RevealNextAnswer()]);
      expect(s.answerRound!.revealed, ['red', 'blue']);
      expect(apply(s, const RevealNextAnswer()).accepted, isFalse);
      s = run(s, [const RevealAnswer('red', show: false)]);
      expect(s.answerRound!.revealed, ['blue']);
      s = run(s, [const RevealAnswers()]);
      expect(s.answerRound!.revealed, ['blue', 'red']);
    });

    test('right gives the question\'s points, wrong takes its minus, and a ruling can change', () {
      var s = run(fixtureState(), [const OpenQuestion(sum), const RateAnswer('red', correct: true)]);
      expect(points(s, 'red'), 400);
      s = run(s, [const RateAnswer('red', correct: false)]);
      expect(points(s, 'red'), 0, reason: 'this question has no minus points');
      s = run(s, [const RateAnswer('red', correct: true), const RateAnswer('red', correct: null)]);
      expect(points(s, 'red'), 0);
      expect(s.answerRound!.verdicts, isEmpty);
      expect(apply(s, const RateAnswer('red', correct: null)).accepted, isFalse);
    });

    test('several teams can be right', () {
      final s = run(fixtureState(), [const OpenQuestion(sum), const RateAnswer('red', correct: true), const RateAnswer('blue', correct: true)]);
      expect((points(s, 'red'), points(s, 'blue')), (400, 400));
    });

    test('custom points replace what the team got for this round', () {
      var s = run(fixtureState(), [const OpenQuestion(sum), const RateAnswer('red', correct: true), const AwardAnswer('red', 150)]);
      expect(points(s, 'red'), 150);
      expect(s.answerRound!.verdicts['red'], isTrue);
      s = run(s, [const AwardAnswer('red', 0)]);
      expect(points(s, 'red'), 0);
      expect(s.answerRound!.verdicts['red'], isFalse);
    });

    test('points stay when the question closes; the round goes', () {
      final s = run(fixtureState(), [const OpenQuestion(sum), const RateAnswer('red', correct: true), const CloseQuestion()]);
      expect(points(s, 'red'), 400);
      expect(s.answerRound, isNull);
    });

    test('ratings sound like the buzzer verdicts do', () {
      final s = run(fixtureState(), [const OpenQuestion(sum)]);
      expect((apply(s, const RateAnswer('red', correct: true)).effects.single as SoundEffect).key, effectAnswerCorrect);
      expect((apply(s, const RateAnswer('red', correct: false)).effects.single as SoundEffect).key, effectAnswerWrong);
    });

    test('players may answer and lock for their own team, never rate or reveal', () {
      const red = Sender(Role.player, teamId: 'red');
      expect(mayIssue(red, const SubmitAnswer('red', PlayerAnswer(drawing: 'a'))), isTrue);
      expect(mayIssue(red, const LockAnswer('red')), isTrue);
      expect(mayIssue(red, const LockAnswer('blue')), isFalse);
      expect(mayIssue(red, const RateAnswer('red', correct: true)), isFalse);
      expect(mayIssue(red, const AwardAnswer('red', 1000)), isFalse);
      expect(mayIssue(red, const RevealAnswer('blue')), isFalse);
      expect(mayIssue(red, const LockAnswers()), isFalse);
      expect(mayIssue(red, const UnlockAnswers()), isFalse);
    });

    test('a removed team leaves no trace in the round', () {
      final s = run(fixtureState(), [
        const OpenQuestion(sum),
        const SubmitAnswer('red', PlayerAnswer(drawing: 'a')),
        const RevealAnswer('red'),
        const RateAnswer('red', correct: true),
        const RemoveTeam('red'),
      ]);
      final round = s.answerRound!;
      expect(round.answers, isEmpty);
      expect(round.revealed, isEmpty);
      expect(round.verdicts, isEmpty);
      expect(round.awarded, isEmpty);
      // Points it was given are gone with it; nobody else's changed.
      expect(points(s, 'blue'), 0);
    });
  });

  group('the timer', () {
    test('locks the round when it runs out', () async {
      var clock = 0;
      final host = SessionHost(initial: fixtureState(), game: game, clock: () => clock);
      final custom = GameContent.fromJson(game.toJson()..['questions']['c1']['sum']['companion']['timer'] = 1);
      host.setGame(custom);
      host.dispatch(const OpenQuestion(sum));
      expect(host.state.answerRound!.open, isTrue);
      host.dispatch(const SubmitAnswer('red', PlayerAnswer(drawing: 'a')));
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(host.state.answerRound!.open, isFalse);
      expect(host.dispatch(const SubmitAnswer('red', PlayerAnswer(drawing: 'late'))), isFalse);
      expect(host.state.answerRound!.answers['red']!.drawing, 'a');
      await host.dispose();
    });

    test('does nothing once the round was locked or cleared by hand', () async {
      final host = SessionHost(initial: fixtureState(), game: game);
      host
        ..dispatch(const OpenQuestion(estimate))
        ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.text, timerSeconds: 1)))
        ..dispatch(const ClearAnswers())
        ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.text)));
      var states = 0;
      host.states.listen((_) => states++);
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(states, 0);
      expect(host.state.answerRound!.open, isTrue);
      await host.dispose();
    });

    test('a show resumed after its deadline locks at once', () async {
      final running = reduce(fixtureState(), const OpenQuestion(sum), game, now: 1000).state;
      final host = SessionHost(initial: running, game: game, clock: () => 99000);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(host.state.answerRound!.open, isFalse);
      await host.dispose();
    });
  });

  group('the other screens', () {
    SessionState round(CompanionSpec spec) => run(fixtureState(), [const OpenQuestion(estimate), OpenAnswers(spec)]);

    test('an answer has to fit the screen', () {
      final s = round(const CompanionSpec(kind: CompanionKind.slider, min: 0, max: 10));
      expect(apply(s, const SubmitAnswer('red', PlayerAnswer(number: 4))).accepted, isTrue);
      expect(apply(s, const SubmitAnswer('red', PlayerAnswer(text: 'four'))).accepted, isFalse);
      expect(apply(s, const SubmitAnswer('red', PlayerAnswer(number: 4, text: 'four'))).accepted, isFalse);
      expect(apply(s, const SubmitAnswer('red', PlayerAnswer())).accepted, isFalse);
    });

    test('order, pairs and picks can be judged without a human', () {
      const order = CompanionSpec(kind: CompanionKind.order, options: ['a', 'b', 'c']);
      expect(autoVerdict(order, const PlayerAnswer(order: [0, 1, 2])), isTrue);
      expect(autoVerdict(order, const PlayerAnswer(order: [1, 0, 2])), isFalse);
      expect(autoVerdict(order, null), isNull);

      const match = CompanionSpec(kind: CompanionKind.match, options: ['France', 'Italy'], targets: ['Paris', 'Rome']);
      expect(autoVerdict(match, const PlayerAnswer(pairs: [0, 1])), isTrue);
      expect(autoVerdict(match, const PlayerAnswer(pairs: [1, 0])), isFalse);
      expect(autoVerdict(match, const PlayerAnswer(pairs: [0, -1])), isFalse);

      const choice = CompanionSpec(kind: CompanionKind.choice, options: ['a', 'b']);
      expect(autoVerdict(choice, const PlayerAnswer(choice: 1), choiceCorrect: [false, true]), isTrue);
      expect(autoVerdict(choice, const PlayerAnswer(choice: 0), choiceCorrect: [false, true]), isFalse);
      expect(autoVerdict(choice, const PlayerAnswer(choice: 0)), isNull);
    });

    test('a whiteboard or a text always needs the gamemaster', () {
      expect(autoVerdict(const CompanionSpec(kind: CompanionKind.whiteboard), const PlayerAnswer(drawing: 'a')), isNull);
      expect(autoVerdict(const CompanionSpec(kind: CompanionKind.text), const PlayerAnswer(text: '8')), isNull);
    });

    test('estimates: exact is right, otherwise the closest team is found', () {
      const spec = CompanionSpec(kind: CompanionKind.number, solution: 100);
      expect(autoVerdict(spec, const PlayerAnswer(number: 100)), isTrue);
      expect(autoVerdict(spec, const PlayerAnswer(number: 99)), isFalse);
      expect(autoVerdict(const CompanionSpec(kind: CompanionKind.number), const PlayerAnswer(number: 1)), isNull);
      expect(closestTeams(spec, const {'a': PlayerAnswer(number: 80), 'b': PlayerAnswer(number: 111), 'c': PlayerAnswer(number: 89)}), ['b', 'c']);
      expect(closestTeams(spec, const {}), isEmpty);
      expect(closestTeams(const CompanionSpec(kind: CompanionKind.number), const {'a': PlayerAnswer(number: 1)}), isEmpty);
    });

    test('"pick one" on an ABCD question offers its answers', () {
      final abcdWithScreen = GameContent.fromJson(game.toJson()..['questions']['c2']['abcd']['companion'] = {'kind': 'choice'});
      expect(abcdWithScreen.question(abcd)!.companion!.options, ['a', 'b', 'c', 'd']);
    });

    test('a screen set up in the editor survives storage', () {
      const spec = CompanionSpec(
        kind: CompanionKind.slider,
        timerSeconds: 45,
        min: 0,
        max: 10,
        step: 0.5,
        unit: 'kg',
        solution: 4.5,
      );
      final copy = CompanionSpec.fromMap(spec.toMap())!;
      expect((copy.kind, copy.timerSeconds, copy.range, copy.unit, copy.solution),
          (CompanionKind.slider, 45, (min: 0.0, max: 10.0, step: 0.5), 'kg', 4.5));
      const list = CompanionSpec(kind: CompanionKind.whiteboard, background: 'list', listRows: 7);
      expect(CompanionSpec.fromMap(list.toMap())!.listRows, 7);
      expect(CompanionSpec.fromMap({'kind': 'hologram'}), isNull);
      expect(CompanionSpec.fromMap({'kind': 'whiteboard', 'background': 'lava', 'timer': -5})!.background, 'blank');
      expect(CompanionSpec.fromMap({'kind': 'whiteboard', 'timer': -5})!.timerSeconds, isNull);
      expect(const CompanionSpec(kind: CompanionKind.slider, min: 5, max: 5).range, (min: 5.0, max: 105.0, step: 1.0));
    });
  });

  group('a picture as whiteboard paper', () {
    const spec = CompanionSpec(kind: CompanionKind.whiteboard, background: 'image', backgroundImage: 'map.png');

    test('survives storage and tells the devices which picture to wait for', () {
      final copy = CompanionSpec.fromMap(spec.toMap())!;
      expect((copy.background, copy.backgroundImage), ('image', 'map.png'));
      expect(spec.toPublicMap('seed')['backgroundImage'], 'map.png');
      expect(spec.withOptions(const ['x']).backgroundImage, 'map.png');
    });

    test('without a picture it is a blank board', () {
      final copy = CompanionSpec.fromMap({'kind': 'whiteboard', 'background': 'image'})!;
      expect((copy.background, copy.backgroundImage), ('blank', null));
      // A picture name left over from another paper is ignored.
      expect(CompanionSpec.fromMap({'kind': 'whiteboard', 'background': 'lines', 'backgroundImage': 'map.png'})!.backgroundImage, isNull);
    });

    test('is cached with the rest of the question\'s media', () {
      final question = Question.fromMap('q', {'type': 'free', 'companion': spec.toMap()});
      expect(question.mediaPaths, ['map.png']);
    });

    test('travels in the session state', () {
      final s = run(fixtureState(), [const OpenQuestion(estimate), const OpenAnswers(spec)]);
      expect(SessionState.fromJson(s.toJson()).answerRound!.spec.backgroundImage, 'map.png');
    });
  });

  group('drawings', () {
    test('survive encoding, to about a thousandth of the board', () {
      final strokes = <Stroke>[
        [(0.0, 0.0), (0.5, 0.25), (1.0, 1.0)],
        [(0.3333, 0.6667)],
      ];
      final copy = decodeDrawing(encodeDrawing(strokes));
      expect(copy, hasLength(2));
      expect(copy[0], hasLength(3));
      expect(copy[0][1].$1, closeTo(0.5, 0.001));
      expect(copy[1][0].$2, closeTo(0.6667, 0.001));
    });

    test('junk decodes to nothing rather than throwing', () {
      expect(decodeDrawing(null), isEmpty);
      expect(decodeDrawing(''), isEmpty);
      expect(decodeDrawing('hello;1,2,3; ,;x,y'), isEmpty);
      expect(decodeDrawing('5,5 bad 7,7'), [
        [(5 / 999, 5 / 999), (7 / 999, 7 / 999)],
      ]);
    });

    test('a huge drawing is thinned out instead of growing without bound', () {
      final stroke = <InkPoint>[for (var i = 0; i < 20000; i++) (i / 20000, 0.5)];
      final copy = decodeDrawing(encodeDrawing([stroke]));
      expect(copy.single.length, lessThanOrEqualTo(kMaxInkPoints));
      // It still runs from one side to the other.
      expect(copy.single.first.$1, closeTo(0, 0.001));
      expect(copy.single.last.$1, closeTo(1, 0.001));
    });

    test('an upright board says so, and a sideways one stays as short as before', () {
      final strokes = <Stroke>[
        [(0.1, 0.2), (0.3, 0.4)],
      ];
      final sideways = encodeDrawing(strokes);
      final upright = encodeDrawing(strokes, aspect: 3 / 4);
      expect(sideways.startsWith('a'), isFalse);
      expect(upright.startsWith('a750|'), isTrue);
      expect(drawingAspect(sideways), kDefaultDrawingAspect);
      expect(drawingAspect(upright), 0.75);
      expect(decodeDrawing(upright), decodeDrawing(sideways));
      expect(drawingAspect('a5|1,1'), kDefaultDrawingAspect);
      expect(drawingAspect('abc|1,1'), kDefaultDrawingAspect);
      expect(drawingAspect(null), kDefaultDrawingAspect);
    });

    test('points outside the board are pulled onto it', () {
      expect(decodeDrawing(encodeDrawing([[(-0.5, 2.0)]])), [[(0.0, 1.0)]]);
    });
  });
}
