import 'package:quiz_show/game/game.dart';

const buzzerRound = QuestionRef('r', 'buzz');
const devicesRound = QuestionRef('r', 'devices');

/// One category with a Fragenhagel of each kind.
GameContent rapidGame() => GameContent.assemble(
      id: 'game',
      game: {'name': 'Rapid'},
      groups: {
        'g': {'name': 'Round', 'categoryGroupIndex': 0},
      },
      categories: {
        'r': {'name': 'Rapid', 'categoryGroup': 'g', 'categoryIndex': 0},
      },
      questions: {
        'r': {
          'buzz': {
            'type': 'rapidFire',
            'question': 'Capitals',
            'pointsPlus': 10,
            'pointsMinus': 5,
            'rapidFire': {
              'mode': 'buzzer',
              'progress': 'flux',
              'items': [
                {'question': 'France?', 'answer': 'Paris', 'music': 'marseillaise.mp3'},
                {'question': 'Italy?', 'answer': 'Rome', 'image': 'rome.png'},
                {'question': 'Spain?', 'answer': 'Madrid'},
              ],
            },
          },
          'devices': {
            'type': 'rapidFire',
            'question': 'True or false',
            'pointsPlus': 10,
            'pointsMinus': 0,
            'rapidFire': {
              'mode': 'devices',
              'items': [
                {'question': 'The sun is a star', 'true': true},
                {'question': 'Bats are birds', 'true': false},
              ],
            },
          },
        },
      },
    );

const matchingRound = QuestionRef('m', 'films');

/// A matching question: films (one only as a picture) and their years.
GameContent matchingGame() => GameContent.assemble(
      id: 'game',
      game: {'name': 'Films'},
      groups: {
        'g': {'name': 'Round', 'categoryGroupIndex': 0},
      },
      categories: {
        'm': {'name': 'Cinema', 'categoryGroup': 'g', 'categoryIndex': 0},
      },
      questions: {
        'm': {
          'films': {
            'type': 'matching',
            'question': 'Which year did each film come out?',
            'pointsPlus': 40,
            'companion': {'timer': 90, 'lock': true},
            'matching': {
              'pairs': [
                {'left': {'text': 'Back to the Future'}, 'right': {'text': '1985'}},
                {'left': {'text': 'Jurassic Park'}, 'right': {'text': '1993'}},
                {'left': {'text': '', 'image': 'poster.png'}, 'right': {'text': '1977'}},
                {'left': {'text': 'Titanic'}, 'right': {'text': '1997'}},
              ],
            },
          },
        },
      },
    );
