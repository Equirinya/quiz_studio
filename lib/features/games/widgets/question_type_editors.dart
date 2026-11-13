import 'package:flutter/material.dart';

import 'package:quiz_show/features/games/widgets/editor_section.dart';
import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/features/games/widgets/ranker_import.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// Queues a partial update of the question document.
typedef SaveQuestion = void Function(Map<String, dynamic> data);

/// Puts a type's own settings (null if it has none) and its content in place.
typedef TypeEditorLayout = Widget Function(Widget? settings, Widget content);

String questionTypeExplanation(AppLocalizations l10n, QuestionType type) => switch (type) {
      QuestionType.free => l10n.explainFree,
      QuestionType.abcd => l10n.explainAbcd,
      QuestionType.progressingReveal => l10n.explainProgressingReveal,
      QuestionType.feud => l10n.explainFeud,
      QuestionType.topAnswers => l10n.explainTopAnswers,
      QuestionType.connections => l10n.explainConnections,
      QuestionType.rapidFire => l10n.explainRapidFire,
      QuestionType.matching => l10n.explainMatching,
      QuestionType.ordering => l10n.explainOrdering,
      QuestionType.lastStanding => l10n.explainLastStanding,
      QuestionType.unsupported => l10n.explainUnsupported,
    };

/// The icon of a question type, in the type menu and wherever the type is
/// named in short.
IconData questionTypeIcon(QuestionType type) => switch (type) {
      QuestionType.free => Icons.chat_bubble_outline,
      QuestionType.abcd => Icons.grid_view,
      QuestionType.progressingReveal => Icons.visibility_outlined,
      QuestionType.topAnswers => Icons.format_list_numbered,
      QuestionType.feud => Icons.bar_chart,
      QuestionType.matching => Icons.link,
      QuestionType.ordering => Icons.swap_vert,
      QuestionType.connections => Icons.apps,
      QuestionType.rapidFire => Icons.bolt,
      QuestionType.lastStanding => Icons.emoji_events_outlined,
      QuestionType.unsupported => Icons.block,
    };

/// The inputs that only one question type has.
class QuestionTypeEditor extends StatelessWidget {
  const QuestionTypeEditor({
    super.key,
    required this.gameId,
    required this.question,
    required this.save,
    required this.onImported,
    required this.layout,
  });

  final String gameId;
  final Question question;
  final SaveQuestion save;

  /// An import replaced the question text and answer hint as well.
  final void Function(String text, String answerHint) onImported;

  /// Places the type's own settings (how teams answer), if it has any, and
  /// its content in the card.
  final TypeEditorLayout layout;

  @override
  Widget build(BuildContext context) {
    Widget content(Widget editor) =>
        question.needsDevices ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const DevicesOnlyHint(), editor]) : editor;
    Widget place(Widget? settings, Widget editor) => layout(settings, content(editor));
    return switch (question.type) {
      QuestionType.free => place(null, const SizedBox.shrink()),
      QuestionType.abcd => place(null, _AbcdEditor(question: question, save: save)),
      QuestionType.progressingReveal =>
        place(null, _InformationEditor(gameId: gameId, question: question, save: save, feud: false, onImported: onImported)),
      QuestionType.feud => place(null, _InformationEditor(gameId: gameId, question: question, save: save, feud: true, onImported: onImported)),
      QuestionType.connections => place(null, _ConnectionsEditor(question: question, save: save)),
      QuestionType.rapidFire => _RapidFireEditor(gameId: gameId, question: question, save: save, layout: place),
      QuestionType.matching => _MatchingEditor(gameId: gameId, question: question, save: save, layout: place),
      QuestionType.ordering => _OrderingEditor(gameId: gameId, question: question, save: save, layout: place),
      QuestionType.topAnswers => _TopAnswersEditor(question: question, save: save, layout: place),
      QuestionType.lastStanding => _StandingEditor(gameId: gameId, question: question, save: save, layout: place),
      QuestionType.unsupported => place(null, const SizedBox.shrink()),
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
    if (missing > 0) return context.l10n.groupsNeedNameAndWords(missing);
    final seen = <String>{};
    for (final word in [for (final g in groups) ...g.words]) {
      if (!seen.add(word.toLowerCase())) return context.l10n.wordTwice(word);
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
                    labelText: context.l10n.groupInCommon(g),
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
                              decoration: InputDecoration(labelText: context.l10n.wordN(w + 1), isDense: true),
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
          problem ?? context.l10n.connectionsReady,
          style: theme.textTheme.bodySmall?.copyWith(color: problem == null ? null : theme.colorScheme.error),
        ),
      ],
    );
  }
}

