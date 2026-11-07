import 'package:quiz_show/game/game.dart';

const free = QuestionRef('c1', 'free');
const estimate = QuestionRef('c1', 'estimate');
const song = QuestionRef('c1', 'song');
const sum = QuestionRef('c1', 'sum');
const abcd = QuestionRef('c2', 'abcd');
const reveal = QuestionRef('c2', 'reveal');
const feud = QuestionRef('c3', 'feud');

/// Two groups: g1 (wheel) with c1 and c2, g2 (display) with c3.
GameContent fixtureGame() => GameContent.assemble(
      id: 'game',
      game: {
        'name': 'Fixture',
        'musicBackground': 'bg.mp3',
        'musicEffects': {'musicEffectAnswerWrong': 'wrong.mp3', 'airhorn': 'horn.mp3'},
      },
      groups: {
        'g2': {'name': 'Finale', 'categoryGroupType': 'category_display', 'categoryGroupIndex': 1, 'musicBackground': 'finale.mp3'},
        'g1': {'name': 'Round 1', 'categoryGroupType': 'category_wheel', 'categoryGroupIndex': 0, 'imagePath': 'g1.png'},
      },
      categories: {
        'c2': {'name': 'Second', 'categoryGroup': 'g1', 'categoryIndex': 1, 'active': true},
        'c1': {'name': 'First', 'categoryGroup': 'g1', 'categoryIndex': 0, 'active': true},
        'c3': {'name': 'Feud', 'categoryGroup': 'g2', 'categoryIndex': 0, 'active': true},
        'hidden': {'name': 'Hidden', 'categoryGroup': 'g1', 'categoryIndex': 2, 'active': false},
      },
      questions: {
        'c1': {
          'song': {'type': 'free', 'question': 'Name the song', 'music': 'song.mp3', 'pointsPlus': 300, 'pointsMinus': 150},
          'free': {'type': 'free', 'question': 'Capital of France?', 'answerHint': 'Paris', 'pointsPlus': 100, 'pointsMinus': 50},
          'estimate': {'type': 'free', 'question': 'How many?', 'noBuzzer': true, 'pointsPlus': 200},
          'sum': {
            'type': 'free',
            'question': 'What is 3+5?',
            'answerHint': '8',
            'noBuzzer': true,
            'pointsPlus': 400,
            'companion': {'kind': 'whiteboard', 'timer': 30},
          },
        },
        'c2': {
          'abcd': {
            'type': 'abcd',
            'question': 'Pick one',
            'answers': ['a', 'b', 'c', 'd'],
            'answersCorrect': [false, true, false, false],
            'pointsPlus': 100,
            'pointsMinus': 100,
          },
          'reveal': {
            'type': 'progressingReveal',
            'question': 'Who is it?',
            'information': ['hint 1', 'hint 2', 'hint 3'],
            'informationImage': ['1.png', '', '3.png'],
            'informationMusic': ['', '', ''],
            'pointsPlus': 200,
            'musicEffects': {'musicEffectAnswerWrong': 'question-wrong.mp3'},
          },
        },
        'c3': {
          'feud': {
            'type': 'feud',
            'question': 'Name a fruit',
            'information': ['apple', 'banana', 'cherry'],
            'informationPercentage': [50, 30, 20],
            'pointsPlus': 1000,
          },
        },
        'hidden': {
          'x': {'type': 'free', 'question': 'never shown', 'pointsPlus': 1},
        },
      },
    );

/// Two teams, the fixture game loaded.
SessionState fixtureState() => const SessionState(
      gameId: 'game',
      teams: [Team(id: 'red', name: 'Red'), Team(id: 'blue', name: 'Blue')],
    );

/// Applies commands in order, failing loudly if one is rejected.
SessionState run(SessionState state, List<Command> commands, [GameContent? game]) {
  game ??= fixtureGame();
  for (final command in commands) {
    final result = reduce(state, command, game);
    if (!result.accepted) throw StateError('rejected: ${command.toJson()} in phase ${state.phase.name}');
    state = result.state;
  }
  return state;
}

int points(SessionState state, String teamId) => state.team(teamId)!.points;
