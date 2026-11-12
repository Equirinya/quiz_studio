import 'package:flutter/material.dart';

import 'package:quiz_show/features/games/widgets/editor_section.dart';
import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/game/game.dart';

/// Sets up what the teams' own devices show while a question is open: a
/// whiteboard, a number to enter, items to sort, and so on. Stored on the
/// question as `companion`; null removes it.
class CompanionEditor extends StatefulWidget {
  const CompanionEditor({super.key, required this.gameId, required this.question, required this.save});

  final String gameId;
  final Question question;
  final void Function(Map<String, dynamic> data) save;

  @override
  State<CompanionEditor> createState() => _CompanionEditorState();
}

const Map<String, String> _backgroundNames = {
  'blank': "Blank",
  'lines': "Ruled",
  'grid': "Squared",
  'list': "Numbered list",
  'image': "Picture",
};

class _CompanionEditorState extends State<CompanionEditor> {
  late CompanionKind? _kind;

  /// With no screen: whether the devices show a buzzer, or nothing at all.
  late bool _phoneBuzzer;

  /// With nothing on the devices: no buzzer boxes either (free questions).
  late bool _noBuzzer;
  late int? _timer;
  late bool _lockable;
  late int _mistakes;
  late String _background;
  String? _backgroundImage;
  late int _listRows;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late final TextEditingController _step;
  late final TextEditingController _unit;
  late final TextEditingController _solution;
  late final TextEditingController _tolerance;
  late final List<TextEditingController> _options;
  late final List<TextEditingController> _targets;

  @override
  void initState() {
    super.initState();
    final spec = CompanionSpec.fromMap(widget.question.data['companion']);
    String n(double? v) => v == null ? '' : formatNumber(v);
    final connections = widget.question.type == QuestionType.connections;
    final played = connections ? widget.question.companion : spec;
    _kind = connections ? CompanionKind.connections : spec?.kind;
    _phoneBuzzer = _canBuzz && widget.question.data['noBuzzer'] != true && widget.question.data['noPhoneBuzzer'] != true;
    _noBuzzer = widget.question.data['noBuzzer'] == true;
    // With a buzzer or nothing on the devices the question has its own timer.
    final own = widget.question.data['timer'];
    _timer = played?.timerSeconds ?? (spec == null && own is num ? own.toInt() : null);
    _lockable = played?.lockable ?? true;
    _mistakes = played?.mistakes ?? 3;
    // Read from the stored value: a "Picture" paper without a picture yet
    // should stay selected while one is being chosen.
    final stored = (widget.question.data['companion'] as Map?)?['background'];
    _background = stored is String && whiteboardBackgrounds.contains(stored) ? stored : 'blank';
    _backgroundImage = spec?.backgroundImage ?? (widget.question.data['companion'] as Map?)?['backgroundImage'] as String?;
    _listRows = spec?.listRows ?? 5;
    _min = TextEditingController(text: n(spec?.min));
    _max = TextEditingController(text: n(spec?.max));
    _step = TextEditingController(text: n(spec?.step));
    _unit = TextEditingController(text: spec?.unit ?? '');
    _solution = TextEditingController(text: n(spec?.solution));
    _tolerance = TextEditingController(text: n(spec?.tolerance));
    _options = [for (final option in spec?.options ?? const <String>[]) TextEditingController(text: option)];
    _targets = [
      for (var i = 0; i < _options.length; i++) TextEditingController(text: spec?.targets.elementAtOrNull(i) ?? ''),
    ];
  }

