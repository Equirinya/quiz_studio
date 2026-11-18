import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

/// An information screen: a board without categories, with a text, a
/// picture and a timer that starts as it is shown.
void main() {
  GameContent game() => GameContent.assemble(
        id: 'game',
        game: const {'name': 'Show'},
        groups: const {
          'g1': {'name': 'Round 1', 'categoryGroupType': 'category_wheel', 'categoryGroupIndex': 0},
          'break': {
            'name': 'Break',
            'categoryGroupType': 'category_info',
            'categoryGroupIndex': 1,
            'text': 'Back in ten minutes',
            'imagePath': 'coffee.png',
            'timer': 600,
          },
        },
        categories: const {
          'c1': {'name': 'First', 'categoryGroup': 'g1', 'categoryIndex': 0, 'active': true},
        },
        questions: const {
          'c1': {
            'q': {'type': 'free', 'question': 'Capital of France?', 'pointsPlus': 100},
          },
        },
      );

  const teams = SessionState(gameId: 'game', teams: [Team(id: 'red', name: 'Red')]);

  test('it is read as an information screen', () {
    final screen = game().group('break')!;
    expect(screen.isInfo, isTrue);
    expect(screen.text, 'Back in ten minutes');
    expect(screen.imagePath, 'coffee.png');
    expect(screen.timerSeconds, 600);
    expect(game().group('g1')!.timerSeconds, isNull);
  });

  test('showing it starts its clock; going back to a board stops it', () {
    final g = game();
    var s = reduce(teams, const SelectGroup('break'), g, now: 1000).state;
    expect(s.timer!.endsAtMillis, 601000);

    // More time, and started again from the beginning.
    s = reduce(s, const SetTimer(60), g, now: 5000).state;
    expect(s.timer!.endsAtMillis, 661000);
    s = reduce(s, const SelectGroup('break'), g, now: 9000).state;
    expect(s.timer!.endsAtMillis, 609000);

    s = reduce(s, const SelectGroup('g1'), g, now: 10000).state;
    expect(s.timer, isNull);
    expect(reduce(s, const SetTimer(30), g, now: 11000).accepted, isFalse, reason: 'a board has no clock of its own');
  });

  test('it shows up in the game as text', () {
    expect(gameAsText(game()), contains('Back in ten minutes'));
  });

  test('minutes off and on; without a clock, more time puts one up', () {
    final g = game();
    var s = reduce(teams, const SelectGroup('break'), g, now: 0).state;
    s = reduce(s, const SetTimer(-60), g, now: 0).state;
    expect(s.timer!.endsAtMillis, 540000);
    s = reduce(s, const SetTimer(15 * 60), g, now: 0).state;
    expect(s.timer!.endsAtMillis, 1440000);
    // Never into the past: at nothing left the time is up.
    s = reduce(s, const SetTimer(-60 * 60), g, now: 1000).state;
    expect(s.timer!.endsAtMillis, 1000);

    s = reduce(s, const SetTimer(null), g, now: 2000).state;
    expect(s.timer, isNull);
    expect(reduce(s, const SetTimer(-60), g, now: 2000).accepted, isFalse, reason: 'nothing to take time off');
    s = reduce(s, const SetTimer(60), g, now: 2000).state;
    expect(s.timer!.endsAtMillis, 62000);
  });
}