// The same colours as on screen; see features/companion/connections.dart.
const List<Color> _groupColors = [Color(0xFFF9DF6D), Color(0xFFA0C35A), Color(0xFFB0C4EF), Color(0xFFBA81C5)];

class _AbcdEditor extends StatefulWidget {
  const _AbcdEditor({required this.question, required this.save});

  final Question question;
  final SaveQuestion save;

  @override
  State<_AbcdEditor> createState() => _AbcdEditorState();
}

class _AbcdEditorState extends State<_AbcdEditor> {
  /// Four for a new question, as before; 2 to 9 in all.
  late final int _initial = widget.question.answers.length.clamp(kMinAbcdAnswers, kMaxAbcdAnswers) == widget.question.answers.length
      ? widget.question.answers.length
      : 4;

  late final List<TextEditingController> _answers = [
    for (var i = 0; i < _initial; i++) TextEditingController(text: widget.question.answers.elementAtOrNull(i) ?? ''),
  ];
  late final List<bool> _correct = [
    for (var i = 0; i < _initial; i++) widget.question.answersCorrect.elementAtOrNull(i) ?? false,
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

  void _add() {
    setState(() {
      _answers.add(TextEditingController());
      _correct.add(false);
    });
    _write();
  }

  void _remove(int i) {
    final removed = _answers.removeAt(i);
    _correct.removeAt(i);
    setState(() {});
    _write();
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _answers.length; i++)
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
                    key: ObjectKey(_answers[i]),
                    controller: _answers[i],
                    decoration: InputDecoration(labelText: context.l10n.answerLetter(String.fromCharCode(0x41 + i))),
                    onChanged: (_) => _write(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.l10n.removeAnswer,
                  onPressed: _answers.length > kMinAbcdAnswers ? () => _remove(i) : null,
                ),
              ],
            ),
          ),
        if (_answers.length < kMaxAbcdAnswers)
          TextButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: Text(context.l10n.addAnswer)),
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
  late bool _pictureStrip = widget.question.pictureStrip;

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
    final l10n = context.l10n;
    final feud = widget.feud;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.feud)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.absoluteValues),
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
                        decoration: InputDecoration(labelText: _absolute ? l10n.value : "%"),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _write(),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      controller: row.text,
                      decoration: InputDecoration(labelText: feud ? l10n.answerN(i + 1) : l10n.informationN(i + 1)),
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
                    tooltip: context.l10n.remove,
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
              label: Text(feud ? l10n.addAnswer : l10n.addInformation),
            ),
            if (widget.feud)
              TextButton.icon(
                onPressed: _importFromRanker,
                icon: const Icon(Icons.link),
                label: Text(l10n.importFromRanker),
              ),
          ],
        ),
        if (!widget.feud && _rows.any((row) => row.image.isNotEmpty))
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.pictureStrip),
            subtitle: Text(l10n.pictureStripText),
            value: _pictureStrip,
            onChanged: (value) {
              setState(() => _pictureStrip = value);
              widget.save({'pictureStrip': value});
            },
          ),
      ],
    );
  }
}

class _RapidRow {
  _RapidRow(RapidItem item)
      : question = TextEditingController(text: item.question),
        answer = TextEditingController(text: item.answer),
        hint = TextEditingController(text: item.hint),
        isTrue = item.isTrue,
        image = item.image,
        music = item.music;

  final TextEditingController question;
  final TextEditingController answer;

  /// For the gamemaster only, e.g. other answers to accept.
  final TextEditingController hint;
  bool isTrue;
  String? image;
  String? music;

  RapidItem get item =>
      RapidItem(question: question.text, answer: answer.text, isTrue: isTrue, hint: hint.text.trim(), image: image, music: music);

  void dispose() {
    question.dispose();
    answer.dispose();
    hint.dispose();
  }
}

/// Fragenhagel: how the teams answer, what shows the progress, and the items
/// with their answer (or whether the statement is right), picture and sound.
class _RapidFireEditor extends StatefulWidget {
  const _RapidFireEditor({required this.gameId, required this.question, required this.save, required this.layout});

  final String gameId;
  final Question question;
  final SaveQuestion save;
  final TypeEditorLayout layout;

  @override
  State<_RapidFireEditor> createState() => _RapidFireEditorState();
}

