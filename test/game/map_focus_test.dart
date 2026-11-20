import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

/// On a map, the category picked on the controller brings its cards, sounds
/// and music before any of its questions is open.
void main() {
  GameContent game() => GameContent.assemble(
        id: 'game',
        game: const {'name': 'Show', 'musicBackground': 'game.mp3'},
        groups: const {
          'map': {'name': 'Map', 'categoryGroupType': 'category_map', 'categoryGroupIndex': 0},
          'ring': {'name': 'Ring', 'categoryGroupType': 'category_wheel', 'categoryGroupIndex': 1},
        },
        categories: const {
          'forest': {
            'name': 'Forest',
            'categoryGroup': 'map',
            'categoryIndex': 0,
            'active': true,
            'musicBackground': 'forest.mp3',
            'cards': [
              {'title': 'Owl', 'text': 'Hoo'},
            ],
          },
          'sea': {'name': 'Sea', 'categoryGroup': 'ring', 'categoryIndex': 0, 'active': true, 'musicBackground': 'sea.mp3'},
        },
        questions: const {
          'forest': {
            'q': {'type': 'free', 'question': 'Tallest tree?', 'pointsPlus': 100},
          },
          'sea': {
            'q': {'type': 'free', 'question': 'Deepest sea?', 'pointsPlus': 100},
          },
        },
      );

  test('the category picked on the map counts without an open question', () {
    final g = game();
    expect(g.soundsFor(groupId: 'map', focus: 'forest').slots['musicBackground'], 'forest.mp3');
    expect(g.cardsFor(groupId: 'map', focus: 'forest').map((card) => card.title), contains('Owl'));
  });

  test("until one is picked there, the map's first category is in focus", () {
    final g = game();
    expect(g.soundsFor(groupId: 'map').slots['musicBackground'], 'forest.mp3');
    expect(g.cardsFor(groupId: 'map', focus: 'sea').map((card) => card.title), contains('Owl'));
  });

  test('resetting a question or the whole show puts every map back on its first category', () {
    final g = game();
    const start = SessionState(gameId: 'game', groupId: 'map', played: {'sea/q'}, boardFocus: 'sea');
    final unmarked = reduce(start, const UnmarkPlayed(QuestionRef('sea', 'q')), g).state;
    expect(unmarked.boardFocus, isNull);
    expect(reduce(start, const ClearSessionData(), g).state.boardFocus, isNull);
  });

  test('only on a map, and only for the board shown', () {
    final g = game();
    // A ring has no picked category.
    expect(g.soundsFor(groupId: 'ring', focus: 'sea').slots['musicBackground'], 'game.mp3');
    // Left over from the map while another board is shown.
    expect(g.soundsFor(groupId: 'ring', focus: 'forest').slots['musicBackground'], 'game.mp3');
  });

  test('picking it on the controller is what sets it', () {
    final g = game();
    const start = SessionState(gameId: 'game', groupId: 'map', teams: [Team(id: 'red', name: 'Red')]);
    final s = reduce(start, const FocusCategory('forest'), g).state;
    expect(g.soundsFor(ref: s.current, groupId: s.groupId, focus: s.boardFocus).slots['musicBackground'], 'forest.mp3');
  });
}
