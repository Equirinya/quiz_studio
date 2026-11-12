import 'package:quiz_show/game/game.dart';

import 'fixture.dart';

const raced = QuestionRef('c1', 'raced');
const mime = QuestionRef('c1', 'mime');

/// The fixture game with two "by order" questions: one typed on the devices,
/// one with nothing on them (e.g. charades on stage).
GameContent scoringGame() {
  final base = fixtureGame();
  return GameContent.assemble(
    id: 'game',
    game: const {'name': 'Scoring'},
    groups: const {
      'g1': {'name': 'Round 1', 'categoryGroupType': 'category_wheel', 'categoryGroupIndex': 0},
    },
    categories: const {
      'c1': {'name': 'First', 'categoryGroup': 'g1', 'categoryIndex': 0, 'active': true},
    },
    questions: {
      'c1': {
        'raced': {
          'type': 'free',
          'question': 'Which film is it?',
          'noBuzzer': true,
          'pointsPlus': 600,
          'pointsMinus': 50,
          'rankStep': 100,
          'companion': {'kind': 'text', 'timer': 60},
        },
        'mime': {'type': 'free', 'question': 'Charades', 'noBuzzer': true, 'pointsPlus': 300, 'rankStep': 100},
        'free': base.question(free)!.data,
      },
    },
  );
}

SessionState scoringState() => const SessionState(
  gameId: 'game',
  teams: [
    Team(id: 'red', name: 'Red'),
    Team(id: 'blue', name: 'Blue'),
    Team(id: 'green', name: 'Green'),
  ],
);
