import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

import 'fixture.dart';

void main() {
  final text = gameAsText(GameContent.fromJson(fixtureGame().toJson()));

  test('groups and categories in play order, under the game name', () {
    expect(text, startsWith('Fixture\n'));
    final order = ['══ Round 1 ══', '── First ──', '── Second ──', '══ Finale ══', '── Feud ──'].map(text.indexOf).toList();
    expect(order, everyElement(greaterThanOrEqualTo(0)));
    expect(order, [...order]..sort());
  });

  test('questions by rising points, with their answers', () {
    final first = text.substring(text.indexOf('── First ──'), text.indexOf('── Second ──'));
    expect(first, contains('100 / -50: Capital of France?\n  Answer: Paris\n'));
    expect(first.indexOf('Capital of France?'), lessThan(first.indexOf('Name the song')));
    expect(first, contains('300 / -150: Name the song [sound]'));
    expect(first, contains('200: How many?\n  No buzzers\n'));
    expect(first, contains("400: What is 3+5?\n  On the teams' devices: whiteboard, 30 s\n  Answer: 8\n"));
  });

  test('each type writes out what belongs to it', () {
    expect(text, contains('  A) a\n  B) b  ✓\n  C) c\n  D) d\n'));
    expect(text, contains('  1. hint 1 [picture]\n  2. hint 2\n  3. hint 3 [picture]\n'));
    expect(text, contains('  50 %  apple\n  30 %  banana\n  20 %  cherry\n'));
  });

  test('a single question on its own', () {
    final q = fixtureGame().question(abcd)!;
    expect(questionAsText(q), '100 / -100: Pick one\n  A) a\n  B) b  ✓\n  C) c\n  D) d\n');
  });
}
