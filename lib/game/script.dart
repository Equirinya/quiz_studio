import 'content.dart';

/// The gamemaster's script: one long note for the show, written in the game
/// editor and read on the controller.
///
/// It is stored as `script` on the game document, a map of section key to
/// text: [introKey] for what comes before the first category, `c_<id>` for a
/// category and `q_<id>` for a question. Keying by id keeps the text with its
/// question when it is renamed or moved; a deleted question's text is simply
/// no longer shown. [sections] lays them out in the order of the game, one
/// divider each, so the script always follows the game.
///
/// Text is a small markdown subset, see [parseScriptLine].
class GameScript {
  const GameScript(this.texts);

  factory GameScript.of(GameContent game) => GameScript.fromStored(game.data[field]);

  factory GameScript.fromStored(Object? stored) => GameScript({
        if (stored is Map)
          for (final entry in stored.entries)
            if (entry.key is String && entry.value is String) entry.key as String: entry.value as String,
      });

  /// The field on the game document.
  static const field = 'script';
  static const introKey = 'intro';

  static String categoryKey(String categoryId) => 'c_$categoryId';
  static String questionKey(String questionId) => 'q_$questionId';

  /// Section key to text, as stored.
  final Map<String, String> texts;

  String text(String key) => texts[key] ?? '';

  /// Whether anything at all has been written in the sections of [game].
  bool hasTextFor(GameContent game) => sections(game).any((s) => text(s.key).trim().isNotEmpty);

  Map<String, dynamic> toMap() => {
        for (final entry in texts.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value,
      };

  /// The update for the game document that stores [text] in section [key].
  /// One section at a time, so two people writing in different sections do
  /// not overwrite each other. Ids that are no plain names (never the case
  /// for database ids) fall back to writing the whole script.
  Map<String, dynamic> updateFor(String key, String text) {
    if (RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(key)) return {'$field.$key': text};
    return {field: (GameScript({...texts, key: text})).toMap()};
  }

  /// The intro, then every category of [game] followed by its questions, in
  /// playing order.
  static List<ScriptSection> sections(GameContent game) => [
        const ScriptSection(key: introKey, kind: ScriptSectionKind.intro),
        for (final group in game.groups)
          for (final category in group.categories) ...[
            ScriptSection(
              key: categoryKey(category.id),
              kind: ScriptSectionKind.category,
              title: category.name,
              categoryId: category.id,
              groupId: group.id,
            ),
            for (final question in category.questions)
              ScriptSection(
                key: questionKey(question.id),
                kind: ScriptSectionKind.question,
                title: questionTitle(question),
                points: question.boardPoints,
                categoryId: category.id,
                questionId: question.id,
                groupId: group.id,
              ),
          ],
      ];

  /// What a question's divider is called: the first line of its text.
  static String questionTitle(Question question) {
    var title = question.text.trim().split('\n').first.trim();
    if (title.isEmpty) title = (question.description ?? '').trim();
    const max = 60;
    return title.length > max ? '${title.substring(0, max - 1).trimRight()}…' : title;
  }

  /// The section to open the script at: the open question's, else its
  /// category's, else the first category of the board on screen, else the
  /// intro.
  static String targetKey(GameContent game, {QuestionRef? current, String? groupId}) {
    final keys = sections(game).map((s) => s.key).toSet();
    if (current != null) {
      final question = questionKey(current.questionId);
      if (keys.contains(question)) return question;
      final category = categoryKey(current.categoryId);
      if (keys.contains(category)) return category;
    }
    final group = game.group(groupId);
    if (group != null && group.categories.isNotEmpty) return categoryKey(group.categories.first.id);
    return introKey;
  }
}

enum ScriptSectionKind { intro, category, question }

class ScriptSection {
  const ScriptSection({
    required this.key,
    required this.kind,
    this.title = '',
    this.points,
    this.categoryId,
    this.questionId,
    this.groupId,
  });

  final String key;
  final ScriptSectionKind kind;

