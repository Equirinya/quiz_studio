import 'package:flutter/material.dart';

/// A group of settings in the question editor: a header with what is set in
/// one line, which opens to show the settings themselves. Closed, the
/// settings stay alive, so nothing typed is lost.
class EditorSection extends StatelessWidget {
  const EditorSection({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  final IconData icon;
  final String title;

  /// What is set right now, in a few words; shown while closed.
  final String summary;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Icon(icon, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleSmall),
                          if (!open)
                            Text(
                              summary,
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Icon(open ? Icons.expand_less : Icons.expand_more, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            Visibility(
              visible: open,
              maintainState: true,
              child: Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fields side by side in equal columns, as many as fit at [minWidth] each:
/// labels always have room, on a phone as on a wide screen.
class FieldGrid extends StatelessWidget {
  const FieldGrid({super.key, required this.children, this.minWidth = 140});

  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final columns = (box.maxWidth / minWidth).floor().clamp(1, children.isEmpty ? 1 : children.length);
        final width = (box.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

/// A [DropdownMenu] as wide as the space it gets, e.g. a cell of a [FieldGrid].
class FillDropdown<T> extends StatelessWidget {
  const FillDropdown({super.key, required this.label, required this.value, required this.entries, required this.onSelected});

  final String label;
  final T value;
  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => DropdownMenu<T>(
        // A new selection from outside shows at once.
        key: ValueKey(value),
        width: box.maxWidth,
        label: Text(label),
        initialSelection: value,
        dropdownMenuEntries: entries,
        onSelected: onSelected,
      ),
    );
  }
}

/// The times every timer in the editor offers, in seconds.
const List<int> kTimerChoices = [10, 20, 30, 45, 60, 90, 120, 180, 300];

/// A timer the way the editor writes it everywhere: "0:30", "1:30", "5:00",
/// like the clock on the screen.
String timerLabel(int? seconds) =>
    seconds == null || seconds <= 0 ? "No timer" : "${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}";

/// Picks a question's timer from [kTimerChoices]; a time set elsewhere (e.g.
/// by the assistant) stays offered.
class TimerDropdown extends StatelessWidget {
  const TimerDropdown({super.key, required this.seconds, required this.onChanged});

  final int? seconds;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final choices = [...kTimerChoices, if (seconds != null && !kTimerChoices.contains(seconds)) seconds!]..sort();
    return FillDropdown<int?>(
      label: "Timer",
      value: seconds,
      entries: [
        const DropdownMenuEntry(value: null, label: "No timer"),
        for (final choice in choices) DropdownMenuEntry(value: choice, label: timerLabel(choice)),
      ],
      onSelected: onChanged,
    );
  }
}

/// Whether teams may lock in their answer before the time is up.
class LockInSwitch extends StatelessWidget {
  const LockInSwitch({super.key, required this.value, required this.onChanged, this.title = "Teams can lock in early"});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        value
            ? "Locking in ends a team's time, and how long it took is kept"
            : "Every answer counts as it stands when the time is up or you end the round",
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
