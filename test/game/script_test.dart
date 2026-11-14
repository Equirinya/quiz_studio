import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

GameContent _game({Map<String, dynamic> game = const {}, Map<String, Map<String, dynamic>>? categories, Map<String, Map<String, Map<String, dynamic>>>? questions}) =>
    GameContent.assemble(
      id: 'g',
      game: game,
      groups: {
        'r1': {'name': 'Round 1', 'categoryGroupIndex': 0},
        'r2': {'name': 'Round 2', 'categoryGroupIndex': 1},
      },
      categories: categories ??
          {
            'history': {'name': 'History', 'categoryGroup': 'r1', 'categoryIndex': 0},
            'music': {'name': 'Music', 'categoryGroup': 'r1', 'categoryIndex': 1},
            'final': {'name': 'Final', 'categoryGroup': 'r2', 'categoryIndex': 0},
          },
      questions: questions ??
          {
            'history': {
              'h2': {'type': 'free', 'question': 'Who built it?\nMore text', 'pointsPlus': 200, 'questionIndex': 1},
              'h1': {'type': 'free', 'question': 'When was Rome founded?', 'pointsPlus': 100, 'questionIndex': 0},
            },
            'music': {
              'm1': {'type': 'free', 'question': 'Name the song', 'pointsPlus': 100},
            },
          },
    );

