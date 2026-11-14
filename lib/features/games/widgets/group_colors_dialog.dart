import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// Picks the two colours a group's board is themed with. [save] receives the
/// ARGB values, or nulls to go back to the app's own colours.
Future<void> showGroupColorsDialog(
  BuildContext context, {
  required CategoryGroup group,
  required void Function(int? color, int? accentColor) save,
}) =>
    showColorsDialog(context, color: group.color, accentColor: group.accentColor, save: save);

/// Picks two colours, [color] and [accentColor] as they are now (ARGB, null
/// for the default ones). [save] gets nulls to go back to [resetLabel]'s.
Future<void> showColorsDialog(
  BuildContext context, {
  required int? color,
  required int? accentColor,
  required void Function(int? color, int? accentColor) save,
  String? resetLabel,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _GroupColorsDialog(color: color, accentColor: accentColor, save: save, resetLabel: resetLabel),
    );

class _GroupColorsDialog extends StatefulWidget {
  const _GroupColorsDialog({required this.color, required this.accentColor, required this.save, this.resetLabel});

  final int? color;
  final int? accentColor;
  final String? resetLabel;
  final void Function(int? color, int? accentColor) save;

  @override
  State<_GroupColorsDialog> createState() => _GroupColorsDialogState();
}

class _GroupColorsDialogState extends State<_GroupColorsDialog> {
  late Color? _color = widget.color == null ? null : Color(widget.color!);
  late Color? _accent = widget.accentColor == null ? null : Color(widget.accentColor!);

  void _save() {
    final scheme = Theme.of(context).colorScheme;
    // The board is themed from both, so picking one fixes the other as well.
    widget.save((_color ?? scheme.primary).toARGB32(), (_accent ?? scheme.tertiary).toARGB32());
  }

  Widget _picker(String label, Color color, ValueChanged<Color> onChanged) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          ColorPicker(
            color: color,
            onColorChanged: (value) => setState(() => onChanged(value)),
            onColorChangeEnd: (_) => _save(),
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.both: false,
              ColorPickerType.primary: false,
              ColorPickerType.accent: false,
              ColorPickerType.wheel: true,
            },
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(context.l10n.boardColours),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _picker(context.l10n.primaryColour, _color ?? scheme.primary, (value) => _color = value),
            const SizedBox(height: 16),
            _picker(context.l10n.accentColour, _accent ?? scheme.tertiary, (value) => _accent = value),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.save(null, null);
            Navigator.of(context).pop();
          },
          child: Text(widget.resetLabel ?? context.l10n.useAppColours),
        ),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.done)),
      ],
    );
  }
}
