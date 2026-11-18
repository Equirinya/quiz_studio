import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';

/// ABCD on the teams' devices: the options arrive as the big screen
/// uncovers them, and the clock waits for the last.
void main() {
  const ref = QuestionRef('c2', 'abcd');
  GameContent game({Map<String, dynamic>? companion, int? timer}) {
    final base = fixtureGame();
    final question = Map<String, dynamic>.from(base.question(ref)!.data);
    if (companion != null) question['companion'] = companion;
    if (timer != null) question['timer'] = timer;
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

  test('the devices get the options only as they are uncovered', () {
    final g = game(companion: {'kind': 'choice'});
    var s = run(fixtureState(), [const OpenQuestion(ref)], g);
    var spec = PublicView(publicView(s, g)).companion!;
    expect(spec['options'], isEmpty);
    expect(spec['optionCount'], 4);

    s = run(s, [const Reveal(1), const Reveal(1)], g);
    spec = PublicView(publicView(s, g)).companion!;
    expect(spec['options'], ['a', 'b']);
    expect(spec['optionCount'], 4);

    s = run(s, [const Reveal(1), const Reveal(1)], g);
    spec = PublicView(publicView(s, g)).companion!;
    expect(spec['options'], ['a', 'b', 'c', 'd']);
    expect(spec.containsKey('optionCount'), isFalse);
  });

  test("the devices' timer starts once the last option is up", () {
    final g = game(companion: {'kind': 'choice', 'timer': 20});
    var s = run(fixtureState(), [const OpenQuestion(ref), const Reveal(3)], g, 1000);
    expect(s.answerRound!.endsAtMillis, isNull);
    s = run(s, [const Reveal(1)], g, 5000);
    expect(s.answerRound!.endsAtMillis, 25000);
    // Uncovering the right answer does not start it over.
    s = run(s, [const Reveal(1)], g, 9000);
    expect(s.answerRound!.endsAtMillis, 25000);
  });

  test("the question's own clock waits for the options too", () {
    final g = game(timer: 30);
    var s = run(fixtureState(), [const OpenQuestion(ref)], g, 1000);
    expect(s.timer, isNull);
    s = run(s, [const Reveal(4)], g, 4000);
    expect(s.timer!.endsAtMillis, 34000);
  });
}
