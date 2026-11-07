import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';
import 'rapid_fixture.dart';

/// The sound effects a show plays by itself, beyond right and wrong.
void main() {
  List<String> sounds(Reduction r) => [for (final e in r.effects) if (e is SoundEffect) e.key];

  test('a question opening, a team locking in', () {
    final game = fixtureGame();
    var r = reduce(fixtureState(), const OpenQuestion(sum), game, now: 0);
    expect(sounds(r), [effectQuestionOpen]);
    r = reduce(r.state, const LockAnswer('red'), game, now: 10);
    expect(sounds(r), [effectLockIn]);
  });

  test('Fragenhagel: the next item, and a fanfare when the last one is done', () {
    final game = rapidGame();
    var s = reduce(fixtureState(), const OpenQuestion(buzzerRound), game).state;
    var r = reduce(s, const Reveal(1), game);
    expect(sounds(r), [effectNextItem]);
    r = reduce(r.state, const Buzz('red'), game);
    r = reduce(r.state, const Judge(correct: true), game);
    expect(sounds(r), [effectAnswerCorrect]);
    r = reduce(r.state, const Reveal(1), game);
    expect(sounds(r), [effectFanfare], reason: 'that was the last item');
    s = r.state;
    expect(sounds(reduce(s, const Reveal(-1), game)), isEmpty, reason: 'going back is quiet');
  });

  test('Feud: the third strike announces the steal; the last answer gets the fanfare', () {
    final game = fixtureGame();
    var s = run(fixtureState(), const [OpenQuestion(feud), Buzz('red'), FeudWrong(), FeudWrong()], game);
    expect(sounds(reduce(s, const FeudWrong(), game)), [effectAnswerWrong, effectSteal]);
    s = run(fixtureState(), const [OpenQuestion(feud), Buzz('red')], game);
    final count = game.question(feud)!.information.length;
    for (var i = 0; i < count - 1; i++) {
      s = reduce(s, FeudToggle(i), game).state;
    }
    expect(sounds(reduce(s, FeudToggle(count - 1), game)), [effectFanfare]);
  });

  test('a timed round counts the last ten seconds down and says when time is up', () {
    fakeAsync((async) {
      var now = 0;
      final host = SessionHost(initial: fixtureState(), game: fixtureGame(), clock: () => now);
      final heard = <String>[];
      host.effects.listen((e) {
        if (e is SoundEffect) heard.add(e.key);
      });
      host
        ..dispatch(const OpenQuestion(free))
        ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.text, timerSeconds: 30)));
      heard.clear();
      now = 19000;
      async.elapse(const Duration(seconds: 19));
      expect(heard, isEmpty);
      now = 20500;
      async.elapse(const Duration(milliseconds: 1500));
      expect(heard, [effectCountdown]);
      now = 30500;
      async.elapse(const Duration(seconds: 10));
      expect(heard, [effectCountdown, effectTimesUp]);
      expect(host.state.answerRound!.open, isFalse);
      host.dispose();
    });
  });

  test('a short round, or one closed by hand, gets neither', () {
    fakeAsync((async) {
      var now = 0;
      final host = SessionHost(initial: fixtureState(), game: fixtureGame(), clock: () => now);
      final heard = <String>[];
      host.effects.listen((e) {
        if (e is SoundEffect) heard.add(e.key);
      });
      host
        ..dispatch(const OpenQuestion(free))
        ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.text, timerSeconds: 15)));
      heard.clear();
      now = 16000;
      async.elapse(const Duration(seconds: 16));
      expect(heard, [effectTimesUp], reason: 'too short for a countdown');
      host.dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.text, timerSeconds: 60)));
      heard.clear();
      host.dispatch(const LockAnswers());
      now = 80000;
      async.elapse(const Duration(seconds: 64));
      expect(heard, isEmpty);
      host.dispose();
    });
  });
}
