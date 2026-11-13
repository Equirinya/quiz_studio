import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';

void main() {
  final game = fixtureGame();
  const red = Sender(Role.player, teamId: 'red');

  SessionState open(CompanionSpec spec) {
    final s = reduce(fixtureState(), const OpenQuestion(free), game, now: 0).state;
    return reduce(s, OpenAnswers(spec), game, now: 0).state;
  }

  test('who answers changes while the round runs; at least one team stays', () {
    var s = open(const CompanionSpec(kind: CompanionKind.text));
    s = reduce(s, const SetRoundTeams(['blue']), game).state;
    expect(s.roundTeams.map((t) => t.id), ['blue']);
    expect(reduce(s, const SubmitAnswer('red', PlayerAnswer(text: 'x')), game).accepted, isFalse);
    expect(reduce(s, const SetRoundTeams([]), game).accepted, isFalse);
    s = reduce(s, const SetRoundTeams(['red', 'blue']), game).state;
    expect(s.answerRound!.teams, isEmpty, reason: 'everyone again');
  });

  test('notes: only the chosen teams write them, apart from the round, and they end with the question', () {
    var s = open(const CompanionSpec(kind: CompanionKind.order, options: ['a', 'b']));
    expect(mayIssue(red, const WriteNotes('red', 'x')), isTrue);
    expect(mayIssue(red, const WriteNotes('blue', 'x')), isFalse);
    expect(reduce(s, const WriteNotes('red', 'too early'), game).accepted, isFalse);
    s = reduce(s, const AllowNotes(['red']), game).state;
    s = reduce(s, const WriteNotes('red', 'Bohemian Rhapsody 1200\nNapoleon 300'), game).state;
    expect(reduce(s, const WriteNotes('blue', 'x'), game).accepted, isFalse);
    expect(s.notes, {'red': 'Bohemian Rhapsody 1200\nNapoleon 300'});
    // The sorting round goes on as before.
    expect(s.answerRound!.kind, CompanionKind.order);
    expect(PublicView(publicView(s, game, teamId: 'red')).ownNotes, 'Bohemian Rhapsody 1200\nNapoleon 300');
    expect(PublicView(publicView(s, game, teamId: 'blue')).ownNotes, isNull);
    expect(PublicView(publicView(s, game)).json.toString(), isNot(contains('Napoleon')), reason: 'only the team and the gamemaster');
    expect(SessionState.fromJson(s.toJson()).notes, s.notes);
    s = reduce(s, const CloseQuestion(), game).state;
    expect(s.notesTeams, isEmpty);
    expect(s.notes, isEmpty);
  });

  test('more time: from the end, or from now once it ran out (which reopens), or no limit', () {
    var s = open(const CompanionSpec(kind: CompanionKind.text, timerSeconds: 30));
    expect(s.answerRound!.endsAtMillis, 30000);
    s = reduce(s, const ExtendAnswers(30), game, now: 10000).state;
    expect(s.answerRound!.endsAtMillis, 60000);
    s = reduce(s, const LockAnswers(), game, now: 60000).state;
    s = reduce(s, const ExtendAnswers(60), game, now: 70000).state;
    expect((s.answerRound!.open, s.answerRound!.endsAtMillis), (true, 130000));
    s = reduce(s, const ExtendAnswers(null), game, now: 80000).state;
    expect((s.answerRound!.open, s.answerRound!.endsAtMillis), (true, null));
    expect(reduce(s, const ExtendAnswers(null), game, now: 80000).accepted, isFalse);
  });

  test('locking in early only where the scoring goes by time', () {
    final timed = open(const CompanionSpec(kind: CompanionKind.text, timerSeconds: 30));
    final s = reduce(timed, const SubmitAnswer('red', PlayerAnswer(text: 'x')), game).state;
    expect(canLockIn(s, game), isFalse, reason: 'a timer alone is not enough');
    expect(reduce(s, const LockAnswer('red'), game).accepted, isFalse);
    expect(PublicView(publicView(s, game, teamId: 'red')).lockable, isFalse);
    final racing = reduce(fixtureState(), const OpenQuestion(race), game, now: 0).state;
    expect(canLockIn(racing, game), isTrue);
  });
}
