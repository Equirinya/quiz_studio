import 'package:quiz_show/game/game.dart';

const buzzed = QuestionRef('c1', 'buzzed');
const picked = QuestionRef('c1', 'picked');
const guessed = QuestionRef('c1', 'guessed');
const feudBet = QuestionRef('c1', 'feudBet');
const films = QuestionRef('c1', 'films');
const pushUps = QuestionRef('c1', 'pushUps');
const timed = QuestionRef('c1', 'timed');

/// Questions played with bets: one buzzed, one picked on the devices, one
/// estimated on the devices, and a Survey duel that can't be played with
/// bets.
GameContent bettingGame() => GameContent.assemble(
  id: 'game',
  game: const {'name': 'Bets'},
  groups: const {
    'g1': {'name': 'Round 1', 'categoryGroupType': 'category_wheel', 'categoryGroupIndex': 0},
  },
  categories: const {
    'c1': {'name': 'All in', 'categoryGroup': 'g1', 'categoryIndex': 0, 'active': true},
  },
  questions: const {
    'c1': {
      'buzzed': {'type': 'free', 'question': 'Capital of Peru?', 'answerHint': 'Lima', 'pointsPlus': 200, 'wager': true},
      'picked': {
        'type': 'abcd',
        'question': 'Pick one',
        'answers': ['a', 'b', 'c', 'd'],
        'answersCorrect': [false, true, false, false],
        'pointsPlus': 300,
        'wager': true,
        'companion': {'kind': 'choice', 'timer': 20},
      },
      'guessed': {
        'type': 'free',
        'question': 'How many?',
        'noBuzzer': true,
        'pointsPlus': 100,
        'wager': true,
        'companion': {'kind': 'number', 'solution': 100},
      },
      'films': {
        'type': 'free',
        'question': 'Name science fiction films',
        'pointsPlus': 50,
        'amountBet': {'prompt': 'How many science fiction films can you name?', 'max': 10},
        'companion': {'kind': 'list', 'timer': 60, 'listRows': 3},
      },
      'pushUps': {
        'type': 'free',
        'question': 'Push-ups, go!',
        'pointsPlus': 10,
        'pointsMinus': 10,
        'noPhoneBuzzer': true,
        'timer': 30,
        'amountBet': {'prompt': 'How many push-ups can you do in 30 seconds?', 'max': 50},
      },
      'timed': {'type': 'free', 'question': 'Quick: capital of Chile?', 'pointsPlus': 100, 'timer': 20},
      'feudBet': {
        'type': 'feud',
        'question': 'Name a fruit',
        'information': ['apple'],
        'informationPercentage': [100],
        'pointsPlus': 100,
        'wager': true,
      },
    },
  },
);

/// Red has 500 points, Blue none, Green is in debt.
SessionState bettingState() => const SessionState(
  gameId: 'game',
  teams: [
    Team(id: 'red', name: 'Red', points: 500),
    Team(id: 'blue', name: 'Blue'),
    Team(id: 'green', name: 'Green', points: -50),
  ],
);
