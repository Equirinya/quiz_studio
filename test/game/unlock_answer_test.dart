import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';

/// The gamemaster lets one team change its locked-in answer.
void main() {
  final game = fixtureGame();
  bool accepts(SessionState s, Command c) => reduce(s, c, game, now: 2000).accepted;

  test('a team that locked in can change its answer again; the others stay locked', () {
    var s = run(fixtureState(), [
      const OpenQuestion(race),
      const SubmitAnswer('red', PlayerAnswer(drawing: 'x')),
      const LockAnswer('red'),
      const SubmitAnswer('blue', PlayerAnswer(drawing: 'y')),
      const LockAnswer('blue'),
    ], game, 1000);
    // Everyone locked in: answering closed by itself.
    expect(s.answerRound!.open, isFalse);
    expect(canUnlockAnswer(s, 'red'), isTrue);

    s = run(s, [const UnlockAnswer('red')], game, 2000);
    expect(s.answerRound!.open, isTrue);
    expect(s.answerRound!.answers['red']!.locked, isFalse);
    expect(s.answerRound!.answers['red']!.drawing, 'x');
    expect(s.answerRound!.answers['blue']!.locked, isTrue);
    expect(accepts(s, const SubmitAnswer('red', PlayerAnswer(drawing: 'z'))), isTrue);
    expect(accepts(s, const UnlockAnswer('red')), isFalse, reason: 'not locked any more');
  });

  test('not once its answer is on the big screen, nor when you closed answering with others still open', () {
    final locked = run(fixtureState(), [const OpenQuestion(race), const SubmitAnswer('red', PlayerAnswer(drawing: 'x')), const LockAnswer('red')], game, 1000);
    expect(accepts(locked, const UnlockAnswer('red')), isTrue);
    expect(accepts(locked, const UnlockAnswer('blue')), isFalse, reason: 'blue never locked in');

    final closed = run(locked, [const LockAnswers()], game, 1500);
    expect(accepts(closed, const UnlockAnswer('red')), isFalse, reason: 'it would let blue answer again too');

    final shown = run(locked, [const RevealAnswer('red')], game, 1500);
    expect(accepts(shown, const UnlockAnswer('red')), isFalse);
  });

  test('players cannot unlock themselves', () {
    expect(mayIssue(const Sender(Role.player, teamId: 'red'), const UnlockAnswer('red')), isFalse);
    expect(Command.fromJson(const UnlockAnswer('red').toJson()), isA<UnlockAnswer>());
  });

  test('questions hidden on the board are left off the ring and the map', () {
    final g = fixtureGame();
    final category = g.category('c1')!;
    final hidden = Question.fromMap('h', {'type': 'free', 'question': 'Secret', 'pointsPlus': 900, 'hiddenOnBoard': true});
    expect(hidden.hiddenOnBoard, isTrue);
    final withHidden = Category(id: 'c1', name: 'First', questions: [...category.questions, hidden]);
    expect(withHidden.boardQuestions.map((q) => q.id), category.questions.map((q) => q.id));
  });
}