  /// The category's name or the question's first line.
  final String title;
  final int? points;
  final String? categoryId;
  final String? questionId;
  final String? groupId;
}

/// Whether the script, opened again, stays where it was read last instead of
/// jumping to the target section: it does when the target's divider is
/// already in view (in the top four fifths), or when the reader is inside the
/// target section and it fills at least half the view.
///
/// All values are in scroll pixels; [lastOffset] is null the first time.
bool scriptStaysPut({
  required double? lastOffset,
  required double viewport,
  required double sectionTop,
  required double sectionBottom,
}) {
  if (lastOffset == null) return false;
  final dividerInView = sectionTop >= lastOffset && sectionTop <= lastOffset + viewport * 0.8;
  final readingInside = sectionTop < lastOffset && sectionBottom >= lastOffset + viewport * 0.5;
  return dividerInView || readingInside;
}

// ── format ──────────────────────────────────────────────────────────────────

/// The colours text can have, by the name written in the script.
enum ScriptColor { red, orange, yellow, green, blue, purple, grey }

enum ScriptLineKind { plain, heading1, heading2, bullet }

/// A run of one line, with the format in force. [marker] runs are the
/// formatting signs themselves: the editor shows them faintly, the reading
/// view leaves them out.
class ScriptRun {
  const ScriptRun(this.text, {this.bold = false, this.italic = false, this.color, this.marker = false});

  final String text;
  final bool bold;
  final bool italic;
  final ScriptColor? color;
  final bool marker;

  @override
  String toString() => '${marker ? '~' : ''}"$text"${bold ? ' b' : ''}${italic ? ' i' : ''}${color == null ? '' : ' ${color!.name}'}';
}

class ScriptLine {
  const ScriptLine(this.kind, this.runs);

  final ScriptLineKind kind;

  /// Together exactly the line as written, markers included.
  final List<ScriptRun> runs;

  String get plainText => runs.where((r) => !r.marker).map((r) => r.text).join();
}

/// Reads one line of the script:
///
/// * `# ` and `## ` at the start make a heading, `- ` a bullet point;
/// * `**bold**`, `*italic*` (a `*` followed by a space stays a star);
/// * `{red}coloured{/}` with the names of [ScriptColor].
///
/// Formats end with the line, so a forgotten closing sign never spills over.
ScriptLine parseScriptLine(String line) {
  final runs = <ScriptRun>[];
  var kind = ScriptLineKind.plain;
  var i = 0;
  for (final (prefix, k) in [('## ', ScriptLineKind.heading2), ('# ', ScriptLineKind.heading1), ('- ', ScriptLineKind.bullet)]) {
    if (line.startsWith(prefix)) {
      kind = k;
      runs.add(ScriptRun(prefix, marker: true));
      i = prefix.length;
      break;
    }
  }
  var bold = false;
  var italic = false;
  final colors = <ScriptColor>[];
  final buffer = StringBuffer();
  void flush() {
    if (buffer.isEmpty) return;
    runs.add(ScriptRun(buffer.toString(), bold: bold, italic: italic, color: colors.isEmpty ? null : colors.last));
    buffer.clear();
  }

  void marker(String text) {
    flush();
    runs.add(ScriptRun(text, bold: bold, italic: italic, color: colors.isEmpty ? null : colors.last, marker: true));
  }

  while (i < line.length) {
    if (line.startsWith('**', i)) {
      marker('**');
      bold = !bold;
      i += 2;
      continue;
    }
    if (line[i] == '*' && (italic || (i + 1 < line.length && line[i + 1] != ' '))) {
      marker('*');
      italic = !italic;
      i += 1;
      continue;
    }
    if (line[i] == '{') {
      if (line.startsWith('{/}', i) && colors.isNotEmpty) {
        marker('{/}');
        colors.removeLast();
        i += 3;
        continue;
      }
      final match = RegExp(r'\{([a-z]+)\}').matchAsPrefix(line, i);
      final color = match == null ? null : ScriptColor.values.where((c) => c.name == match.group(1)).firstOrNull;
      if (color != null) {
        flush();
        colors.add(color);
        marker(match!.group(0)!);
        i += match.group(0)!.length;
        continue;
      }
    }
    buffer.write(line[i]);
    i += 1;
  }
  flush();
  return ScriptLine(kind, runs);
}

List<ScriptLine> parseScript(String text) => [for (final line in text.split('\n')) parseScriptLine(line)];
