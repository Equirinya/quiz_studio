import 'package:quiz_show/game/game.dart';

const puzzle = QuestionRef('cx', 'puzzle');

const groups = [
  {'name': 'Fruit', 'words': ['Apple', 'Pear', 'Plum', 'Fig']},
  {'name': 'Planets', 'words': ['Mars', 'Venus', 'Earth', 'Saturn']},
  {'name': 'Card games', 'words': ['Bridge', 'Poker', 'Snap', 'Rummy']},
  {'name': '___ Pie', 'words': ['Cherry', 'Humble', 'Shepherd', 'Pork']},
];

/// One wheel group with a Connections question worth 400.
GameContent connectionsGame({int? timer, int mistakes = 3, bool lock = true}) => GameContent.assemble(
      id: 'cg',
      game: {'name': 'Connections'},
      groups: {
        'g': {'name': 'Round', 'categoryGroupType': 'category_wheel', 'categoryGroupIndex': 0},
      },
      categories: {
        'cx': {'name': 'Words', 'categoryGroup': 'g', 'categoryIndex': 0, 'active': true},
      },
      questions: {
        'cx': {
          'puzzle': {
            'type': 'connections',
            'question': 'Find four groups of four',
            'pointsPlus': 400,
            'connections': groups,
            'companion': {'timer': ?timer, 'mistakes': mistakes, if (!lock) 'lock': false},
          },
        },
      },
    );

/// Places in the shown order of the words of group [level].
List<int> placesOf(int level, {String seed = 'cx/puzzle'}) {
  final order = connectionsOrder(seed);
  return [for (var i = 0; i < 4; i++) order.indexOf(level * 4 + i)];
}
