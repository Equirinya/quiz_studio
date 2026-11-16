import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

GameContent picturesGame() => GameContent.assemble(
  id: 'game',
  game: const {'name': 'Pictures'},
  groups: const {
    'g': {'name': 'Round', 'categoryGroupIndex': 0},
  },
  categories: const {
    'c': {'name': 'Art', 'categoryGroup': 'g', 'categoryIndex': 0},
  },
  questions: const {
    'c': {
      'steps': {'type': 'free', 'question': 'Who painted these?', 'image': 'a.png', 'images': ['a.png', 'b.png', 'c.png'], 'imagesOneByOne': true},
      'side': {'type': 'free', 'question': 'Same?', 'image': 'a.png', 'images': ['a.png', 'b.png']},
      'rapid': {
        'type': 'rapidFire',
        'question': 'Quick',
        'rapidFire': {
          'items': [
            {'question': 'one', 'image': 'a.png', 'images': ['a.png', 'b.png'], 'imagesOneByOne': true},
            {'question': 'two', 'image': 'c.png', 'images': ['c.png', 'd.png'], 'imagesOneByOne': true},
          ],
        },
      },
    },
  },
);

void main() {
  final game = picturesGame();
  SessionState run(SessionState s, List<Command> commands) {
    for (final command in commands) {
      s = reduce(s, command, game).state;
    }
    return s;
  }

  test('the gamemaster steps through pictures shown one after another', () {
    var s = run(const SessionState(gameId: 'game'), [const OpenQuestion(QuestionRef('c', 'steps'))]);
    expect(s.imageFocus, 0);
    s = run(s, [const ImageFocus(1), const ImageFocus(1)]);
    expect(s.imageFocus, 2);
    // Not past the last one, nor before the first.
    expect(reduce(s, const ImageFocus(1), game).accepted, isFalse);
    s = run(s, [const ImageFocus(-1)]);
    expect(s.imageFocus, 1);
  });

  test('pictures side by side have nothing to step through', () {
    final s = run(const SessionState(gameId: 'game'), [const OpenQuestion(QuestionRef('c', 'side'))]);
    expect(reduce(s, const ImageFocus(1), game).accepted, isFalse);
  });

  test('each Fragenhagel item starts at its first picture', () {
    var s = run(const SessionState(gameId: 'game'), [const OpenQuestion(QuestionRef('c', 'rapid')), const Reveal(1)]);
    expect(s.revealed, 0);
    s = run(s, [const ImageFocus(1)]);
    expect(s.imageFocus, 1);
    s = run(s, [const Reveal(1)]);
    expect(s.revealed, 1);
    expect(s.imageFocus, 0);
  });

  test('the setting is stored with the pictures', () {
    const media = MediaSet(images: ['a.png', 'b.png'], oneByOne: true);
    expect(media.toMap()['imagesOneByOne'], isTrue);
    expect(MediaSet.fromMap(media.toMap()), media);
    expect(const MediaSet(images: ['a.png']).toMap()['imagesOneByOne'], isNull);
  });
}
