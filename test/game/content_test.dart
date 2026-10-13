import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';

void main() {
  final game = fixtureGame();

  test('groups, categories and questions are sorted as in v1', () {
    expect(game.groups.map((g) => g.id), ['g1', 'g2']);
    expect(game.groups.first.categories.map((c) => c.id), ['c1', 'c2']);
    // by points, ascending
    expect(game.category('c1')!.questions.map((q) => q.id), ['free', 'estimate', 'song']);
    expect(game.groups.first.type, BoardType.wheel);
    expect(game.groups.last.type, BoardType.display);
  });

  test('inactive categories are left out of play but kept for the editor', () {
    expect(game.category('hidden'), isNull);
    final all = GameContent.assemble(
      id: 'g',
      game: {},
      groups: {},
      categories: {
        'a': {'name': 'A', 'active': false},
      },
      questions: {},
      activeOnly: false,
    );
    expect(all.category('a')!.active, isFalse);
  });

  test('categories without a known group land in the ungrouped group, first', () {
    final loose = GameContent.assemble(
      id: 'g',
      game: {},
      groups: {
        'g1': {'categoryGroupIndex': 0},
      },
      categories: {
        'a': {'name': 'A', 'categoryGroup': 'deleted-group'},
        'b': {'name': 'B', 'categoryGroup': 'g1'},
      },
      questions: {},
    );
    expect(loose.groups.map((g) => g.id), [CategoryGroup.ungroupedId, 'g1']);
    expect(loose.groups.first.isUngrouped, isTrue);
    expect(loose.groupOfCategory('a')!.type, BoardType.wheel);
  });

  test('question fields and derived flags', () {
    expect(game.question(free)!.answerHint, 'Paris');
    expect(game.question(free)!.buzzerable, isTrue);
    expect(game.question(estimate)!.buzzerable, isFalse);
    expect(game.question(song)!.hasMusic, isTrue);
    expect(game.question(abcd)!.maxReveal, 5);
    expect(game.question(reveal)!.maxReveal, 4);
    expect(game.question(reveal)!.hasInformationImages, isTrue);
    expect(game.question(feud)!.defaultJudging, isFalse);
    expect(game.question(feud)!.percentages, [50.0, 30.0, 20.0]);
    expect(game.question(const QuestionRef('c1', 'missing')), isNull);
  });

  test('unknown question types and malformed fields do not throw', () {
    final q = Question.fromMap('q', {'type': 'hologram', 'question': 5, 'pointsPlus': 'many', 'answers': 'abc'});
    expect(q.type, QuestionType.unsupported);
    expect(q.text, '');
    expect(q.pointsPlus, 0);
    expect(q.answers, isEmpty);
  });

  test('sounds resolve from the most specific level', () {
    expect(game.soundsFor().slots[musicBackground], 'bg.mp3');
    expect(game.soundsFor(groupId: 'g2').slots[musicBackground], 'finale.mp3');
    expect(game.soundsFor(ref: feud).slots[musicBackground], 'finale.mp3');
    expect(game.soundsFor(ref: free).effects[effectAnswerWrong], 'wrong.mp3');
    expect(game.soundsFor(ref: reveal).effects[effectAnswerWrong], 'question-wrong.mp3');
    expect(game.soundsFor(ref: reveal).effects['airhorn'], 'horn.mp3');
  });

  test('mediaPaths lists every file to cache and skips empty slots', () {
    expect(
      game.mediaPaths,
      {'bg.mp3', 'wrong.mp3', 'horn.mp3', 'finale.mp3', 'g1.png', 'song.mp3', '1.png', '3.png', 'question-wrong.mp3'},
    );
  });

  test('QuestionRef round-trips through its key', () {
    expect(QuestionRef.tryParse(free.key), free);
    expect(QuestionRef.tryParse('no-slash'), isNull);
    expect(QuestionRef.tryParse('/x'), isNull);
    expect(QuestionRef.tryParse(3), isNull);
  });
}
