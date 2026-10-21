import 'package:quiz_show/game/game.dart';

const films = QuestionRef('tc', 'films');

/// "Name the five most popular films", in [mode]; the third answer is worth
/// 300, the others the question's 100.
GameContent topAnswersGame({TopAnswersMode mode = TopAnswersMode.buzzer, int? timer}) => GameContent.assemble(
  id: 'tg',
  game: {'name': 'Top answers'},
  groups: {
    'g': {'name': 'Round', 'categoryGroupType': 'category_wheel', 'categoryGroupIndex': 0},
  },
  categories: {
    'tc': {'name': 'Films', 'categoryGroup': 'g', 'categoryIndex': 0, 'active': true},
  },
  questions: {
    'tc': {
      'films': {
        'type': 'topAnswers',
        'question': 'Name the five most popular films',
        'pointsPlus': 100,
        'pointsMinus': 50,
        'topAnswers': TopAnswers(
          mode: mode,
          items: const [
            TopAnswer(answer: 'Titanic'),
            TopAnswer(answer: 'Avatar'),
            TopAnswer(answer: 'The Lion King / Lion King', points: 300),
            TopAnswer(answer: 'Star Wars'),
            TopAnswer(answer: 'Jurassic Park'),
          ],
        ).toMap(),
        'companion': {'timer': ?timer},
      },
    },
  },
);

const topTeams = SessionState(
  gameId: 'tg',
  teams: [
    Team(id: 'red', name: 'Red'),
    Team(id: 'blue', name: 'Blue'),
  ],
);
