import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// The team's own colour, if it has one.
Color? teamColor(Team? team) => team?.color == null ? null : Color(team!.color!);

/// Text that reads on [background].
Color onTeamColor(Color background) => background.computeLuminance() > 0.5 ? Colors.black : Colors.white;

/// A row of colours for a team to pick from, "none" for the app's own, and
/// any other colour on a colour wheel.
class TeamColorPicker extends StatelessWidget {
  const TeamColorPicker({super.key, required this.selected, required this.onChanged});

  final int? selected;
  final ValueChanged<int?> onChanged;

  /// Any colour, on a wheel; kept as it is chosen.
  Future<void> _pick(BuildContext context, int? current) async {
    var color = Color(current ?? teamColors.first);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.customColour),
        content: SingleChildScrollView(
          child: ColorPicker(
            color: color,
            onColorChanged: (value) => color = value,
            onColorChangeEnd: (value) => onChanged(value.withAlpha(255).toARGB32()),
            enableShadesSelection: false,
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.both: false,
              ColorPickerType.primary: false,
              ColorPickerType.accent: false,
              ColorPickerType.wheel: true,
            },
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              onChanged(color.withAlpha(255).toARGB32());
              Navigator.of(context).pop();
            },
            child: Text(context.l10n.done),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget dot(int? color, double size) {
      final on = color == selected;
      return Tooltip(
        message: color == null ? context.l10n.noColour : context.l10n.useThisColour,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onChanged(color),
          child: Container(
            width: size,
            height: size,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color == null ? scheme.surfaceContainerHighest : Color(color),
              border: Border.all(color: on ? scheme.onSurface : Colors.transparent, width: 3),
            ),
            child: color == null ? Icon(Icons.format_color_reset_outlined, size: 18, color: scheme.outline) : null,
          ),
        ),
      );
    }

    // A colour of its own: shown as picked, and tapped to change it again.
    final custom = selected != null && !teamColors.contains(selected) ? selected : null;
    Widget wheel(double size) => Tooltip(
      message: context.l10n.customColour,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _pick(context, custom),
        child: Container(
          width: size,
          height: size,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: custom == null ? null : Color(custom),
            gradient: custom != null
                ? null
                : const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red]),
            border: Border.all(color: custom != null ? scheme.onSurface : Colors.transparent, width: 3),
          ),
          child: Icon(Icons.colorize, size: 16, color: custom == null ? Colors.white : onTeamColor(Color(custom))),
        ),
      ),
    );

    // One row on a phone too: the dots shrink a little rather than wrap.
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.maxWidth.isFinite ? (box.maxWidth / (teamColors.length + 2) - 8).clamp(24.0, 36.0) : 36.0;
        return Wrap(
          alignment: WrapAlignment.center,
          children: [dot(null, size), for (final color in teamColors) dot(color, size), wheel(size)],
        );
      },
    );
  }
}
