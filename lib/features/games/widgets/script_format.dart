import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// How a [ScriptColor] looks, readable on light and dark backgrounds.
Color scriptColor(ScriptColor color, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (color) {
    ScriptColor.red => dark ? Colors.red.shade300 : Colors.red.shade700,
    ScriptColor.orange => dark ? Colors.orange.shade300 : Colors.orange.shade800,
    ScriptColor.yellow => dark ? Colors.yellow.shade400 : Colors.amber.shade800,
    ScriptColor.green => dark ? Colors.green.shade300 : Colors.green.shade700,
    ScriptColor.blue => dark ? Colors.blue.shade300 : Colors.blue.shade700,
    ScriptColor.purple => dark ? Colors.purple.shade200 : Colors.purple.shade600,
    ScriptColor.grey => dark ? Colors.grey.shade400 : Colors.grey.shade600,
  };
}

TextStyle _lineStyle(ScriptLineKind kind, TextStyle base) => switch (kind) {
  ScriptLineKind.heading1 => base.copyWith(fontSize: (base.fontSize ?? 14) * 1.5, fontWeight: FontWeight.w700, height: 1.4),
  ScriptLineKind.heading2 => base.copyWith(fontSize: (base.fontSize ?? 14) * 1.25, fontWeight: FontWeight.w700, height: 1.4),
  _ => base,
};

TextStyle _runStyle(ScriptRun run, TextStyle line, Brightness brightness) => line.copyWith(
  fontWeight: run.bold ? FontWeight.w700 : null,
  fontStyle: run.italic ? FontStyle.italic : null,
  color: run.color == null ? null : scriptColor(run.color!, brightness),
);

/// The script text as formatted spans. While [editing], the formatting signs
/// stay in (faint), so the text is exactly what is typed; for reading they
/// are left out and bullet points get a dot.
TextSpan scriptSpan(String text, {required TextStyle base, required Brightness brightness, bool editing = false}) {
  final lines = parseScript(text);
  final faint = (base.color ?? (brightness == Brightness.dark ? Colors.white : Colors.black)).withValues(alpha: 0.35);
  return TextSpan(
    style: base,
    children: [
      for (final (index, line) in lines.indexed) ...[
        if (index > 0) const TextSpan(text: '\n'),
        if (!editing && line.kind == ScriptLineKind.bullet) TextSpan(text: '•  ', style: _lineStyle(line.kind, base)),
        for (final run in line.runs)
          if (run.marker)
            editing
                ? TextSpan(text: run.text, style: _lineStyle(line.kind, base).copyWith(color: faint, fontWeight: FontWeight.w400, fontStyle: FontStyle.normal))
                : const TextSpan()
          else
            TextSpan(text: run.text, style: _runStyle(run, _lineStyle(line.kind, base), brightness)),
      ],
    ],
  );
}

/// A text controller that shows the script's formatting while it is typed.
class ScriptTextController extends TextEditingController {
  ScriptTextController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    // While a word is being composed (IMEs), keep Flutter's own underline.
    if (withComposing && value.isComposingRangeValid) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    return scriptSpan(text, base: style ?? const TextStyle(), brightness: Theme.of(context).brightness, editing: true);
  }

  /// Puts [before] and [after] around the selection, or the word typed next.
  void wrapSelection(String before, String after) {
    final selection = this.selection;
    if (!selection.isValid) {
      value = TextEditingValue(text: '$text$before$after', selection: TextSelection.collapsed(offset: text.length + before.length));
      return;
    }
    final selected = selection.textInside(text);
    final next = selection.textBefore(text) + before + selected + after + selection.textAfter(text);
    value = TextEditingValue(
      text: next,
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: selection.start + before.length)
          : TextSelection(baseOffset: selection.start + before.length, extentOffset: selection.start + before.length + selected.length),
    );
  }

  /// Sets or removes [prefix] ("# ", "## ", "- ") on the line of the cursor;
  /// another line prefix is replaced.
  void toggleLinePrefix(String prefix) {
    final selection = this.selection;
    final at = selection.isValid ? selection.start : text.length;
    final start = text.lastIndexOf('\n', at == 0 ? 0 : at - 1) + 1;
    final line = text.substring(start);
    var removed = 0;
    for (final existing in ['## ', '# ', '- ']) {
      if (line.startsWith(existing)) {
        removed = existing.length;
        if (existing == prefix) prefix = '';
        break;
      }
    }
    final next = text.substring(0, start) + prefix + text.substring(start + removed);
    final shift = prefix.length - removed;
    value = TextEditingValue(
      text: next,
      selection: selection.isValid
          ? TextSelection(
              baseOffset: (selection.baseOffset + shift).clamp(start, next.length),
              extentOffset: (selection.extentOffset + shift).clamp(start, next.length),
            )
          : TextSelection.collapsed(offset: next.length),
    );
  }

  /// Takes every formatting sign out of the selected lines' text.
  void clearFormatting() {
    final selection = this.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final start = text.lastIndexOf('\n', selection.start == 0 ? 0 : selection.start - 1) + 1;
    var end = text.indexOf('\n', selection.end);
    if (end < 0) end = text.length;
    final cleaned = parseScript(text.substring(start, end)).map((line) => line.plainText).join('\n');
    final next = text.substring(0, start) + cleaned + text.substring(end);
    value = TextEditingValue(text: next, selection: TextSelection(baseOffset: start, extentOffset: start + cleaned.length));
  }
}

/// The fixed line between sections: "──── Category: History ────".
class ScriptDivider extends StatelessWidget {
  const ScriptDivider({super.key, required this.section, this.highlight = false});

  final ScriptSection section;

  /// The section the show is at right now.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final isCategory = section.kind == ScriptSectionKind.category;
    final label = switch (section.kind) {
      ScriptSectionKind.intro => l10n.scriptIntro,
      ScriptSectionKind.category => l10n.scriptCategory(section.title.isEmpty ? l10n.unnamed : section.title),
      ScriptSectionKind.question => l10n.scriptQuestion(
        [if ((section.points ?? 0) != 0) '${section.points}', if (section.title.isNotEmpty) section.title].join(' · '),
      ),
    };
    final color = highlight ? scheme.primary : (isCategory ? scheme.onSurface : scheme.onSurfaceVariant);
    final line = Expanded(child: Divider(thickness: isCategory ? 2 : 1, color: color.withValues(alpha: highlight ? 1 : 0.5)));
    return Padding(
      padding: EdgeInsets.only(top: isCategory ? 20 : 12, bottom: 4),
      child: Row(
        children: [
          SizedBox(width: isCategory ? 8 : 24, child: Divider(thickness: isCategory ? 2 : 1, color: color.withValues(alpha: highlight ? 1 : 0.5))),
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (isCategory ? theme.textTheme.titleSmall : theme.textTheme.labelLarge)?.copyWith(
                    color: color,
                    fontWeight: isCategory || highlight ? FontWeight.w700 : null,
                  ),
                ),
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}

/// A section's text for reading: formatted, selectable, nothing when empty.
class ScriptText extends StatelessWidget {
  const ScriptText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge ?? const TextStyle();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SelectableText.rich(scriptSpan(trimmed, base: base, brightness: theme.brightness)),
    );
  }
}