void main() {
  group('storage', () {
    test('older games without a script load with an empty one', () {
      final game = _game();
      final script = GameScript.of(game);
      expect(script.texts, isEmpty);
      expect(script.text(GameScript.introKey), '');
      expect(script.hasTextFor(game), isFalse);
    });

    test('junk in the stored field is ignored', () {
      expect(GameScript.fromStored('nope').texts, isEmpty);
      expect(GameScript.fromStored({'intro': 3, 'q_h1': 'ok'}).texts, {'q_h1': 'ok'});
    });

    test('round trip through the game document and the JSON for the controller', () {
      final texts = {'intro': '# Welcome\n**Hi** {red}all{/}', 'c_history': 'Story time', 'q_h1': '*Read slowly*'};
      final game = _game(game: {'name': 'Show', GameScript.field: texts});
      expect(GameScript.of(game).texts, texts);
      final again = GameContent.fromJson(game.toJson());
      expect(GameScript.of(again).texts, texts);
      expect(GameScript.of(again).hasTextFor(again), isTrue);
      expect(GameScript(texts).toMap(), texts);
      expect(GameScript(const {'intro': ''}).toMap(), isEmpty);
    });

    test('a section is saved on its own', () {
      const script = GameScript({'intro': 'a'});
      expect(script.updateFor('q_abc123', 'text'), {'script.q_abc123': 'text'});
      expect(script.updateFor('q_odd.id', 'text'), {
        'script': {'intro': 'a', 'q_odd.id': 'text'},
      });
    });
  });

  group('dividers follow the game', () {
    List<String> keys(GameContent game) => [for (final s in GameScript.sections(game)) s.key];

    test('intro, then each category with its questions in playing order', () {
      final game = _game();
      expect(keys(game), ['intro', 'c_history', 'q_h1', 'q_h2', 'c_music', 'q_m1', 'c_final']);
      final sections = GameScript.sections(game);
      expect(sections[1].kind, ScriptSectionKind.category);
      expect(sections[1].title, 'History');
      expect(sections[3].title, 'Who built it?');
      expect(sections[3].points, 200);
      expect(sections[6].groupId, 'r2');
    });

    test('reordered, renamed and deleted questions; text stays with its question', () {
      final script = GameScript.fromStored({'q_h1': 'about Rome', 'q_h2': 'about building', 'c_music': 'play loud'});
      final changed = _game(
        categories: {
          // Music now comes first.
          'history': {'name': 'Ancient history', 'categoryGroup': 'r1', 'categoryIndex': 1},
          'music': {'name': 'Music', 'categoryGroup': 'r1', 'categoryIndex': 0},
        },
        questions: {
          'history': {
            'h2': {'type': 'free', 'question': 'Who built it?', 'pointsPlus': 200, 'questionIndex': 0},
            'h3': {'type': 'free', 'question': 'New one', 'pointsPlus': 300, 'questionIndex': 1},
          },
          'music': {},
        },
      );
      expect(keys(changed), ['intro', 'c_music', 'c_history', 'q_h2', 'q_h3']);
      final sections = GameScript.sections(changed);
      expect(sections[2].title, 'Ancient history');
      expect(script.text(sections[3].key), 'about building');
      expect(script.text(sections[4].key), '');
      expect(script.text(sections[1].key), 'play loud');
    });

    test('long question texts are shortened for the divider', () {
      final title = GameScript.questionTitle(Question(id: 'q', type: QuestionType.free, text: 'x' * 100));
      expect(title.length, lessThanOrEqualTo(60));
      expect(title, endsWith('…'));
    });
  });

  group('where the script opens', () {
    final game = _game();

    test('at the open question, else its category, else the board, else the intro', () {
      expect(GameScript.targetKey(game, current: const QuestionRef('history', 'h2')), 'q_h2');
      expect(GameScript.targetKey(game, current: const QuestionRef('history', 'gone')), 'c_history');
      expect(GameScript.targetKey(game, groupId: 'r2'), 'c_final');
      expect(GameScript.targetKey(game, groupId: 'r1'), 'c_history');
      expect(GameScript.targetKey(game), 'intro');
      expect(GameScript.targetKey(game, groupId: 'nope'), 'intro');
    });

    test('jumps the first time, stays when the section is already close', () {
      bool stays(double? last, double top, double bottom) =>
          scriptStaysPut(lastOffset: last, viewport: 600, sectionTop: top, sectionBottom: bottom);
      // Never opened: jump.
      expect(stays(null, 0, 100), isFalse);
      // Divider in view.
      expect(stays(1000, 1000, 1200), isTrue);
      expect(stays(1000, 1400, 1600), isTrue);
      // Divider at the very bottom of the view or below it: jump.
      expect(stays(1000, 1550, 1700), isFalse);
      expect(stays(1000, 3000, 3200), isFalse);
      // Far above: jump.
      expect(stays(5000, 1000, 1200), isFalse);
      // Reading inside a long section: stay.
      expect(stays(1000, 400, 2000), isTrue);
      // Only the section's last lines at the top of the view: jump back to it.
      expect(stays(1000, 400, 1100), isFalse);
    });
  });

  group('format', () {
    test('headings, bullets, bold, italic and colours', () {
      final h = parseScriptLine('# Title');
      expect(h.kind, ScriptLineKind.heading1);
      expect(h.plainText, 'Title');
      expect(parseScriptLine('## Sub').kind, ScriptLineKind.heading2);
      expect(parseScriptLine('- point').kind, ScriptLineKind.bullet);

      final line = parseScriptLine('Say **loud** and *soft* {red}stop{/} now');
      expect(line.plainText, 'Say loud and soft stop now');
      final loud = line.runs.firstWhere((r) => r.text == 'loud');
      expect(loud.bold, isTrue);
      expect(line.runs.firstWhere((r) => r.text == 'soft').italic, isTrue);
      final stop = line.runs.firstWhere((r) => r.text == 'stop');
      expect(stop.color, ScriptColor.red);
      expect(line.runs.firstWhere((r) => r.text == ' now').color, isNull);
    });

    test('markers and text together are exactly what was written', () {
      for (final text in ['# **a** *b* {blue}c{/}', '5 * 3 = 15', '{nope}x{/}', '**open', '- {green}**x', '']) {
        expect(parseScriptLine(text).runs.map((r) => r.text).join(), text, reason: text);
      }
    });

    test('a star before a space or unknown braces are plain text; formats end with the line', () {
      expect(parseScriptLine('5 * 3').plainText, '5 * 3');
      expect(parseScriptLine('{nope}x{/}').plainText, '{nope}x{/}');
      final lines = parseScript('**bold\nplain');
      expect(lines[1].runs.single.bold, isFalse);
    });
  });
}
