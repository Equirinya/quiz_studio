import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';

/// The team's own colour, if it has one.
Color? teamColor(Team? team) => team?.color == null ? null : Color(team!.color!);

/// Text that reads on [background].
Color onTeamColor(Color background) => background.computeLuminance() > 0.5 ? Colors.black : Colors.white;

/// A row of colours for a team to pick from, and "none" for the app's own.
class TeamColorPicker extends StatelessWidget {
  const TeamColorPicker({super.key, required this.selected, required this.onChanged});

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget dot(int? color, double size) {
      final on = color == selected;
      return Tooltip(
        message: color == null ? "No colour" : "Use this colour",
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

    // One row on a phone too: the dots shrink a little rather than wrap.
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.maxWidth.isFinite ? (box.maxWidth / (teamColors.length + 1) - 8).clamp(24.0, 36.0) : 36.0;
        return Wrap(alignment: WrapAlignment.center, children: [dot(null, size), for (final color in teamColors) dot(color, size)]);
      },
    );
  }
}
