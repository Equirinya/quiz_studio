import 'package:flutter/material.dart';

import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/features/games/widgets/ranker_import.dart';
import 'package:quiz_show/game/game.dart';

/// Queues a partial update of the question document.
typedef SaveQuestion = void Function(Map<String, dynamic> data);

String questionTypeExplanation(QuestionType type) => switch (type) {
      QuestionType.free =>
        "The most basic question: no answer options and nothing to reveal. Buzzers can be disabled, e.g. for estimation questions.",
      QuestionType.abcd => "Shows right and wrong answer suggestions, which the gamemaster reveals one by one.",
      QuestionType.progressingReveal => "The gamemaster reveals more information piece by piece.",
      QuestionType.feud => "Inspired by Family Feud: a list of answers, each worth a share of the points.",
      QuestionType.connections =>
        "Sixteen words in four groups of four. Every team solves it on its own device; each group found is worth a quarter of the points.",
      QuestionType.unsupported => "This question type is not supported by this version of the app.",
    };

/// The inputs that only one question type has.
class QuestionTypeEditor extends StatelessWidget {
  const QuestionTypeEditor({
    super.key,
    required this.gameId,
    required this.question,
    required this.save,
    required this.onImported,
  });

  final String gameId;
  final Question question;
  final SaveQuestion save;

  /// An import replaced the question text and answer hint as well.
  final void Function(String text, String answerHint) onImported;

  @override
  Widget build(BuildContext context) {
    return switch (question.type) {
      QuestionType.free => _FreeEditor(question: question, save: save),
      QuestionType.abcd => _AbcdEditor(question: question, save: save),
      QuestionType.progressingReveal =>
        _InformationEditor(gameId: gameId, question: question, save: save, feud: false, onImported: onImported),
      QuestionType.feud =>
        _InformationEditor(gameId: gameId, question: question, save: save, feud: true, onImported: onImported),
      QuestionType.connections => _ConnectionsEditor(question: question, save: save),
      QuestionType.unsupported => const SizedBox(),
    };
  }
}

/// The four groups of a Connections question, easiest first, each in the
/// colour it will have on screen.
class _ConnectionsEditor extends StatefulWidget {
  const _ConnectionsEditor({required this.question, required this.save});

  final Question question;
  final SaveQuestion save;

  @override
  State<_ConnectionsEditor> createState() => _ConnectionsEditorState();
}

class _ConnectionsEditorState extends State<_ConnectionsEditor> {
  late final List<TextEditingController> _names = [
    for (final group in widget.question.connectionGroups) TextEditingController(text: group.name),
  ];
  late final List<List<TextEditingController>> _words = [
    for (final group in widget.question.connectionGroups) [for (final word in group.words) TextEditingController(text: word)],
  ];