class _RapidFireEditorState extends State<_RapidFireEditor> {
  late final RapidFire _stored = widget.question.rapidFire ?? const RapidFire();
  late RapidMode _mode = _stored.mode;
  late ProgressStyle _progress = _stored.progress;
  late final List<_RapidRow> _rows = [for (final item in _stored.items) _RapidRow(item)];

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _write() => widget.save({
        'rapidFire': RapidFire(mode: _mode, progress: _progress, items: [for (final row in _rows) row.item]).toMap(),
      });

  void _change(VoidCallback change) {
    setState(change);
    _write();
  }

  @override
  Widget build(BuildContext context) {
    final devices = _mode == RapidMode.devices;
    final settings = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<RapidMode>(
          segments: [
            ButtonSegment(value: RapidMode.buzzer, icon: const Icon(Icons.notifications_active_outlined), label: Text(context.l10n.teamsBuzz)),
            ButtonSegment(value: RapidMode.devices, icon: const Icon(Icons.tablet_android), label: Text(context.l10n.onTheDevicesShort)),
          ],
          selected: {_mode},
          onSelectionChanged: (selected) => _change(() => _mode = selected.first),
        ),
        const SizedBox(height: 12),
        FillDropdown<ProgressStyle>(
          label: context.l10n.progressOnBigScreen,
          value: _progress,
          entries: [for (final style in ProgressStyle.values) DropdownMenuEntry(value: style, label: context.l10n.progressStyle(style))],
          onSelected: (style) {
            if (style != null) _change(() => _progress = style);
          },
        ),
        const SizedBox(height: 8),
        Text(
          devices
              ? context.l10n.rapidDevicesText
              : context.l10n.rapidBuzzText,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
    return widget.layout(settings, Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(padding: EdgeInsets.fromLTRB(0, 14, 8, 0), child: Icon(Icons.drag_indicator)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: row.question,
                          decoration: InputDecoration(labelText: devices ? context.l10n.statementN(i + 1) : context.l10n.questionN(i + 1), isDense: true),
                          onChanged: (_) => _write(),
                        ),
                        const SizedBox(height: 6),
                        // The answer (or right/wrong) and a hint only the
                        // gamemaster sees: side by side when there is room.
                        LayoutBuilder(
                          builder: (context, box) {
                            final answer = devices
                                ? Align(
                                    alignment: Alignment.centerLeft,
                                    child: SegmentedButton<bool>(
                                      // Without icons "Wrong" fits beside a narrow statement field.
                                      showSelectedIcon: false,
                                      segments: [
                                        ButtonSegment(value: true, label: Text(context.l10n.rapidRight)),
                                        ButtonSegment(value: false, label: Text(context.l10n.rapidWrong)),
                                      ],
                                      selected: {row.isTrue},
                                      onSelectionChanged: (selected) => _change(() => row.isTrue = selected.first),
                                    ),
                                  )
                                : TextField(
                                    controller: row.answer,
                                    decoration: InputDecoration(labelText: context.l10n.answer, isDense: true),
                                    onChanged: (_) => _write(),
                                  );
                            final hint = TextField(
                              controller: row.hint,
                              decoration: InputDecoration(labelText: context.l10n.answerHint, isDense: true),
                              onChanged: (_) => _write(),
                            );
                            if (box.maxWidth < 420) {
                              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [answer, const SizedBox(height: 6), hint]);
                            }
                            return Row(
                              children: [
                                devices ? answer : Expanded(child: answer),
                                const SizedBox(width: 8),
                                Expanded(child: hint),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  MediaButton(
                    gameId: widget.gameId,
                    kind: MediaKind.image,
                    name: row.image,
                    onChanged: (name) => _change(() => row.image = name),
                  ),
                  MediaButton(
                    gameId: widget.gameId,
                    kind: MediaKind.audio,
                    name: row.music,
                    onChanged: (name) => _change(() => row.music = name),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.remove,
                    onPressed: () => _change(() {
                      final removed = _rows.removeAt(i);
                      WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                    }),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _change(() => _rows.add(_RapidRow(const RapidItem()))),
            icon: const Icon(Icons.add),
            label: Text(devices ? context.l10n.addStatement : context.l10n.addQuestion),
          ),
        ),
      ],
    ));
  }
}

/// Last team standing: the turn order, and the prompts, one per turn (none
/// for a question every turn answers, e.g. "Name a Disney film").
class _StandingEditor extends StatefulWidget {
  const _StandingEditor({required this.gameId, required this.question, required this.save, required this.layout});

