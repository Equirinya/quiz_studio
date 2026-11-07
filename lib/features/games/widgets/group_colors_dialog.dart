import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';

/// Picks the two colours a group's board is themed with. [save] receives the
/// ARGB values, or nulls to go back to the app's own colours.
Future<void> showGroupColorsDialog(
  BuildContext context, {
  required CategoryGroup group,
  required void Function(int? color, int? accentColor) save,
}) =>
    showDialog<void>(context: context, builder: (_) => _GroupColorsDialog(group: group, save: save));

class _GroupColorsDialog extends StatefulWidget {
  const _GroupColorsDialog({required this.group, required this.save});

  final CategoryGroup group;
  final void Function(int? color, int? accentColor) save;

  @override
  State<_GroupColorsDialog> createState() => _GroupColorsDialogState();
}

class _GroupColorsDialogState extends State<_GroupColorsDialog> {
  late Color? _color = widget.group.color == null ? null : Color(widget.group.color!);
  late Color? _accent = widget.group.accentColor == null ? null : Color(widget.group.accentColor!);

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
      title: const Text("Board colours"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _picker("Primary", _color ?? scheme.primary, (value) => _color = value),
            const SizedBox(height: 16),
            _picker("Accent", _accent ?? scheme.tertiary, (value) => _accent = value),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.save(null, null);
            Navigator.of(context).pop();
          },
          child: const Text("Use app colours"),
        ),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Done")),
      ],
    );
  }
}
