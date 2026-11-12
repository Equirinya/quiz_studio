import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

const biopics = QuestionRef('c', 'biopics');
const disney = QuestionRef('c', 'disney');

GameContent standingGame({TurnOrder order = TurnOrder.teams}) => GameContent.assemble(
  id: 'game',
  game: const {'name': 'Standing'},
  groups: const {
    'g': {'name': 'Round', 'categoryGroupIndex': 0},
  },
  categories: const {
    'c': {'name': 'Biopics', 'categoryGroup': 'g', 'categoryIndex': 0},
  },
  questions: {
    'c': {
      'biopics': {
        'type': 'lastStanding',
        'question': 'Does this star have a biopic?',
        'pointsPlus': 300,
        'lastStanding': LastStanding(
          order: order,
          items: const [
            RapidItem(question: 'Freddie Mercury', answer: 'Yes: Bohemian Rhapsody'),
            RapidItem(question: 'Bruno Mars', answer: 'No'),
            RapidItem(question: 'Elton John', answer: 'Yes: Rocketman'),
          ],
        ).toMap(),
      },
      'disney': {'type': 'lastStanding', 'question': 'Name a Disney film', 'pointsPlus': 200},
    },
  },
);

SessionState teams() => const SessionState(
  gameId: 'game',
  teams: [
    Team(id: 'red', name: 'Red', points: 100),
    Team(id: 'blue', name: 'Blue', points: 300),
    Team(id: 'green', name: 'Green', points: 200),
  ],
);

SessionState play(List<Command> commands, {SessionState? from, GameContent? game}) {
  var state = from ?? teams();
  game ??= standingGame();
  for (final command in commands) {
    final result = reduce(state, command, game);
    if (!result.accepted) throw StateError('rejected: ${command.toJson()}');
    state = result.state;
  }
  return state;
}

void main() {
  test('the turns go round; a wrong answer puts a team out; the last one left wins', () {
    var s = play(const [OpenQuestion(biopics)]);
    expect(s.standing!.current, 'red');
    s = play(const [TakeTurn(StandingResult.right)], from: s);
    expect(s.standing!.current, 'blue');
    s = play(const [TakeTurn(StandingResult.out)], from: s);
    expect(s.standing!.current, 'green');
    expect(s.standing!.out, ['blue']);
    // A free miss: wrong, but Green stays in.
    s = play(const [TakeTurn(StandingResult.miss)], from: s);
    expect(s.standing!.current, 'red');
    expect(s.standing!.inPlay, ['red', 'green']);
    s = play(const [TakeTurn(StandingResult.out)], from: s);
    expect(s.standing!.winner, 'green');
    expect(s.standing!.current, isNull);
    expect(s.team('green')!.points, 500, reason: 'the points go up at once');
    expect(s.scoreLog.last.delta, 300);
    expect(reduce(s, const TakeTurn(StandingResult.right), standingGame()).accepted, isFalse);
  });

  test('taking a turn back takes the win and its points back too', () {
    var s = play(const [OpenQuestion(biopics), TakeTurn(StandingResult.out), TakeTurn(StandingResult.out)]);
    expect((s.standing!.winner, s.team('green')!.points), ('green', 500));
    s = play(const [UndoTurn()], from: s);
    expect((s.standing!.winner, s.standing!.current, s.team('green')!.points), (null, 'blue', 200));
  });

  test('the order: as listed, most points first, or fewest first', () {
    expect(play(const [OpenQuestion(biopics)]).standing!.order, ['red', 'blue', 'green']);
    expect(play(const [OpenQuestion(biopics)], game: standingGame(order: TurnOrder.mostPoints)).standing!.order, ['blue', 'green', 'red']);
    expect(play(const [OpenQuestion(biopics)], game: standingGame(order: TurnOrder.fewestPoints)).standing!.order, [
      'red',
      'green',
      'blue',
    ]);
  });

  test('the devices see whose turn it is and the prompt, never its answer', () {
    final s = play(const [OpenQuestion(biopics), TakeTurn(StandingResult.right)]);
    final view = publicView(s, standingGame())['question'] as Map;
    expect(view['standing'], {
      'order': ['red', 'blue', 'green'],
      'out': <String>[],
      'current': 'blue',
      'prompt': 'Bruno Mars',
    });
    expect(view.toString(), isNot(contains('Rocketman')));
  });

  test('without prompts every turn is the question itself; nobody buzzes', () {
    final s = play(const [OpenQuestion(disney)]);
    expect(s.standing!.current, 'red');
    expect(buzzersOpen(s, standingGame()), isFalse);
    expect((publicView(s, standingGame())['question'] as Map)['standing'], isNot(contains('prompt')));
  });

  test('a team that leaves drops out of the turns; the play survives storage', () {
    var s = play(const [OpenQuestion(biopics), TakeTurn(StandingResult.right), RemoveTeam('blue')]);
    expect(s.standing!.order, ['red', 'green']);
    expect(s.standing!.current, 'green');
    s = SessionState.fromJson(s.toJson());
    expect(s.standing!.turns.single, ('red', StandingResult.right));
  });
}
