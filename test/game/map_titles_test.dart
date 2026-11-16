import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

void main() {
  test("a question's map title is its own name, else its first line", () {
    expect(Question.fromMap('a', {'question': 'Which river?\nIt is long.'}).shortTitle, 'Which river?');
    expect(Question.fromMap('b', {'question': 'Which river?', 'mapTitle': 'Rivers'}).shortTitle, 'Rivers');
  });
}
