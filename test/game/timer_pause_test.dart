import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';

/// Pausing and shortening a clock: the question's own, an information
/// screen's, and the devices' answer round's.
void main() {
  final game = fixtureGame();
  SessionState apply(SessionState s, Command c, int now) {
    final result = reduce(s, c, game, now: now);
    expect(result.accepted, isTrue, reason: '${c.toJson()} rejected');
    return result.state;
  }

  bool accepts(SessionState s, Command c, int now) => reduce(s, c, game, now: now).accepted;

  group('the question\'s own clock', () {
    SessionState timed() => apply(apply(fixtureState(), const OpenQuestion(free), 0), const SetTimer(60), 0);

    test('pauses and runs on with the time left then; the pause is not part of its length', () {
      var s = apply(timed(), const PauseTimer(paused: true), 20000);
      expect((s.timer!.paused, s.timer!.pausedAtMillis, s.timer!.endsAtMillis), (true, 20000, 60000));
      expect(accepts(s, const PauseTimer(paused: true), 21000), isFalse, reason: 'paused already');
      expect(accepts(s, const TimeUp(), 90000), isFalse, reason: 'never up while paused');
      s = apply(s, const PauseTimer(paused: false), 50000);
      expect((s.timer!.paused, s.timer!.endsAtMillis, s.timer!.heldMillis), (false, 90000, 30000));
      expect(s.timer!.endsAtMillis - s.timer!.openedAtMillis! - s.timer!.heldMillis, 60000);
      expect(accepts(s, const PauseTimer(paused: false), 51000), isFalse, reason: 'running already');
    });

    test('more or less time while paused moves the deadline and stays paused, never below nothing left', () {
      var s = apply(timed(), const PauseTimer(paused: true), 20000);
      s = apply(s, const SetTimer(30), 25000);
      expect((s.timer!.paused, s.timer!.endsAtMillis), (true, 90000));
      s = apply(s, const SetTimer(-30), 26000);
      expect((s.timer!.paused, s.timer!.endsAtMillis), (true, 60000));
      s = apply(s, const SetTimer(-120), 27000);
      expect((s.timer!.paused, s.timer!.endsAtMillis), (true, 20000), reason: 'nothing left, not less');
    });

    test('less time off a running clock as before: never into the past', () {
      var s = apply(timed(), const SetTimer(-30), 10000);
      expect(s.timer!.endsAtMillis, 30000);
      s = apply(s, const SetTimer(-60), 20000);
      expect(s.timer!.endsAtMillis, 20000);
    });

    test('nothing to pause once the time is up or without a clock', () {
      final up = reduce(timed(), const TimeUp(), game, now: 60000).state;
      expect(accepts(up, const PauseTimer(paused: true), 61000), isFalse);
      final none = apply(fixtureState(), const OpenQuestion(free), 0);
      expect(accepts(none, const PauseTimer(paused: true), 1000), isFalse);
      expect(accepts(timed(), const PauseTimer(paused: true), 60000), isFalse, reason: 'at its end');
    });

    test('a fresh clock or none ends the pause', () {
      final paused = apply(timed(), const PauseTimer(paused: true), 20000);
      expect(apply(paused, const SetTimer(null), 21000).timer, isNull);
    });

    test('kept as it is when the state is saved and loaded', () {
      final s = apply(apply(timed(), const PauseTimer(paused: true), 20000), const PauseTimer(paused: false), 30000);
      final paused = apply(s, const PauseTimer(paused: true), 40000);
      final back = SessionState.fromJson(paused.toJson()).timer!;
      expect((back.pausedAtMillis, back.heldMillis, back.endsAtMillis), (40000, 10000, 70000));
      final view = PublicView(publicView(paused, game)).questionTimer!;
      expect((view.pausedAt, view.held), (40000, 10000));
    });

    test('the host lets no time run out while paused, and does once it runs on', () {
      fakeAsync((async) {
        var clock = 0;
        final host = SessionHost(initial: fixtureState(), game: game, clock: () => clock);
        final effects = <Effect>[];
        host.effects.listen(effects.add);
        host
          ..dispatch(const OpenQuestion(free))
          ..dispatch(const SetTimer(10));
        clock = 5000;
        async.elapse(const Duration(seconds: 5));
        host.dispatch(const PauseTimer(paused: true));
        clock = 60000;
        async.elapse(const Duration(seconds: 55));
        expect(host.state.timer!.running, isTrue);
        expect(effects.whereType<SoundEffect>().map((e) => e.key), isNot(contains(effectTimesUp)));
        host.dispatch(const PauseTimer(paused: false));
        clock = 64000;
        async.elapse(const Duration(seconds: 4));
        expect(host.state.timer!.running, isTrue, reason: 'a second still left');
        clock = 65100;
        async.elapse(const Duration(milliseconds: 1100));
        expect(host.state.timer!.running, isFalse);
        expect(effects.whereType<SoundEffect>().map((e) => e.key), contains(effectTimesUp));
        host.dispose();
      });
    });
  });

  test('an information screen\'s clock pauses the same way', () {
    final info = GameContent.assemble(
      id: 'game',
      game: const {'name': 'Show'},
      groups: const {
        'break': {'name': 'Break', 'categoryGroupType': 'category_info', 'categoryGroupIndex': 0, 'timer': 300},
      },
      categories: const {},
      questions: const {},
    );
    var s = reduce(fixtureState(), const SelectGroup('break'), info, now: 0).state;
    expect(s.timer!.endsAtMillis, 300000);
    s = reduce(s, const PauseTimer(paused: true), info, now: 100000).state;
    expect(s.timer!.paused, isTrue);
    s = reduce(s, const PauseTimer(paused: false), info, now: 160000).state;
    expect((s.timer!.paused, s.timer!.endsAtMillis), (false, 360000));
  });

  group('the devices\' answer round', () {
    SessionState round() => apply(
          apply(fixtureState(), const OpenQuestion(estimate), 0),
          const OpenAnswers(CompanionSpec(kind: CompanionKind.text, timerSeconds: 60)),
          0,
        );

    test('pauses and runs on; answers still come in while paused', () {
      var s = apply(round(), const PauseTimer(paused: true), 20000);
      expect((s.answerRound!.timerPaused, s.answerRound!.open), (true, true));
      s = apply(s, const SubmitAnswer('red', PlayerAnswer(text: '12')), 30000);
      s = apply(s, const PauseTimer(paused: false), 50000);
      expect((s.answerRound!.timerPaused, s.answerRound!.endsAtMillis, s.answerRound!.heldMillis), (false, 90000, 30000));
      expect(s.answerRound!.openedAtMillis, 0, reason: 'lock-in times still count from the start');
    });

    test('pause goes to the round, not to a question clock beside it', () {
      var s = apply(round(), const SetTimer(120), 0);
      s = apply(s, const PauseTimer(paused: true), 10000);
      expect((s.answerRound!.timerPaused, s.timer!.paused), (true, false));
    });

    test('less time: off a deadline ahead, never into the past; not without one', () {
      var s = apply(round(), const ExtendAnswers(-30), 10000);
      expect(s.answerRound!.endsAtMillis, 30000);
      s = apply(s, const ExtendAnswers(-60), 20000);
      expect(s.answerRound!.endsAtMillis, 20000);
      final unlimited = apply(round(), const ExtendAnswers(null), 1000);
      expect(accepts(unlimited, const ExtendAnswers(-30), 2000), isFalse);
      final locked = apply(round(), const LockAnswers(), 1000);
      expect(accepts(locked, const ExtendAnswers(-30), 2000), isFalse);
    });

    test('more or less time while paused stays paused; no limit, locking or editing again ends the pause', () {
      final paused = apply(round(), const PauseTimer(paused: true), 20000);
      var s = apply(paused, const ExtendAnswers(30), 70000);
      expect((s.answerRound!.timerPaused, s.answerRound!.endsAtMillis), (true, 90000), reason: 'on top of the deadline, not from now');
      s = apply(s, const ExtendAnswers(-120), 71000);
      expect((s.answerRound!.timerPaused, s.answerRound!.endsAtMillis), (true, 20000));
      expect(apply(paused, const ExtendAnswers(null), 30000).answerRound!.timerPaused, isFalse);
      final locked = apply(paused, const LockAnswers(), 30000);
      expect(locked.answerRound!.pausedAtMillis, isNull);
      final again = apply(apply(locked, const ExtendAnswers(60), 40000), const LockAnswers(), 41000);
      expect(apply(again, const UnlockAnswers(), 42000).answerRound!.timerPaused, isFalse);
      expect(apply(locked, const ExtendAnswers(60), 40000).answerRound!.timerPaused, isFalse, reason: 'a fresh clock runs');
    });

    test('kept as it is when the state is saved and sent to the devices', () {
      final s = apply(round(), const PauseTimer(paused: true), 20000);
      final back = SessionState.fromJson(s.toJson()).answerRound!;
      expect((back.pausedAtMillis, back.endsAtMillis), (20000, 60000));
      final view = PublicView(publicView(s, game, teamId: 'red'));
      expect((view.answersPausedAt, view.answersEndAt, view.answersHeld), (20000, 60000, 0));
    });

    test('the host locks nothing while paused, and locks once it runs out after', () {
      fakeAsync((async) {
        var clock = 0;
        final host = SessionHost(initial: fixtureState(), game: game, clock: () => clock);
        host
          ..dispatch(const OpenQuestion(estimate))
          ..dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.text, timerSeconds: 10)));
        clock = 5000;
        async.elapse(const Duration(seconds: 5));
        host.dispatch(const PauseTimer(paused: true));
        clock = 60000;
        async.elapse(const Duration(seconds: 55));
        expect(host.state.answerRound!.open, isTrue);
        host.dispatch(const PauseTimer(paused: false));
        clock = 66000;
        async.elapse(const Duration(seconds: 6));
        expect(host.state.answerRound!.open, isFalse);
        host.dispose();
      });
    });
  });

  test('only the gamemaster pauses', () {
    expect(mayIssue(const Sender(Role.player, teamId: 'red'), const PauseTimer(paused: true)), isFalse);
    expect(Command.fromJson(const PauseTimer(paused: true).toJson()), isA<PauseTimer>().having((c) => c.paused, 'paused', isTrue));
  });
}
