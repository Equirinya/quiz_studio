import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/games/widgets/script_format.dart';

void main() {
  const mark = TextStyle(backgroundColor: Colors.yellow);
  const current = TextStyle(backgroundColor: Colors.orange);

  String marked(InlineSpan span, TextStyle style) {
    final buffer = StringBuffer();
    span.visitChildren((child) {
      if (child is TextSpan && child.style == style) buffer.write('[${child.text}]');
      return true;
    });
    return buffer.toString();
  }

  test('matches are marked across the pieces of a formatted text, the text itself unchanged', () {
    const span = TextSpan(children: [
      TextSpan(text: 'Welcome to the '),
      TextSpan(text: 'quiz', style: TextStyle(fontWeight: FontWeight.bold)),
      TextSpan(text: '\n'),
      TextSpan(text: 'Quiz time!'),
    ]);
    // "the quiz" runs over two pieces; "Quiz" is the second match.
    final result = highlightSpan(span, const [TextRange(start: 11, end: 19), TextRange(start: 20, end: 24)], current: 1, mark: mark, currentMark: current);
    expect(result.toPlainText(), span.toPlainText());
    expect(marked(result, mark), '[the ][quiz]');
    expect(marked(result, current), '[Quiz]');
  });

  test('the controller marks only while there are matches', () {
    final controller = ScriptTextController(text: 'abc abc');
    var notified = 0;
    controller.addListener(() => notified++);
    controller.setHighlights(const [TextRange(start: 0, end: 3)], 0);
    controller.setHighlights(const [TextRange(start: 0, end: 3)], 0);
    expect(notified, 1);
    controller.setHighlights(const [], null);
    expect(notified, 2);
    controller.dispose();
  });
}
