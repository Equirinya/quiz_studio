import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quiz_show/features/companion/match_input.dart';
import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

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
    this.pictures = const {},
    this.teamAnswer,
  });

  /// The team's answer as the host has it. Another phone of the same team
  /// may have changed it; this one then follows (not for whiteboards and
  /// matching, which keep their own).
  final PlayerAnswer? teamAnswer;

  /// Matching: the round's pictures that have arrived, by media name.
  final Map<String, Uint8List> pictures;

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

  // choice with several picks allowed
  late final bool _multiple = widget.spec['multiple'] == true;
  final List<int> _choices = [];

  // order: the items in the team's current order
  late final List<_Item> _items = [
    for (final entry in widget.spec['items'] as List? ?? const [])
      _Item(((entry as Map)['i'] as num).toInt(), context.l10n.deviceLabel(entry['t'] as String)),
  ];

  // order: each item's picture name and raw label, by original index
  late final Map<int, (String?, String)> _orderRaw = {
    for (final entry in widget.spec['items'] as List? ?? const [])
      ((entry as Map)['i'] as num).toInt(): (entry['img'] is String ? entry['img'] as String : null, '${entry['t']}'),
  };

  // choice and match: the options (match: the left-hand items)
  late final List<String> _left = [for (final option in (widget.spec['options'] as List? ?? const []).cast<String>()) context.l10n.deviceLabel(option)];

  // list: one field per answer
  late final List<TextEditingController> _lines = [
    for (var i = 0; i < ((widget.spec['listRows'] as num?)?.toInt() ?? 5).clamp(1, maxListRows(CompanionKind.list)); i++) TextEditingController(),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    for (final line in _lines) {
      line.dispose();
    }
    _text.dispose();
    super.dispose();
  }

  /// What this phone sent lately; the host's copies of these are not news.
  final List<String> _sent = [];

  static String _content(PlayerAnswer answer) => jsonEncode(answer.asLocked(false).toJson());

  void _emit(PlayerAnswer answer) {
    _sent.add(_content(answer));
    if (_sent.length > 8) _sent.removeAt(0);
    widget.onChanged(answer);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A phone that joins or comes back mid-round starts from the team's answer.
    _follow(widget.teamAnswer);
    // Sorting: the order as shown counts as the team's answer from the
    // start, so a team that finds it right can lock in without dragging.
    if (_kind == CompanionKind.order && widget.enabled && widget.teamAnswer == null && !_startSent && _items.isNotEmpty) {
      _startSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.teamAnswer == null) _emit(PlayerAnswer(order: [for (final item in _items) item.index]));
      });
    }
  }

  bool _startSent = false;

  @override
  void didUpdateWidget(CompanionInput old) {
    super.didUpdateWidget(old);
    _follow(widget.teamAnswer);
  }

  /// Takes over [answer] when another phone of the team made it.
  void _follow(PlayerAnswer? answer) {
    if (answer == null || answer.isEmpty) return;
    final content = _content(answer);
    if (_sent.contains(content)) return;
    _sent.add(content);
    if (_sent.length > 8) _sent.removeAt(0);
    switch (_kind) {
      case CompanionKind.text when answer.text != null && answer.text != _text.text.trim():
        _text.text = answer.text!;
      case CompanionKind.number when answer.number != null:
        _text.text = formatNumber(answer.number!);
      case CompanionKind.slider when answer.number != null:
        _value = answer.number!;
        _moved = true;
      case CompanionKind.choice:
        _choice = answer.choice ?? _choice;
        if (answer.choices != null) {
          _choices
            ..clear()
            ..addAll(answer.choices!);
        }
      case CompanionKind.order when answer.order != null:
        final byIndex = {for (final item in _items) item.index: item};
        final ordered = [for (final index in answer.order!) ?byIndex[index]];
        if (ordered.length == _items.length) {
          _items
            ..clear()
            ..addAll(ordered);
        }
      case CompanionKind.list when answer.items != null:
        for (final (i, line) in _lines.indexed) {
          final text = answer.items!.elementAtOrNull(i) ?? '';
          if (line.text.trim() != text) line.text = text;
        }
      default:
        break;
    }
  }

  void _later(PlayerAnswer Function() answer) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _emit(answer()));
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
          onChanged: (drawing) => _emit(PlayerAnswer(drawing: drawing)),
        );

      case CompanionKind.text:
        return TextField(
          controller: _text,
          enabled: enabled,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          style: theme.textTheme.headlineSmall,
          decoration: InputDecoration(labelText: context.l10n.yourAnswer),
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
          decoration: InputDecoration(labelText: context.l10n.yourNumber, suffixText: widget.spec['unit'] as String?),
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
              _moved ? formatNumber(_value, unit: _range.unit) : context.l10n.slideToAnswer,
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
              onChangeEnd: (_) => _emit(PlayerAnswer(number: _value)),
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
        // Held sideways the answers sit in a grid like on the big screen;
        // upright one under the other. Either way they scroll when there are
        // many, and the pick stays marked once it is locked in.
        return LayoutBuilder(
          builder: (context, box) {
            final sideways = box.maxWidth > box.maxHeight * 1.15;
            final columns = sideways ? (_left.length <= 4 ? 2 : 3) : 1;
            final width = (box.maxWidth - (columns - 1) * 12) / columns;
            return SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (i, option) in _left.indexed)
                    SizedBox(
                      width: width,
                      child: _ChoiceTile(
                        letter: String.fromCharCode(0x41 + i),
                        text: option,
                        selected: _multiple ? _choices.contains(i) : i == _choice,
                        several: _multiple,
                        tall: sideways,
                        onTap: !enabled
                            ? null
                            : _multiple
                            ? () {
                                setState(() => _choices.contains(i) ? _choices.remove(i) : _choices.add(i));
                                _emit(PlayerAnswer(choices: [..._choices]..sort()));
                              }
                            : () {
                                setState(() => _choice = i);
                                _emit(PlayerAnswer(choice: i));
                              },
                      ),
                    ),
                ],
              ),
            );
          },
        );

      case CompanionKind.order:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.dragIntoOrder, style: theme.textTheme.bodyMedium),
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
                  _emit(PlayerAnswer(order: [for (final item in _items) item.index]));
                },
                children: [
                  for (final (i, item) in _items.indexed)
                    Card(
                      key: ValueKey(item.index),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(child: Text("${i + 1}")),
                        title: _orderTitle(item),
                        trailing: enabled
                            ? ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle))
                            : const Icon(Icons.lock_outline),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );

      case CompanionKind.match:
        final leftImages = (widget.spec['optionImages'] as List? ?? const []);
        ImageProvider? picture(Object? name) => name is String && widget.pictures[name] != null ? MemoryImage(widget.pictures[name]!) : null;
        final rawLeft = (widget.spec['options'] as List? ?? const []).cast<String>();
        final rawRight = {
          for (final entry in widget.spec['items'] as List? ?? const []) ((entry as Map)['i'] as num).toInt(): '${entry['t']}',
        };
        final rightPictures = {
          for (final entry in widget.spec['items'] as List? ?? const [])
            ((entry as Map)['i'] as num).toInt(): ?picture(entry['img']),
        };
        // A picture without text needs no name next to it.
        return MatchInput(
          left: [
            for (final (i, label) in _left.indexed)
              picture(leftImages.elementAtOrNull(i)) != null && Matching.isPictureName(rawLeft.elementAtOrNull(i) ?? '') ? '' : label,
          ],
          leftImages: [for (var i = 0; i < _left.length; i++) picture(leftImages.elementAtOrNull(i))],
          rightImages: rightPictures,
          right: [
            for (final item in _items)
              (item.index, rightPictures[item.index] != null && Matching.isPictureName(rawRight[item.index] ?? '') ? '' : item.text),
          ],
          enabled: enabled,
          pairs: widget.teamAnswer?.pairs,
          onChanged: (pairs) => _emit(PlayerAnswer(pairs: pairs)),
        );

      case CompanionKind.connections:
        // Played on a screen of its own; see ConnectionsPlay.
        return const SizedBox();

      case CompanionKind.list:
        return ListView(
          shrinkWrap: true,
          children: [
            for (final (i, line) in _lines.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TextField(
                  controller: line,
                  enabled: enabled,
                  autofocus: i == 0,
                  textInputAction: i == _lines.length - 1 ? TextInputAction.done : TextInputAction.next,
                  style: theme.textTheme.titleLarge,
                  decoration: InputDecoration(prefixText: "${i + 1}.  ", hintText: context.l10n.answerN(i + 1)),
                  onChanged: (_) => _later(() => PlayerAnswer(items: [for (final line in _lines) line.text.trim()])),
                ),
              ),
          ],
        );
    }
  }
}

