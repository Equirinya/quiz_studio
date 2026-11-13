import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';
import 'rapid_fixture.dart';

void main() {
  final game = matchingGame();
  final question = game.question(matchingRound)!;

  test('read back with its pairs, pictures cached, and only playable on devices', () {
    expect(question.type, QuestionType.matching);
    expect(question.matching!.pairs, hasLength(4));
    expect(question.needsDevices, isTrue);
    expect(question.buzzerable, isFalse);
    expect(game.mediaPaths, contains('poster.png'));
    expect(Matching.fromMap(question.matching!.toMap()).toMap(), question.matching!.toMap());
    expect(questionAsText(question), contains('[picture] = 1977'));
  });

  test('the right side gets shuffled numbers, the same every time', () {
    final numbers = question.matching!.rightNumbers(question.id);
    expect(numbers.toSet(), {1, 2, 3, 4});
    expect(numbers, isNot([1, 2, 3, 4]));
    expect(question.matching!.rightNumbers(question.id), numbers);
  });

  test('opening it starts a match round; a picture is named, and its name goes to the devices', () {
    final s = reduce(fixtureState(), const OpenQuestion(matchingRound), game, now: 1000).state;
    final spec = s.answerRound!.spec;
    expect((spec.kind, spec.timerSeconds, spec.lockable), (CompanionKind.match, 90, true));
    expect(spec.options[0], 'Back to the Future');
    expect(spec.options[2], 'Picture C');
    // The devices get the picture itself separately, shrunk; here only its name.
    expect(spec.pictures, contains('poster.png'));
    final public = publicView(s, game, teamId: 'red').toString();
    expect(public, contains('poster.png'));
  });

  test('a team that pairs everything right is judged right', () {
    final spec = question.companion!;
    expect(autoVerdict(spec, const PlayerAnswer(pairs: [0, 1, 2, 3])), isTrue);
    expect(autoVerdict(spec, const PlayerAnswer(pairs: [1, 0, 2, 3])), isFalse);
  });

  test('other device-only questions say so too', () {
    expect(QuestionType.connections.needsDevices, isTrue);
    expect(rapidGame().question(devicesRound)!.needsDevices, isTrue);
    expect(rapidGame().question(buzzerRound)!.needsDevices, isFalse);
  });

  test('the solution comes up pair by pair, the last two together, and back', () {
    var s = reduce(fixtureState(), const OpenQuestion(matchingRound), game).state;
    s = reduce(s, const LockAnswers(), game).state;
    expect(question.maxReveal, 4);
    for (final expected in [1, 2, 4]) {
      s = reduce(s, const Reveal(1), game).state;
      expect(s.revealed, expected);
    }
    expect(reduce(s, const Reveal(1), game).accepted, isFalse);
    expect(reduce(s, const Reveal(-1), game).state.revealed, 2);
  });
}