  final String gameId;
  final Question question;
  final SaveQuestion save;
  final TypeEditorLayout layout;

  @override
  State<_StandingEditor> createState() => _StandingEditorState();
}

class _StandingEditorState extends State<_StandingEditor> {
  late final LastStanding _stored = widget.question.lastStanding ?? const LastStanding();
  late TurnOrder _order = _stored.order;
  late final List<_RapidRow> _rows = [for (final item in _stored.items) _RapidRow(item)];

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _write() => widget.save({'lastStanding': LastStanding(order: _order, items: [for (final row in _rows) row.item]).toMap()});

  void _change(VoidCallback change) {
    setState(change);
    _write();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FillDropdown<TurnOrder>(
          label: context.l10n.turnOrderLabel,
          value: _order,
          entries: [for (final order in TurnOrder.values) DropdownMenuEntry(value: order, label: context.l10n.turnOrder(order))],
          onSelected: (order) {
            if (order != null) _change(() => _order = order);
          },
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.lastStandingText,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
    return widget.layout(settings, Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _rows.isEmpty ? context.l10n.noPrompts : context.l10n.onePromptPerTurn,
          style: Theme.of(context).textTheme.bodySmall,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(padding: EdgeInsets.fromLTRB(0, 14, 8, 0), child: Icon(Icons.drag_indicator)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: row.question,
                      decoration: InputDecoration(labelText: context.l10n.promptN(i + 1), isDense: true),
                      onChanged: (_) => _write(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.answer,
                      decoration: InputDecoration(labelText: context.l10n.answer, isDense: true),
                      onChanged: (_) => _write(),
                    ),
                  ),
                  MediaButton(
                    gameId: widget.gameId,
                    kind: MediaKind.image,
                    name: row.image,
                    onChanged: (name) => _change(() => row.image = name),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.remove,
                    onPressed: () => _change(() {
                      final removed = _rows.removeAt(i);
                      WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                    }),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _change(() => _rows.add(_RapidRow(const RapidItem()))),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.addPrompt),
          ),
        ),
      ],
    ));
  }
}

/// Says so when a question can only be played with the teams' own devices.
class DevicesOnlyHint extends StatelessWidget {
  const DevicesOnlyHint({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.tablet_android, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.onlyWithDevices,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchRow {
  _MatchRow(MatchPair pair)
      : left = TextEditingController(text: pair.left.text),
        right = TextEditingController(text: pair.right.text),
        leftImage = pair.left.image,
        rightImage = pair.right.image;

  final TextEditingController left;
  final TextEditingController right;
  String? leftImage;
  String? rightImage;

  MatchPair get pair =>
      MatchPair(left: MatchSide(text: left.text, image: leftImage), right: MatchSide(text: right.text, image: rightImage));

  void dispose() {
    left.dispose();
    right.dispose();
  }
}

/// Matching: the pairs as they belong together, each side a text, a picture
/// or both; plus the time the teams get.
class _MatchingEditor extends StatefulWidget {
  const _MatchingEditor({required this.gameId, required this.question, required this.save, required this.layout});

  final String gameId;
  final Question question;
  final SaveQuestion save;
  final TypeEditorLayout layout;

  @override
  State<_MatchingEditor> createState() => _MatchingEditorState();
}

class _MatchingEditorState extends State<_MatchingEditor> {
  late final List<_MatchRow> _rows = [
    for (final pair in (widget.question.matching ?? const Matching()).pairs) _MatchRow(pair),
  ];
  late int? _timer = widget.question.companion?.timerSeconds;
  late bool _lock = widget.question.companion?.lockable ?? true;

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _write() => widget.save({
        'matching': Matching(pairs: [for (final row in _rows) row.pair]).toMap(),
        'companion': {'timer': _timer, 'lock': _lock},
      });

  void _change(VoidCallback change) {
    setState(change);
    _write();
  }

  Widget _side(String label, TextEditingController text, String? image, ValueChanged<String?> onImage) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: text,
          decoration: InputDecoration(labelText: label, isDense: true),
          onChanged: (_) => _write(),
        ),
      ),
      MediaButton(gameId: widget.gameId, kind: MediaKind.image, name: image, onChanged: onImage),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final settings = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldGrid(minWidth: 170, children: [TimerDropdown(seconds: _timer, onChanged: (seconds) => _change(() => _timer = seconds))]),
        LockInSwitch(value: _lock, onChanged: (on) => _change(() => _lock = on)),
      ],
    );
    return widget.layout(settings, Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.matchingEditorText,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (final (i, row) in _rows.indexed)
          Padding(
            key: ObjectKey(row),
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                SizedBox(width: 28, child: Text(Matching.letter(i), style: Theme.of(context).textTheme.titleMedium)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final left = _side(context.l10n.matchLeft, row.left, row.leftImage, (name) => _change(() => row.leftImage = name));
                      final right = _side(context.l10n.matchBelongsTo, row.right, row.rightImage, (name) => _change(() => row.rightImage = name));
                      // On a phone the two sides go one above the other.
                      if (box.maxWidth < 480) return Column(children: [left, const SizedBox(height: 6), right]);
                      return Row(
                        children: [
                          Expanded(child: left),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.link)),
                          Expanded(child: right),
                        ],
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.l10n.removePair,
                  onPressed: () => _change(() {
                    final removed = _rows.removeAt(i);
                    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                  }),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _change(() => _rows.add(_MatchRow(const MatchPair()))),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.addPair),
          ),
        ),
      ],
    ));
  }
}

