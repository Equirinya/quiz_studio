import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

/// Scoring rules that do not fit how the teams answer.
void main() {
  Question free(Map<String, dynamic> data) => Question.fromMap('q', {'type': 'free', 'question': 'How tall?', 'pointsPlus': 300, ...data});

  test('fitting rules have nothing to warn about', () {
    expect(scoringIssues(free({})), isEmpty);
    expect(scoringIssues(free({'rankStep': 100})), isEmpty);
    expect(scoringIssues(free({'rankStep': 100, 'companion': {'kind': 'text'}})), isEmpty);
    expect(scoringIssues(free({'rankStep': 100, 'byTime': true, 'companion': {'kind': 'whiteboard'}})), isEmpty);
    expect(
      scoringIssues(free({'rankStep': 100, 'closest': true, 'companion': {'kind': 'slider', 'min': 0, 'max': 500, 'solution': 330}})),
      isEmpty,
    );
    // Bets take over from the places.
    expect(scoringIssues(free({'wager': true, 'rankStep': 100, 'closest': true})), isEmpty);
  });

  test('by closeness needs a number with a right value', () {
    expect(scoringIssues(free({'rankStep': 100, 'closest': true})), [ScoringIssue.closenessNeedsNumber]);
    expect(scoringIssues(free({'rankStep': 100, 'closest': true, 'companion': {'kind': 'text'}})), [ScoringIssue.closenessNeedsNumber]);
    expect(scoringIssues(free({'rankStep': 100, 'closest': true, 'companion': {'kind': 'number'}})), [ScoringIssue.closenessNeedsSolution]);
  });

  test('by speed needs a screen teams lock in on', () {
    expect(scoringIssues(free({'rankStep': 100, 'byTime': true})), [ScoringIssue.speedNeedsDevices]);
    expect(
      scoringIssues(free({'rankStep': 100, 'byTime': true, 'companion': {'kind': 'text', 'lock': false}})),
      [ScoringIssue.speedNeedsLockIn],
    );
  });

  test('by order on the devices without locking in goes only by tapping', () {
    expect(scoringIssues(free({'rankStep': 100, 'companion': {'kind': 'text', 'lock': false}})), [ScoringIssue.orderNeedsLockIn]);
  });
}
