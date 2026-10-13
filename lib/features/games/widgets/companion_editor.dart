import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';

/// Sets up what the teams' own devices show while a question is open: a
/// whiteboard, a number to enter, items to sort, and so on. Stored on the
/// question as `companion`; null removes it.
class CompanionEditor extends StatefulWidget {
  const CompanionEditor({super.key, required this.question, required this.save});

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
};

class _CompanionEditorState extends State<CompanionEditor> {
  late CompanionKind? _kind;
  late int? _timer;
  late String _background;
  late int _listRows;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late final TextEditingController _step;
  late final TextEditingController _unit;
  late final TextEditingController _solution;
  late final List<TextEditingController> _options;
  late final List<TextEditingController> _targets;

  @override
  void initState() {
    super.initState();
    final spec = CompanionSpec.fromMap(widget.question.data['companion']);
    String n(double? v) => v == null ? '' : formatNumber(v);
    _kind = spec?.kind;
    _timer = spec?.timerSeconds;
    _background = spec?.background ?? 'blank';
    _listRows = spec?.listRows ?? 5;
    _min = TextEditingController(text: n(spec?.min));
    _max = TextEditingController(text: n(spec?.max));
    _step = TextEditingController(text: n(spec?.step));
    _unit = TextEditingController(text: spec?.unit ?? '');
    _solution = TextEditingController(text: n(spec?.solution));
    _options = [for (final option in spec?.options ?? const <String>[]) TextEditingController(text: option)];
    _targets = [
      for (var i = 0; i < _options.length; i++) TextEditingController(text: spec?.targets.elementAtOrNull(i) ?? ''),
    ];
  }

  @override
  void dispose() {
    for (final controller in [_min, _max, _step, _unit, _solution, ..._options, ..._targets]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasItems => _kind == CompanionKind.order || _kind == CompanionKind.match;

  bool get _hasRange => _kind == CompanionKind.number || _kind == CompanionKind.slider;

  void _write() {
    final kind = _kind;
    if (kind == null) {
      widget.save({'companion': null});
      return;
    }
    double? n(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));
    widget.save({
      'companion': CompanionSpec(
        kind: kind,
        timerSeconds: _timer,
        background: _background,
        listRows: _listRows,
        min: _hasRange ? n(_min) : null,
        max: _hasRange ? n(_max) : null,
        step: kind == CompanionKind.slider ? n(_step) : null,
        unit: _hasRange && _unit.text.trim().isNotEmpty ? _unit.text.trim() : null,
        solution: _hasRange ? n(_solution) : null,
        options: _hasItems ? [for (final c in _options) c.text] : const [],
        targets: kind == CompanionKind.match ? [for (final c in _targets) c.text] : const [],
      ).toMap(),
      // Teams answer on their devices; a buzzer would only get in the way.
      if (widget.question.type == QuestionType.free) 'noBuzzer': true,
    });
  }

  void _change(VoidCallback change) {
    setState(change);
    _write();
  }

  Widget _number(TextEditingController controller, String label) => SizedBox(
        width: 110,
        child: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, isDense: true),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          onChanged: (_) => _write(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = _kind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Text("On the teams' devices", style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        Text(
          "Opens on every team's device with the question. You see the answers as they are written and decide when to show them.",
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownMenu<CompanionKind?>(
              label: const Text("Screen"),
              initialSelection: kind,
              dropdownMenuEntries: [
                const DropdownMenuEntry(value: null, label: "Nothing"),
                for (final option in CompanionKind.values)
                  // "Pick one" takes its options from an ABCD question.
                  if (option != CompanionKind.choice || widget.question.type == QuestionType.abcd)
                    DropdownMenuEntry(value: option, label: option.uiString),
              ],
              onSelected: (value) => _change(() => _kind = value),
            ),
            if (kind != null)
              DropdownMenu<int?>(
                label: const Text("Timer"),
                initialSelection: _timer,
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: "No timer"),
                  for (final seconds in [10, 20, 30, 45, 60, 90, 120, 180, 300])
                    DropdownMenuEntry(value: seconds, label: seconds < 60 ? "$seconds seconds" : "${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} minutes"),
                ],
                onSelected: (value) => _change(() => _timer = value),
              ),
            if (kind == CompanionKind.whiteboard)
              DropdownMenu<String>(
                label: const Text("Paper"),
                initialSelection: _background,
                dropdownMenuEntries: [
                  for (final entry in _backgroundNames.entries) DropdownMenuEntry(value: entry.key, label: entry.value),
                ],
                onSelected: (value) => _change(() => _background = value ?? 'blank'),
              ),
            if (kind == CompanionKind.whiteboard && _background == 'list')
              DropdownMenu<int>(
                label: const Text("Rows"),
                initialSelection: _listRows,
                dropdownMenuEntries: [for (var rows = 2; rows <= 12; rows++) DropdownMenuEntry(value: rows, label: "$rows")],
                onSelected: (value) => _change(() => _listRows = value ?? 5),
              ),
            if (_hasRange) ...[
              _number(_solution, "Right value"),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _unit,
                  decoration: const InputDecoration(labelText: "Unit", isDense: true),
                  onChanged: (_) => _write(),
                ),
              ),
            ],
            if (kind == CompanionKind.slider) ...[_number(_min, "From"), _number(_max, "To"), _number(_step, "Step")],
          ],
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
              padding: const EdgeInsets.only(top: 8),
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
