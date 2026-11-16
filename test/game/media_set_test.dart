import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

void main() {
  test('several pictures are stored with the first also as image, for older versions', () {
    const media = MediaSet(images: ['a.png', 'b.png'], video: 'v.mp4');
    final map = media.toMap();
    expect(map['image'], 'a.png');
    expect(map['images'], ['a.png', 'b.png']);
    expect(MediaSet.fromMap(map), media);
    // One picture: no list.
    expect(const MediaSet(images: ['a.png']).toMap()['images'], isNull);
  });

  test('a picture changed by an older version wins over a stale list', () {
    final media = MediaSet.fromMap({'image': 'c.png', 'images': ['a.png', 'b.png']});
    expect(media.images, ['c.png']);
  });

  test("a Fragenhagel item plays its own clip or sound, else the question's", () {
    final question = Question.fromMap('q', {
      'type': 'rapidFire',
      'music': 'theme.mp3',
      'rapidFire': {
        'items': [
          {'question': 'one', 'video': 'clip.mp4', 'image': 'a.png', 'images': ['a.png', 'b.png']},
          {'question': 'two', 'image': 'c.png'},
        ],
      },
    });
    expect(question.rapidFire!.items.first.images, ['a.png', 'b.png']);
    expect(question.videoAt(0), 'clip.mp4');
    expect(question.musicAt(0), isNull);
    expect(question.videoAt(1), isNull);
    expect(question.musicAt(1), 'theme.mp3');
    expect(question.mediaPaths, containsAll(['clip.mp4', 'a.png', 'b.png', 'c.png', 'theme.mp3']));
  });

  test("last team standing plays the sound of the turn's prompt", () {
    final question = Question.fromMap('q', {
      'type': 'lastStanding',
      'lastStanding': {
        'items': [
          {'question': 'one', 'music': 'one.mp3'},
          {'question': 'two'},
        ],
      },
    });
    const play = StandingPlay(order: ['red', 'blue', 'green']);
    expect(question.musicAt(-1, const StandingPlay(order: ['red'], started: false)), isNull);
    expect(question.musicAt(-1, play), 'one.mp3');
    expect(question.hasMediaAt(-1, play.withTurn(StandingResult.right)), isFalse);
  });
}