/// One answer to pick: letter and text, filled in once picked, and still
/// filled in after the answer is locked.
extension on _CompanionInputState {
  /// An entry to sort: its picture, once it has arrived, and its text; a
  /// picture alone needs no name beside it.
  Widget _orderTitle(_Item item) {
    final (name, raw) = _orderRaw[item.index] ?? (null, '');
    final bytes = name == null ? null : widget.pictures[name];
    if (bytes == null) return Text(item.text);
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, width: 56, height: 56, fit: BoxFit.cover),
        ),
        if (!Matching.isPictureName(raw)) ...[const SizedBox(width: 12), Expanded(child: Text(item.text))],
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.tall,
    this.several = false,
    this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;

  /// Several may be picked: a box to tick shows on every answer.
  final bool several;
  final bool tall;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locked = onTap == null;
    final background = selected ? scheme.primary : scheme.secondaryContainer;
    final foreground = selected ? scheme.onPrimary : scheme.onSecondaryContainer;
    return Opacity(
      opacity: locked && !selected ? 0.5 : 1,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: tall ? 88 : 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(letter, style: theme.textTheme.titleMedium?.copyWith(color: foreground, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(text, style: theme.textTheme.titleMedium?.copyWith(color: foreground))),
                  if (several && !locked)
                    Icon(selected ? Icons.check_box : Icons.check_box_outline_blank, color: foreground)
                  else if (selected)
                    Icon(locked ? Icons.lock : Icons.check_circle, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