  @override
  void dispose() {
    for (final controller in [_min, _max, _step, _unit, _solution, _tolerance, ..._options, ..._targets]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Whether this kind of question can be buzzed at all; a free one can
  /// have its buzzer switched back on.
  bool get _canBuzz => widget.question.type == QuestionType.free || widget.question.buzzerable;

  static const String _buzzer = 'buzzer';
  static const String _nothing = 'nothing';

  bool get _hasItems => _kind == CompanionKind.order || _kind == CompanionKind.match;

  bool get _hasRange => _kind == CompanionKind.number || _kind == CompanionKind.slider;

  void _write() {
    final kind = _kind;
    if (kind == null) {
      // A buzzer on the devices, or nothing there: then only a buzzer box
      // buzzes, if the question is buzzed at all.
      widget.save({
        'companion': null,
        'timer': _timer,
        'noPhoneBuzzer': !_phoneBuzzer,
        if (widget.question.type == QuestionType.free) 'noBuzzer': !_phoneBuzzer && _noBuzzer,
      });
      return;
    }
    if (kind == CompanionKind.connections) {
      // The groups are the question's own; only how it is played goes here.
      widget.save({
        'companion': CompanionSpec(kind: kind, timerSeconds: _timer, lockable: _lockable, mistakes: _mistakes).toMap(),
        'timer': null,
      });
      return;
    }
    double? n(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));
    widget.save({
      'companion': CompanionSpec(
        kind: kind,
        timerSeconds: _timer,
        background: _background,
        backgroundImage: _background == 'image' ? _backgroundImage : null,
        listRows: _listRows,
        min: _hasRange ? n(_min) : null,
        max: _hasRange ? n(_max) : null,
        step: kind == CompanionKind.slider ? n(_step) : null,
        unit: _hasRange && _unit.text.trim().isNotEmpty ? _unit.text.trim() : null,
        solution: _hasRange ? n(_solution) : null,
        tolerance: _hasRange ? n(_tolerance) : null,
        options: _hasItems ? [for (final c in _options) c.text] : const [],
        targets: kind == CompanionKind.match ? [for (final c in _targets) c.text] : const [],
        lockable: _lockable,
      ).toMap(),
      'timer': null,
      // Teams answer on their devices; a buzzer would only get in the way.
      if (widget.question.type == QuestionType.free) 'noBuzzer': true,
    });
  }

  void _change(VoidCallback change) {
    setState(change);
    _write();
  }

  Widget _number(TextEditingController controller, String label) => TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label, isDense: true),
    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
    onChanged: (_) => _write(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = _kind;
    final connections = kind == CompanionKind.connections;
    // A free question with nothing on the devices may still be buzzed on
    // buzzer boxes, or not at all.
    final free = widget.question.type == QuestionType.free && widget.question.amountBet == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          connections
              ? "Every team solves the puzzle on its own device. You see live which groups each team has found."
              : kind == null
              ? "Choose a screen to open on every team's device with the question. You see the answers as they are written "
                    "and decide when to show them."
              : "Opens on every team's device with the question. You see the answers as they are written and decide when to show them.",
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FieldGrid(
          minWidth: 170,
          children: [
            if (!connections)
              FillDropdown<String>(
                label: "On the devices",
                value: kind?.name ?? (_phoneBuzzer ? _buzzer : _nothing),
                entries: [
                  if (_canBuzz) const DropdownMenuEntry(value: _buzzer, label: "Buzzer"),
                  const DropdownMenuEntry(value: _nothing, label: "Nothing"),
                  for (final option in companionKindsFor(widget.question.type, current: kind))
                    DropdownMenuEntry(
                      value: option.name,
                      label: option.uiString,
                      trailingIcon: option == recommendedCompanionKind(widget.question.type)
                          ? const Tooltip(message: "Recommended", child: Icon(Icons.star_outline, size: 18))
                          : null,
                    ),
                ],
                onSelected: (value) => _change(() {
                  _kind = CompanionKind.values.where((k) => k.name == value).firstOrNull;
                  if (_kind == null) _phoneBuzzer = value == _buzzer;
                  if (_kind == null && _phoneBuzzer) _noBuzzer = false;
                }),
              ),
            TimerDropdown(seconds: _timer, onChanged: (value) => _change(() => _timer = value)),
            if (connections)
              FillDropdown<int>(
                label: "Mistakes allowed",
                value: _mistakes,
                entries: [for (var n = 1; n <= 6; n++) DropdownMenuEntry(value: n, label: "$n")],
                onSelected: (value) => _change(() => _mistakes = value ?? 3),
              ),
            if (kind == CompanionKind.whiteboard)
              FillDropdown<String>(
                label: "Paper",
                value: _background,
                entries: [for (final entry in _backgroundNames.entries) DropdownMenuEntry(value: entry.key, label: entry.value)],
                onSelected: (value) => _change(() => _background = value ?? 'blank'),
              ),
            if ((kind == CompanionKind.whiteboard && _background == 'list') || kind == CompanionKind.list)
              FillDropdown<int>(
                label: "Rows",
                value: _listRows,
                entries: [for (var rows = 2; rows <= 12; rows++) DropdownMenuEntry(value: rows, label: "$rows")],
                onSelected: (value) => _change(() => _listRows = value ?? 5),
              ),
          ],
        ),
        if (kind == CompanionKind.whiteboard && _background == 'image')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                MediaButton(
                  gameId: widget.gameId,
                  kind: MediaKind.image,
                  name: _backgroundImage,
                  onChanged: (name) => _change(() => _backgroundImage = name),
                ),
                Expanded(child: Text(_backgroundImage == null ? "Choose the picture to draw on" : "Picture set")),
              ],
            ),
          ),
        if (_hasRange) ...[
          const SizedBox(height: 12),
          FieldGrid(
            children: [
              if (kind == CompanionKind.slider) ...[_number(_min, "From"), _number(_max, "To"), _number(_step, "Step")],
              TextField(
                controller: _unit,
                decoration: const InputDecoration(labelText: "Unit", isDense: true),
                onChanged: (_) => _write(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FieldGrid(children: [_number(_solution, "Right value"), _number(_tolerance, "Right within ±")]),
        ],
        if (kind == null && free && !_phoneBuzzer)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("No buzzing at all"),
            subtitle: const Text("Buzzer boxes stay off too, e.g. for estimation questions"),
            value: _noBuzzer,
            onChanged: (value) => _change(() => _noBuzzer = value),
          ),
        if (kind != null)
          LockInSwitch(
            title: connections ? "Teams can stop early" : "Teams can lock in early",
            value: _lockable,
            onChanged: (value) => _change(() => _lockable = value),
          ),
        if (_hasItems) ...[
          const SizedBox(height: 12),
          Text(
            kind == CompanionKind.order
                ? "Enter the items in the right order. The teams get them shuffled."
                : "Enter each pair. The teams get the right-hand side shuffled.",
            style: theme.textTheme.bodySmall,
          ),
          for (var i = 0; i < _options.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Text("${i + 1}.")),
                  Expanded(
                    child: TextField(
                      controller: _options[i],
                      decoration: InputDecoration(labelText: kind == CompanionKind.match ? "Left" : "Item", isDense: true),
                      onChanged: (_) => _write(),
                    ),
                  ),
                  if (kind == CompanionKind.match) ...[
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, size: 18)),
                    Expanded(
                      child: TextField(
                        controller: _targets[i],
                        decoration: const InputDecoration(labelText: "Right", isDense: true),
                        onChanged: (_) => _write(),
                      ),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: "Remove",
                    onPressed: () => _change(() {
                      final removed = [_options.removeAt(i), _targets.removeAt(i)];
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        for (final controller in removed) {
                          controller.dispose();
                        }
                      });
                    }),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _change(() {
                _options.add(TextEditingController());
                _targets.add(TextEditingController());
              }),
              icon: const Icon(Icons.add),
              label: Text(kind == CompanionKind.match ? "Add pair" : "Add item"),
            ),
          ),
        ],
      ],
    );
  }
}

