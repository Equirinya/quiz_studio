import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quiz_show/core/theme.dart';
import 'package:quiz_show/features/assistant/assistant.dart';

/// The assistant switch on the account page, bound to [Assistant.instance].
class AssistantSection extends StatelessWidget {
  const AssistantSection({super.key});

  @override
  Widget build(BuildContext context) {
    final assistant = Assistant.instance;
    return ListenableBuilder(
      listenable: assistant,
      builder: (context, _) => AssistantCard(
        running: assistant.running,
        url: assistant.url,
        command: assistant.connectCommand,
        activity: assistant.activity,
        onChanged: (on) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await (on ? assistant.start() : assistant.stop());
          } catch (_) {
            messenger.showSnackBar(const SnackBar(content: Text("Could not start the assistant connection.")));
          }
        },
      ),
    );
  }
}

/// The assistant switch and, while it is on, how to connect and what was done.
class AssistantCard extends StatelessWidget {
  const AssistantCard({
    super.key,
    required this.running,
    required this.url,
    required this.command,
    required this.activity,
    required this.onChanged,
  });

  final bool running;
  final String? url;
  final String? command;
  final List<String> activity;
  final ValueChanged<bool> onChanged;

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied.")));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: kMonospaceFamily,
      fontFamilyFallback: kMonospaceFallback,
      color: scheme.onSurface,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.auto_awesome_outlined),
          title: const Text("Let Claude edit my games"),
          subtitle: Text(running
              ? "On until you switch it off or close the app"
              : "Claude on this computer can read your games and add categories and questions"),
          value: running,
          onChanged: onChanged,
        ),
        if (running && command != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Run this once in a terminal, then ask Claude about your games:", style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: SelectableText(command!, style: mono)),
                    IconButton(
                      tooltip: "Copy command",
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () => _copy(context, command!),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Any program on this computer can use this connection while it is on. Other devices cannot reach it.",
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (activity.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text("Changes made", style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  for (final line in activity.take(8))
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 8),
                      child: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                    ),
                  if (activity.length > 8)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text("and ${activity.length - 8} more", style: theme.textTheme.bodySmall),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
