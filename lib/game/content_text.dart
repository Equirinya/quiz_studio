/// A game written out as plain text, to paste into a document or a chat.
library;

import 'companion.dart';
import 'content.dart';
import 'matching.dart';
import 'rapid_fire.dart';

String _number(double value) => value % 1 == 0 ? value.toInt().toString() : value.toString();

String questionAsText(Question q) {
  final out = StringBuffer();
  out.write('${q.pointsPlus}');
  if (q.pointsMinus > 0) out.write(' / -${q.pointsMinus}');
  out.write(': ${q.text}');
  final media = [if (q.image != null) 'picture', if (q.hasMusic) 'sound'];
  if (media.isNotEmpty) out.write(' [${media.join(', ')}]');
  out.writeln();
  if ((q.description ?? '').isNotEmpty) out.writeln('  Label: ${q.description}');
  switch (q.type) {
    case QuestionType.abcd:
      for (final (i, answer) in q.answers.indexed) {
        final right = q.answersCorrect.elementAtOrNull(i) ?? false;
        out.writeln('  ${String.fromCharCode(0x41 + i)}) $answer${right ? '  ✓' : ''}');
      }
    case QuestionType.progressingReveal:
      for (final (i, information) in q.information.indexed) {
        final picture = (q.informationImages.elementAtOrNull(i) ?? '').isNotEmpty;
        out.writeln('  ${i + 1}. $information${picture ? ' [picture]' : ''}');
      }
    case QuestionType.feud:
      for (final (i, information) in q.information.indexed) {
        final value = q.percentages.elementAtOrNull(i);
        final shown = value == null ? '-' : '${_number(value)}${q.absoluteValues ? '' : ' %'}';
        out.writeln('  $shown  $information');
      }
    case QuestionType.connections:
      const colours = ['yellow', 'green', 'blue', 'purple'];
      for (final (i, group) in q.connectionGroups.indexed) {
        out.writeln('  ${colours[i]}: ${group.name} – ${group.words.join(', ')}');
      }
    case QuestionType.rapidFire:
      final rapid = q.rapidFire ?? const RapidFire();
      final devices = rapid.mode == RapidMode.devices;
      out.writeln(devices ? '  Right or wrong on the teams\' devices' : '  Teams buzz');
      for (final (i, item) in rapid.items.indexed) {
        final media = [if (item.image != null) 'picture', if (item.music != null) 'sound'];
        final solution = devices ? (item.isTrue ? 'right' : 'wrong') : item.answer;
        out.writeln('  ${i + 1}. ${item.question}${solution.isEmpty ? '' : ' – $solution'}${media.isEmpty ? '' : ' [${media.join(', ')}]'}');
      }
    case QuestionType.matching:
      final pairs = q.matching ?? const Matching();
      for (final pair in pairs.pairs) {
        String side(MatchSide s) => [if (s.text.isNotEmpty) s.text, if (s.image != null) '[picture]'].join(' ');
        out.writeln('  ${side(pair.left)} = ${side(pair.right)}');
      }
    case QuestionType.free:
      if (q.noBuzzer && q.companion == null) out.writeln('  No buzzers');
    case QuestionType.unsupported:
      break;
  }
  final companion = q.type == QuestionType.rapidFire || q.type == QuestionType.matching ? null : q.companion;
  if (companion != null && q.type == QuestionType.connections) {
    final timer = companion.timerSeconds == null ? '' : ', ${companion.timerSeconds} s';
    out.writeln('  ${companion.mistakes} mistakes allowed$timer');
  } else if (companion != null) {
    final timer = companion.timerSeconds == null ? '' : ', ${companion.timerSeconds} s';
    out.writeln('  On the teams\' devices: ${companion.kind.name}$timer');
    if (companion.kind == CompanionKind.order) out.writeln('  Right order: ${companion.options.join(' → ')}');
    if (companion.kind == CompanionKind.match) {
      for (final (i, option) in companion.options.indexed) {
        out.writeln('  $option = ${companion.targets.elementAtOrNull(i) ?? ''}');
      }
    }
    if (companion.solution != null) out.writeln('  Solution: ${formatNumber(companion.solution!, unit: companion.unit)}');
  }
  if ((q.answerHint ?? '').isNotEmpty) out.writeln('  Answer: ${q.answerHint}');
  return out.toString();
}

/// The whole game: groups, categories and questions with their answers.
String gameAsText(GameContent game) {
  final out = StringBuffer()..writeln(game.name.isEmpty ? 'Unnamed game' : game.name);
  for (final group in game.groups) {
    if (group.categories.isEmpty && group.type != BoardType.display) continue;
    if (!group.isUngrouped) {
      out
        ..writeln()
        ..writeln('══ ${group.name} ══');
    }
    for (final category in group.categories) {
      out
        ..writeln()
        ..writeln('── ${category.name}${category.active ? '' : ' (not in play)'} ──');
      for (final question in category.questions) {
        out.write(questionAsText(question));
      }
    }
  }
  return out.toString();
}