/// The screens that make sense on the teams' devices for a question of
/// [type]. A whiteboard always does. A screen already chosen ([current]) stays
/// offered, so older questions keep theirs.
List<CompanionKind> companionKindsFor(QuestionType type, {CompanionKind? current}) {
  final kinds = switch (type) {
    // The answers come from the question itself.
    QuestionType.abcd => const [CompanionKind.choice, CompanionKind.whiteboard, CompanionKind.text],
    QuestionType.free => const [
        CompanionKind.whiteboard,
        CompanionKind.text,
        CompanionKind.number,
        CompanionKind.slider,
        CompanionKind.order,
        CompanionKind.match,
        CompanionKind.list,
      ],
    QuestionType.feud => const [CompanionKind.whiteboard, CompanionKind.text, CompanionKind.list],
    _ => const [CompanionKind.whiteboard, CompanionKind.text],
  };
  return [...kinds, if (current != null && !kinds.contains(current) && current != CompanionKind.connections) current];
}

/// The screen a question of [type] is meant for, marked in the menu.
CompanionKind? recommendedCompanionKind(QuestionType type) => type == QuestionType.abcd ? CompanionKind.choice : null;

/// How teams answer [question], in one line: "Slider 1900–2020 · right 1989 ±2 · timer 0:30".
String answeringSummary(Question question) {
  String n(double? v) => v == null ? '?' : formatNumber(v);
  String? timer(int? seconds) => seconds == null ? null : "timer ${timerLabel(seconds)}";
  final companion = question.companion;
  final parts = switch (question.type) {
    QuestionType.rapidFire => [
      (question.rapidFire?.mode ?? RapidMode.buzzer).uiString,
      "progress: ${(question.rapidFire?.progress ?? ProgressStyle.values.first).uiString.toLowerCase()}",
    ],
    QuestionType.topAnswers => [
      (question.topAnswers?.mode ?? TopAnswersMode.buzzer).uiString,
      ?timer(companion?.timerSeconds),
    ],
    QuestionType.matching => ["On the devices", ?timer(companion?.timerSeconds)],
    QuestionType.connections => [
      "On the devices",
      ?timer(companion?.timerSeconds),
      "${companion?.mistakes ?? 3} mistakes allowed",
    ],
    _ when companion == null => [
      if (!question.buzzerable)
        "Out loud, no buzzer"
      else if (question.noPhoneBuzzer)
        "Buzzer boxes only"
      else
        "Buzzer",
      ?timer(question.questionTimer),
    ],
    _ => [
      switch (companion.kind) {
        CompanionKind.slider => "Slider ${n(companion.min)}–${n(companion.max)}",
        CompanionKind.whiteboard => "Whiteboard, ${(_backgroundNames[companion.background] ?? "blank").toLowerCase()}",
        CompanionKind.order => "Put ${companion.options.length} in order",
        CompanionKind.match => "Match ${companion.options.length} pairs",
        CompanionKind.list => "Answer list, ${companion.listRows} rows",
        final kind => kind.uiString,
      },
      if (companion.solution != null)
        "right ${n(companion.solution)}${companion.tolerance == null || companion.tolerance == 0 ? '' : ' ±${n(companion.tolerance)}'}"
            "${companion.unit == null ? '' : ' ${companion.unit}'}",
      ?timer(companion.timerSeconds),
    ],
  };
  return parts.join(" · ");
}
