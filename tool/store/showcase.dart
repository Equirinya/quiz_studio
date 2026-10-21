// A quiz with real-looking content for the README, the website and the
// store listings. Only used by tool/store_screenshots_test.dart.
import 'dart:math' as math;

import 'package:quiz_show/game/game.dart';

const science = QuestionRef('science', 'moons');
const spider = QuestionRef('warmup', 'spider');
const beach = QuestionRef('feud', 'beach');

const showcaseTeams = [
  Team(id: 'owls', name: 'Know-It-Owls', points: 700),
  Team(id: 'quizzards', name: 'Quizzards', points: 500),
  Team(id: 'pants', name: 'Smarty Pants', points: 300),
];

const _mapNames = ['Warm-up', 'Movies', 'Geography', 'Music', 'Science'];
const _mapIds = ['warmup', 'movies', 'geography', 'music', 'science'];
const _texts = {
  'music/q2': 'Which band recorded "Bohemian Rhapsody"?',
  'movies/q2': 'Which film won the first Oscar for Best Picture?',
  'geography/q1': 'Which river flows through Vienna, Budapest and Belgrade?',
};

const _labels = {
  'warmup': ['Animals', 'Food', 'Sports', 'Spider'],
  'movies': ['Quotes', 'Actors', 'Oscars', 'Sequels'],
  'geography': ['Capitals', 'Rivers', 'Flags', 'Borders'],
  'music': ['Intros', 'Bands', 'Lyrics', 'Charts'],
  'science': ['Elements', 'Space', 'Moons', 'Inventions'],
};

Map<String, dynamic> _plain(String category, int i) => {
      'type': 'free',
      'question': _texts['$category/q$i'] ?? '${_labels[category]![i]} question',
      'description': _labels[category]![i],
      'pointsPlus': (i + 1) * 100,
      'pointsMinus': (i + 1) * 50,
    };

GameContent showcaseGame() => GameContent.assemble(
      id: 'showcase',
      game: {'name': 'Friday quiz night'},
      groups: {
        'road': {
          'name': 'Road to the finale',
          'categoryGroupType': 'category_map',
          'categoryGroupIndex': 0,
          'mapLayout': {
            'follows': {'geography': 'warmup', 'music': 'geography', 'science': 'movies'},
            'decorations': [
              {'type': 'title', 'text': 'Friday\nquiz night', 'x': 0.14, 'y': 0.13, 'size': 1.4},
              {'type': 'line', 'x1': 0.04, 'y1': 0.25, 'x2': 0.25, 'y2': 0.25},
            ],
          },
        },
        'final': {'name': 'Finale', 'categoryGroupType': 'category_display', 'categoryGroupIndex': 1},
      },
      categories: {
        for (var i = 0; i < _mapIds.length; i++)
          _mapIds[i]: {'name': _mapNames[i], 'categoryGroup': 'road', 'categoryIndex': i, 'active': true},
        'feud': {'name': 'Survey says', 'categoryGroup': 'final', 'categoryIndex': 0, 'active': true},
      },
      questions: {
        for (final c in _mapIds)
          c: {
            for (var i = 0; i < 4; i++)
              if (!(c == 'science' && i == 2) && !(c == 'warmup' && i == 3)) 'q$i': _plain(c, i),
            if (c == 'science')
              'moons': {
                'type': 'abcd',
                'question': 'Which planet has the most known moons?',
                'description': 'Moons',
                'answers': ['Jupiter', 'Saturn', 'Uranus', 'Neptune'],
                'answersCorrect': [false, true, false, false],
                'answerHint': 'Saturn, with well over 200',
                'pointsPlus': 300,
                'pointsMinus': 150,
              },
            if (c == 'warmup')
              'spider': {
                'type': 'free',
                'question': 'How many legs does a spider have?',
                'description': 'Spider',
                'answerHint': '8',
                'noBuzzer': true,
                'pointsPlus': 400,
                'companion': {'kind': 'whiteboard', 'timer': 45},
              },
          },
        'feud': {
          'beach': {
            'type': 'feud',
            'question': 'Name something people take to the beach',
            'information': ['Towel', 'Sunscreen', 'Sunglasses', 'Umbrella', 'A book'],
            'informationPercentage': [38, 27, 15, 12, 8],
            'pointsPlus': 1000,
          },
        },
      },
    );

/// The board halfway through the evening.
const playedSoFar = {
  'warmup/q0', 'warmup/q1', 'warmup/q2', //
  'movies/q0', 'movies/q1', 'geography/q0',
};

SessionState showcaseState() => const SessionState(gameId: 'showcase', teams: showcaseTeams, groupId: 'road', played: playedSoFar);

List<(double, double)> _ellipse(double cx, double cy, double rx, double ry, {double from = 0, double to = 1}) => [
      for (var i = 0; i <= 40; i++)
        (cx + rx * math.sin((from + (to - from) * i / 40) * 2 * math.pi), cy - ry * math.cos((from + (to - from) * i / 40) * 2 * math.pi)),
    ];

/// "8", written by hand.
String drawnEight() => encodeDrawing([_ellipse(0.5, 0.33, 0.11, 0.16), _ellipse(0.5, 0.68, 0.14, 0.19)]);

/// "6", written by hand.
String drawnSix() => encodeDrawing([
      [(0.6, 0.16), (0.52, 0.22), (0.45, 0.32), (0.4, 0.45), (0.37, 0.58), (0.37, 0.7)],
      _ellipse(0.5, 0.68, 0.13, 0.17),
    ]);
