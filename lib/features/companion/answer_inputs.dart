import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/game/game.dart';

/// The input a team's device shows for an answer round. [spec] is the public
/// form of the round's setup (`CompanionSpec.toPublicMap`): no solution, and
/// the items to sort or assign already shuffled.
///
/// [onChanged] fires with the answer as it stands whenever it changes, so
/// the gamemaster can watch along; typing is held back for a moment first.
class CompanionInput extends StatefulWidget {
  const CompanionInput({
    super.key,
    required this.spec,
    required this.onChanged,
    this.enabled = true,
    this.whiteboardAspect = kWhiteboardAspect,
    this.backgroundImage,
  });

  /// Whiteboards with a picture as paper: the picture, once it has arrived.
  final ImageProvider? backgroundImage;

  /// Whiteboards only: the board's width / height, chosen to fit the device.
  final double whiteboardAspect;

  final Map<String, dynamic> spec;
  final ValueChanged<PlayerAnswer> onChanged;
  final bool enabled;

  @override
  State<CompanionInput> createState() => _CompanionInputState();
}

class _Item {
  const _Item(this.index, this.text);

  /// Position in the original, unshuffled list; what the answer refers to.
  final int index;
  final String text;
}

class _CompanionInputState extends State<CompanionInput> {
  late final CompanionKind _kind = CompanionKind.fromName(widget.spec['kind']) ?? CompanionKind.text;
  final TextEditingController _text = TextEditingController();
  Timer? _debounce;

  // slider
  late final CompanionSpec _range = CompanionSpec.fromMap(widget.spec) ?? const CompanionSpec(kind: CompanionKind.slider);
  late double _value = (_range.range.min + _range.range.max) / 2;
  bool _moved = false;

  // choice
  int? _choice;

  // order: the items in the team's current order
  late final List<_Item> _items = [
    for (final entry in widget.spec['items'] as List? ?? const [])
      _Item(((entry as Map)['i'] as num).toInt(), entry['t'] as String),
  ];

  // match: for each left-hand item, the chosen right-hand item
  late final List<String> _left = (widget.spec['options'] as List? ?? const []).cast<String>();
  late final List<int> _pairs = List.filled(_left.length, -1);

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _later(PlayerAnswer Function() answer) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => widget.onChanged(answer()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.enabled;
    switch (_kind) {
      case CompanionKind.whiteboard:
        return WhiteboardPad(
          enabled: enabled,
          aspect: widget.whiteboardAspect,
          backgroundImage: widget.backgroundImage,
          background: widget.spec['background'] as String? ?? 'blank',
          listRows: (widget.spec['listRows'] as num?)?.toInt() ?? 5,
          onChanged: (drawing) => widget.onChanged(PlayerAnswer(drawing: drawing)),
        );

      case CompanionKind.text:
        return TextField(
          controller: _text,
          enabled: enabled,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          style: theme.textTheme.headlineSmall,
          decoration: const InputDecoration(labelText: "Your answer"),
          onChanged: (text) => _later(() => PlayerAnswer(text: text.trim())),
        );

      case CompanionKind.number:
        return TextField(
          controller: _text,
          enabled: enabled,
          autofocus: true,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))],
          decoration: InputDecoration(labelText: "Your number", suffixText: widget.spec['unit'] as String?),
          onChanged: (text) {
            final number = double.tryParse(text.replaceAll(',', '.'));
            if (number != null) _later(() => PlayerAnswer(number: number));
          },
        );

      case CompanionKind.slider:
        final range = _range.range;
        final divisions = ((range.max - range.min) / range.step).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _moved ? formatNumber(_value, unit: _range.unit) : "Slide to answer",
              style: _moved ? theme.textTheme.displaySmall : theme.textTheme.titleLarge,
            ),
            Slider(
              min: range.min,
              max: range.max,
              divisions: divisions > 0 && divisions <= 1000 ? divisions : null,
              value: _value,
              onChanged: !enabled
                  ? null
                  : (value) => setState(() {
                        // Snap to the step, so 37.999 does not sneak in.
                        _value = ((value - range.min) / range.step).round() * range.step + range.min;
                        _moved = true;
                      }),
              onChangeEnd: (_) => widget.onChanged(PlayerAnswer(number: _value)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatNumber(range.min, unit: _range.unit)),
                Text(formatNumber(range.max, unit: _range.unit)),
              ],
            ),
          ],
        );

      case CompanionKind.choice:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, option) in _left.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: i == _choice
                      ? FilledButton(onPressed: enabled ? () {} : null, child: Text("${String.fromCharCode(0x41 + i)}   $option"))
                      : FilledButton.tonal(
                          onPressed: !enabled
                              ? null
                              : () {
                                  setState(() => _choice = i);
                                  widget.onChanged(PlayerAnswer(choice: i));
                                },
                          child: Text("${String.fromCharCode(0x41 + i)}   $option"),
                        ),
                ),
              ),
          ],
        );

      case CompanionKind.order:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Drag into the right order", style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Flexible(
              child: ReorderableListView(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                // onReorderItem replaces this from Flutter 3.41 on; kept for older SDKs in CI.
                // ignore: deprecated_member_use
                onReorder: (from, to) {
                  if (!enabled) return;
                  setState(() {
                    if (to > from) to -= 1;
                    _items.insert(to, _items.removeAt(from));
                  });
                  widget.onChanged(PlayerAnswer(order: [for (final item in _items) item.index]));
                },
                children: [
                  for (final (i, item) in _items.indexed)
                    Card(
                      key: ValueKey(item.index),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(child: Text("${i + 1}")),
                        title: Text(item.text),
                        trailing: enabled
                            ? ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle))
                            : const Icon(Icons.lock_outline),
                      ),
                    ),
                ],
              ),
            ),
            if (enabled)
              TextButton(
                onPressed: () => widget.onChanged(PlayerAnswer(order: [for (final item in _items) item.index])),
                child: const Text("This order is right"),
              ),
          ],
        );

      case CompanionKind.match:
        return ListView(
          shrinkWrap: true,
          children: [
            for (final (i, left) in _left.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(left, style: theme.textTheme.titleMedium)),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward)),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        // Rebuilt when another row takes this row's item away.
                        key: ValueKey('$i/${_pairs[i]}'),
                        initialValue: _pairs[i] < 0 ? null : _pairs[i],
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        hint: const Text("Choose"),
                        items: [for (final item in _items) DropdownMenuItem(value: item.index, child: Text(item.text, overflow: TextOverflow.ellipsis))],
                        onChanged: !enabled
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  // Each right-hand item goes to one place only.
                                  for (var other = 0; other < _pairs.length; other++) {
                                    if (_pairs[other] == value) _pairs[other] = -1;
                                  }
                                  _pairs[i] = value;
                                });
                                widget.onChanged(PlayerAnswer(pairs: List.of(_pairs)));
                              },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

      case CompanionKind.connections:
        // Played on a screen of its own; see ConnectionsPlay.
        return const SizedBox();
    }
  }
}
