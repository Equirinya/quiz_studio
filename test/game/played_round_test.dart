import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';

/// A question closed as played keeps its answers, ratings and points, and
/// can be reopened with them; clearing the session starts it over.
void main() {
  final game = fixtureGame();
  var now = 1000;
  SessionHost newHost([SessionState? initial, Map<String, PlayedRound> rounds = const {}]) {
    final host = SessionHost(initial: initial ?? fixtureState(), game: game, clock: () => now, rounds: rounds);
    addTearDown(host.dispose);
    return host;
  }

  void play(SessionHost host, List<Command> commands) {
    for (final command in commands) {
      expect(host.dispatch(command), isTrue, reason: 'rejected: ${command.toJson()}');
    }
  }

  /// Whiteboards on `sum`: red right and on screen (points given), blue
  /// wrong and never shown.
  void playSum(SessionHost host) => play(host, [
    const OpenQuestion(sum),
    const SubmitAnswer('red', PlayerAnswer(drawing: '1,1 2,2')),
    const SubmitAnswer('blue', PlayerAnswer(drawing: '5,5 6,6')),
    const LockAnswers(),
    const RevealAnswer('red'),
    const RateAnswer('red', correct: true),
    const RateAnswer('blue', correct: false),
  ]);

  test('closing as played keeps the whiteboards, ratings and the points given', () {
    final host = newHost();
    final changes = <StoredRoundsChange>[];
    host.roundChanges.listen(changes.add);
    playSum(host);
    expect(points(host.state, 'red'), 400);
    play(host, [const CloseQuestion()]);

    expect(host.state.played, contains(sum.key));
    expect(host.state.storedRounds, {sum.key});
    final kept = host.rounds[sum.key]!;
    expect(kept.answerRound!.answers['red']!.drawing, '1,1 2,2');
    expect(kept.answerRound!.answers['blue']!.drawing, '5,5 6,6');
    expect(kept.answerRound!.open, isFalse);
    expect(kept.answerRound!.revealed, ['red']);
    expect(kept.results.verdicts, {'red': true, 'blue': false});
    expect(kept.results.given['red'], 400);
    expect(changes.single.rounds.keys, [sum.key]);
    expect(changes.single.cleared, isFalse);
  });

  test('reopened with its answers it is as it was left, and nothing counts twice', () {
    final host = newHost();
    playSum(host);
    play(host, [const CloseQuestion()]);
    now = 50000;
    play(host, [const OpenQuestion(sum, restore: true)]);

    final s = host.state;
    expect(s.current, sum);
    expect(s.played, isNot(contains(sum.key)), reason: 'being played again');
    expect(s.answerRound!.answers['blue']!.drawing, '5,5 6,6');
    expect(s.answerRound!.revealed, ['red']);
    expect(s.answerRound!.open, isFalse);
    expect(s.answerRound!.endsAtMillis, isNull);
    expect(s.timer, isNull);
    expect(s.results.verdicts['red'], isTrue);
    expect(points(s, 'red'), 400);

    // Blue's rating changed and closed again: blue gets its points, red
    // keeps 400 rather than getting them a second time.
    play(host, [const RateAnswer('blue', correct: true), const CloseQuestion()]);
    expect(points(host.state, 'red'), 400);
    expect(points(host.state, 'blue'), 400);
    expect(host.state.played, contains(sum.key));
    expect(host.rounds[sum.key]!.results.given['red'], 400);

    // Taken back on the reopened question: the points go too.
    play(host, [const OpenQuestion(sum, restore: true), const RateAnswer('red', correct: false)]);
    expect(points(host.state, 'red'), 0);
  });

  test('answering can be opened again on the reopened question, the answers still there', () {
    final host = newHost();
    playSum(host);
    play(host, [const CloseQuestion(), const OpenQuestion(sum, restore: true), const UnlockAnswers()]);
    expect(host.state.answerRound!.open, isTrue);
    expect(host.state.answerRound!.answers['blue']!.drawing, '5,5 6,6');
  });

  test('only a question that left something behind can come back with it', () {
    final host = newHost();
    expect(host.dispatch(const OpenQuestion(sum, restore: true)), isFalse, reason: 'never played');
    // A buzzer question: its points are on the board, nothing to keep.
    play(host, [const OpenQuestion(free), const Buzz('red'), const Judge(correct: true)]);
    expect(host.state.played, contains(free.key));
    expect(host.state.storedRounds, isEmpty);
    expect(host.dispatch(const OpenQuestion(free, restore: true)), isFalse);
  });

  test('taken off without marking it played keeps what was kept before', () {
    final host = newHost();
    playSum(host);
    play(host, [const CloseQuestion(), const UnmarkPlayed(sum)]);
    expect(host.state.storedRounds, {sum.key}, reason: 'it can still be reopened with its answers');
    play(host, [const OpenQuestion(sum), const CloseQuestion(markPlayed: false)]);
    expect(host.rounds[sum.key]!.answerRound!.answers, hasLength(2));
  });

  test('opening the next question closes the last one as played, keeping it', () {
    final host = newHost();
    playSum(host);
    play(host, [const OpenQuestion(free)]);
    expect(host.state.storedRounds, {sum.key});
    expect(host.rounds[sum.key]!.results.given['red'], 400);
  });

  test('clearing the session: points to 0, nothing played or kept, the same teams', () {
    final host = newHost();
    final changes = <StoredRoundsChange>[];
    playSum(host);
    play(host, [const CloseQuestion(), const OpenQuestion(free), const Buzz('blue'), const Judge(correct: true)]);
    host.roundChanges.listen(changes.add);
    expect(points(host.state, 'blue'), 100);

    play(host, [const ClearSessionData()]);
    final s = host.state;
    expect([for (final team in s.teams) (team.id, team.name, team.points)], [('red', 'Red', 0), ('blue', 'Blue', 0)]);
    expect(s.played, isEmpty);
    expect(s.storedRounds, isEmpty);
    expect(s.scoreLog, isEmpty, reason: 'no "-400" for starting over');
    expect(s.current, isNull);
    expect(host.rounds, isEmpty);
    expect(changes.single.cleared, isTrue);
  });

  test('a question still open while clearing is closed without being kept', () {
    final host = newHost();
    playSum(host);
    play(host, [const ClearSessionData()]);
    expect(host.state.current, isNull);
    expect(host.state.answerRound, isNull);
    expect(host.rounds, isEmpty);
  });

  test('another game drops what was kept', () {
    final host = newHost();
    playSum(host);
    play(host, [const CloseQuestion(), const SetGame('other')]);
    expect(host.state.storedRounds, isEmpty);
    expect(host.rounds, isEmpty);
  });

  test('a host started with stored rounds can reopen them', () {
    final first = newHost();
    playSum(first);
    play(first, [const CloseQuestion()]);
    // As the session document and the rounds collection store them.
    final state = SessionState.fromJson(jsonDecode(jsonEncode(first.state.toJson())) as Map<String, dynamic>);
    final rounds = {
      for (final MapEntry(:key, :value) in first.rounds.entries) key: PlayedRound.fromJson(jsonDecode(jsonEncode(value.toJson())))!,
    };
    expect(state.storedRounds, {sum.key});

    final again = newHost(state, rounds);
    play(again, [const OpenQuestion(sum, restore: true)]);
    expect(again.state.answerRound!.answers['red']!.drawing, '1,1 2,2');
    expect(again.state.results.given, {'red': 400});
  });

  test('the commands travel, and players may not send them', () {
    final open = Command.fromJson(const OpenQuestion(sum, restore: true).toJson())! as OpenQuestion;
    expect(open.restore, isTrue);
    expect((Command.fromJson(const OpenQuestion(sum).toJson())! as OpenQuestion).restore, isFalse);
    expect(Command.fromJson(const ClearSessionData().toJson()), isA<ClearSessionData>());
    expect(mayIssue(const Sender(Role.player, teamId: 'red'), const ClearSessionData()), isFalse);
    expect(mayIssue(const Sender(Role.player, teamId: 'red'), const OpenQuestion(sum, restore: true)), isFalse);
  });
}