class _OrderRow {
  _OrderRow(OrderItem item)
      : text = TextEditingController(text: item.text),
        value = TextEditingController(text: item.value),
        image = item.image;

  final TextEditingController text;
  final TextEditingController value;
  String? image;

  OrderItem get item => OrderItem(text: text.text, image: image, value: value.text);

  void dispose() {
    text.dispose();
    value.dispose();
  }
}

/// Put in order: the entries in the right order, each a text, a picture or
/// both, with what it is sorted by; plus the time and how it is scored.
class _OrderingEditor extends StatefulWidget {
  const _OrderingEditor({required this.gameId, required this.question, required this.save, required this.layout});

  final String gameId;
  final Question question;
  final SaveQuestion save;
  final TypeEditorLayout layout;

  @override
  State<_OrderingEditor> createState() => _OrderingEditorState();
}

class _OrderingEditorState extends State<_OrderingEditor> {
  late final Ordering _stored = widget.question.ordering ?? const Ordering();
  late final List<_OrderRow> _rows = [
    for (final item in _stored.items) _OrderRow(item),
    // A new question starts with three empty entries to fill in.
    if (_stored.items.isEmpty) for (var i = 0; i < 3; i++) _OrderRow(const OrderItem()),
  ];
  late int? _timer = widget.question.companion?.timerSeconds;
  late bool _lock = widget.question.companion?.lockable ?? true;

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  // The "put in order" screen of a former free question is replaced. How
  // it is scored is set in the scoring section, stored on its own.
  void _write() => widget.save({
        'ordering': Ordering(items: [for (final row in _rows) row.item]).toMap(),
        'companion': {'timer': _timer, 'lock': _lock},
      });

  void _change(VoidCallback change) {
    setState(change);
    _write();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldGrid(minWidth: 170, children: [TimerDropdown(seconds: _timer, onChanged: (seconds) => _change(() => _timer = seconds))]),
        LockInSwitch(value: _lock, onChanged: (on) => _change(() => _lock = on)),
      ],
    );
    return widget.layout(settings, Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.orderingEditorText, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          // onReorderItem replaces this from Flutter 3.41 on; kept for older SDKs in CI.
          // ignore: deprecated_member_use
          onReorder: (from, to) => _change(() {
            if (to > from) to -= 1;
            _rows.insert(to, _rows.removeAt(from));
          }),
          children: [
            for (final (i, row) in _rows.indexed)
              Padding(
                key: ObjectKey(row),
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: SizedBox(
                        width: 44,
                        child: Row(
                          children: [
                            Icon(Icons.drag_indicator, size: 18, color: theme.colorScheme.outline),
                            Text("${i + 1}", style: theme.textTheme.titleMedium),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final entry = Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: row.text,
                                  decoration: InputDecoration(labelText: l10n.orderEntry, isDense: true),
                                  onChanged: (_) => _write(),
                                ),
                              ),
                              MediaButton(
                                gameId: widget.gameId,
                                kind: MediaKind.image,
                                name: row.image,
                                onChanged: (name) => _change(() => row.image = name),
                              ),
                            ],
                          );
                          final value = TextField(
                            controller: row.value,
                            decoration: InputDecoration(labelText: l10n.orderValue, hintText: l10n.orderValueHint, isDense: true),
                            onChanged: (_) => _write(),
                          );
                          // On a phone the value goes below the entry.
                          if (box.maxWidth < 420) return Column(children: [entry, const SizedBox(height: 6), value]);
                          return Row(
                            children: [
                              Expanded(flex: 3, child: entry),
                              const SizedBox(width: 12),
                              Expanded(flex: 2, child: value),
                            ],
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.removeEntry,
                      onPressed: () => _change(() {
                        final removed = _rows.removeAt(i);
                        WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                      }),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _change(() => _rows.add(_OrderRow(const OrderItem()))),
            icon: const Icon(Icons.add),
            label: Text(l10n.addEntry),
          ),
        ),
      ],
    ));
  }
}