  @override
  void dispose() {
    for (final controller in [..._names, for (final row in _words) ...row]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<ConnectionGroup> get _groups => [
        for (var g = 0; g < kConnectionsGroups; g++)
          ConnectionGroup(name: _names[g].text.trim(), words: [for (final c in _words[g]) c.text.trim()]),
      ];

  void _write() {
    setState(() {});
    widget.save({'connections': [for (final group in _groups) group.toMap()]});
  }

  /// What still stands between this puzzle and a fair game.
  String? get _problem {
    final groups = _groups;
    final missing = groups.where((g) => !g.isComplete).length;
    if (missing > 0) return "$missing ${missing == 1 ? "group needs" : "groups need"} a name and four words.";
    final seen = <String>{};
    for (final word in [for (final g in groups) ...g.words]) {
      if (!seen.add(word.toLowerCase())) return "\"$word\" is in the puzzle twice.";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problem = _problem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        for (var g = 0; g < kConnectionsGroups; g++)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: _groupColors[g].withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(14),
              border: Border(left: BorderSide(color: _groupColors[g], width: 6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _names[g],
                  decoration: InputDecoration(
                    labelText: "${_groupNames[g]}: what they have in common",
                    isDense: true,
                  ),
                  onChanged: (_) => _write(),
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, box) {
                    final perRow = box.maxWidth < 420 ? 2 : 4;
                    final width = (box.maxWidth - 8 * (perRow - 1)) / perRow;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (var w = 0; w < kConnectionsGroupSize; w++)
                          SizedBox(
                            width: width,
                            child: TextField(
                              controller: _words[g][w],
                              decoration: InputDecoration(labelText: "Word ${w + 1}", isDense: true),
                              onChanged: (_) => _write(),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          problem ?? "Ready. Yellow is meant to be the easiest group and purple the hardest.",
          style: theme.textTheme.bodySmall?.copyWith(color: problem == null ? null : theme.colorScheme.error),
        ),
      ],
    );
  }
}

// The same colours as on screen; see features/companion/connections.dart.
const List<Color> _groupColors = [Color(0xFFF9DF6D), Color(0xFFA0C35A), Color(0xFFB0C4EF), Color(0xFFBA81C5)];
const List<String> _groupNames = ['Yellow', 'Green', 'Blue', 'Purple'];

class _FreeEditor extends StatefulWidget {
  const _FreeEditor({required this.question, required this.save});

  final Question question;
  final SaveQuestion save;

  @override
  State<_FreeEditor> createState() => _FreeEditorState();
}

class _FreeEditorState extends State<_FreeEditor> {
  late bool _noBuzzer = widget.question.noBuzzer;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text("Disable buzzers"),
      value: _noBuzzer,
      onChanged: (value) {
        setState(() => _noBuzzer = value);
        widget.save({'noBuzzer': value});
      },
    );
  }
}

class _AbcdEditor extends StatefulWidget {
  const _AbcdEditor({required this.question, required this.save});

  final Question question;
  final SaveQuestion save;

  @override
  State<_AbcdEditor> createState() => _AbcdEditorState();
}

class _AbcdEditorState extends State<_AbcdEditor> {
  static const int _count = 4;

  late final List<TextEditingController> _answers = [
    for (var i = 0; i < _count; i++) TextEditingController(text: widget.question.answers.elementAtOrNull(i) ?? ''),
  ];
  late final List<bool> _correct = [
    for (var i = 0; i < _count; i++) widget.question.answersCorrect.elementAtOrNull(i) ?? false,
  ];

  @override
  void dispose() {
    for (final controller in _answers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _write() => widget.save({
        'answers': [for (final controller in _answers) controller.text],
        'answersCorrect': List<bool>.of(_correct),
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _count; i++)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Checkbox(
                  value: _correct[i],
                  onChanged: (value) {
                    setState(() => _correct[i] = value ?? false);
                    _write();
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _answers[i],
                    decoration: InputDecoration(labelText: "Answer ${String.fromCharCode(0x41 + i)}"),
                    onChanged: (_) => _write(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InformationRow {
  _InformationRow({String text = '', double value = 0, this.image = '', this.music = ''})
      : text = TextEditingController(text: text),
        value = TextEditingController(text: _formatValue(value));

  final TextEditingController text;
  final TextEditingController value;
  String image;
  String music;

  static String _formatValue(double value) => value % 1 == 0 ? value.toInt().toString() : value.toString();

  void dispose() {
    text.dispose();
    value.dispose();
  }
}

/// The list behind progressing reveal (text, image, sound per step) and feud
/// (value and text per answer). The lists are stored index-aligned, so every
/// change writes all of them.
class _InformationEditor extends StatefulWidget {
  const _InformationEditor({
    required this.gameId,
    required this.question,
    required this.save,
    required this.feud,
    required this.onImported,
  });

  final String gameId;
  final Question question;
  final SaveQuestion save;
  final bool feud;
  final void Function(String text, String answerHint) onImported;

  @override
  State<_InformationEditor> createState() => _InformationEditorState();
}

class _InformationEditorState extends State<_InformationEditor> {
  late final List<_InformationRow> _rows = [
    for (final (i, text) in widget.question.information.indexed)
      _InformationRow(
        text: text,
        value: widget.question.percentages.elementAtOrNull(i) ?? 0,
        image: widget.question.informationImages.elementAtOrNull(i) ?? '',
        music: widget.question.informationMusic.elementAtOrNull(i) ?? '',
      ),
  ];
  late bool _absolute = widget.question.absoluteValues;

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _write() => widget.save({
        'information': [for (final row in _rows) row.text.text],
        if (widget.feud)
          'informationPercentage': [for (final row in _rows) double.tryParse(row.value.text.replaceAll(',', '.')) ?? 0.0]
        else ...{
          'informationImage': [for (final row in _rows) row.image],
          'informationMusic': [for (final row in _rows) row.music],
        },
      });

  void _change(VoidCallback change) {
    setState(change);
    _write();
  }

  Future<void> _importFromRanker() async {
    final result = await showRankerImportDialog(context);
    if (result == null || !mounted) return;
    final old = List.of(_rows);
    setState(() {
      _rows
        ..clear()
        ..addAll([
          for (final (i, answer) in result.answers.indexed) _InformationRow(text: answer, value: _round(result.percentages[i])),
        ]);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final row in old) {
        row.dispose();
      }
    });
    _write();
    widget.save({'question': result.title, 'answerHint': result.answerHint});
    widget.onImported(result.title, result.answerHint);
  }

  static double _round(double value) => (value * 10).roundToDouble() / 10;

  @override
  Widget build(BuildContext context) {
    final noun = widget.feud ? "Answer" : "Information";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.feud)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Show absolute values instead of percentages"),
            value: _absolute,
            onChanged: (value) {
              setState(() => _absolute = value);
              widget.save({'absoluteValues': value});
            },
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _rows.length,
          // onReorderItem replaces this from Flutter 3.41 on; kept for older SDKs in CI.
          // ignore: deprecated_member_use
          onReorder: (oldIndex, newIndex) => _change(() {
            if (oldIndex < newIndex) newIndex -= 1;
            _rows.insert(newIndex, _rows.removeAt(oldIndex));
          }),
          itemBuilder: (context, i) {
            final row = _rows[i];
            return Padding(
              key: ObjectKey(row),
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.drag_indicator)),
                  ),
                  if (widget.feud) ...[
                    SizedBox(
                      width: 84,
                      child: TextField(
                        controller: row.value,
                        decoration: InputDecoration(labelText: _absolute ? "Value" : "%"),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _write(),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      controller: row.text,
                      decoration: InputDecoration(labelText: "$noun ${i + 1}"),
                      onChanged: (_) => _write(),
                    ),
                  ),
                  if (!widget.feud) ...[
                    MediaButton(
                      gameId: widget.gameId,
                      kind: MediaKind.image,
                      name: row.image,
                      onChanged: (name) => _change(() => row.image = name ?? ''),
                    ),
                    MediaButton(
                      gameId: widget.gameId,
                      kind: MediaKind.audio,
                      name: row.music,
                      onChanged: (name) => _change(() => row.music = name ?? ''),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: "Remove",
                    onPressed: () => _change(() {
                      final removed = _rows.removeAt(i);
                      // Its text fields are still mounted until the next frame.
                      WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                    }),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => _change(() => _rows.add(_InformationRow())),
              icon: const Icon(Icons.add),
              label: Text("Add ${noun.toLowerCase()}"),
            ),
            if (widget.feud)
              TextButton.icon(
                onPressed: _importFromRanker,
                icon: const Icon(Icons.link),
                label: const Text("Import from Ranker"),
              ),
          ],
        ),
      ],
    );
  }
}