class _TopRow {
  _TopRow(TopAnswer item)
      : answer = TextEditingController(text: item.answer),
        points = TextEditingController(text: item.points?.toString() ?? '');

  final TextEditingController answer;
  final TextEditingController points;

  TopAnswer get item => TopAnswer(answer: answer.text, points: int.tryParse(points.text.trim()));

  void dispose() {
    answer.dispose();
    points.dispose();
  }
}

/// Top answers: the list, most popular first, each answer with its points,
/// and how the teams answer.
class _TopAnswersEditor extends StatefulWidget {
  const _TopAnswersEditor({required this.question, required this.save, required this.layout});

  final Question question;
  final SaveQuestion save;
  final TypeEditorLayout layout;

  @override
  State<_TopAnswersEditor> createState() => _TopAnswersEditorState();
}

class _TopAnswersEditorState extends State<_TopAnswersEditor> {
  late final TopAnswers _stored = widget.question.topAnswers ?? const TopAnswers();
  late TopAnswersMode _mode = _stored.mode;
  late final List<_TopRow> _rows = [for (final item in _stored.items) _TopRow(item)];
  late final CompanionSpec? _companion = CompanionSpec.fromMap({...?_storedCompanion, 'kind': CompanionKind.text.name});
  late int? _timer = _companion?.timerSeconds;
  late bool _lock = _companion?.lockable ?? true;

  Map<String, dynamic>? get _storedCompanion {
    final stored = widget.question.data['companion'];
    return stored is Map ? Map<String, dynamic>.from(stored) : null;
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _write() => widget.save({
        'topAnswers': TopAnswers(mode: _mode, items: [for (final row in _rows) row.item]).toMap(),
        'companion': {'timer': _timer, 'lock': _lock},
      });

  void _change(VoidCallback change) {
    setState(change);
    _write();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devices = _mode != TopAnswersMode.buzzer;
    final settings = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TopAnswersMode>(
          segments: [
            ButtonSegment(value: TopAnswersMode.buzzer, icon: const Icon(Icons.notifications_active_outlined), label: Text(context.l10n.buzz)),
            ButtonSegment(value: TopAnswersMode.typed, icon: const Icon(Icons.keyboard_outlined), label: Text(context.l10n.typed)),
            ButtonSegment(value: TopAnswersMode.whiteboard, icon: const Icon(Icons.draw_outlined), label: Text(context.l10n.whiteboard)),
          ],
          selected: {_mode},
          onSelectionChanged: (selected) => _change(() => _mode = selected.first),
        ),
        if (devices) ...[
          const SizedBox(height: 12),
          FieldGrid(minWidth: 170, children: [TimerDropdown(seconds: _timer, onChanged: (seconds) => _change(() => _timer = seconds))]),
          LockInSwitch(value: _lock, onChanged: (on) => _change(() => _lock = on)),
        ],
        const SizedBox(height: 8),
        Text(
          switch (_mode) {
            TopAnswersMode.buzzer => context.l10n.topAnswersBuzzText,
            TopAnswersMode.typed => context.l10n.topAnswersTypedText,
            TopAnswersMode.whiteboard => context.l10n.topAnswersWhiteboardText,
          },
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
    return widget.layout(settings, Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.topAnswersListText,
          style: theme.textTheme.bodySmall,
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
                  SizedBox(width: 28, child: Text("${i + 1}.", style: theme.textTheme.titleMedium)),
                  Expanded(
                    child: TextField(
                      controller: row.answer,
                      decoration: InputDecoration(labelText: context.l10n.answer, isDense: true),
                      onChanged: (_) => _write(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: row.points,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: context.l10n.points, hintText: "${widget.question.pointsPlus}", isDense: true),
                      onChanged: (_) => _write(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.remove,
                    onPressed: () => _change(() {
                      final removed = _rows.removeAt(i);
                      WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                    }),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _change(() => _rows.add(_TopRow(const TopAnswer()))),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.addAnswer),
          ),
        ),
      ],
    ));
  }
}
