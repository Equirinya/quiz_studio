import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quiz_show/core/theme.dart';
import 'package:quiz_show/features/assistant/assistant.dart';

/// The assistant switch on the account page, bound to [Assistant.instance].
/// Remembers which program the user connects with.
class AssistantSection extends StatefulWidget {
  const AssistantSection({super.key});

  @override
  State<AssistantSection> createState() => _AssistantSectionState();
}

class _AssistantSectionState extends State<AssistantSection> {
  static const String _clientKey = 'assistant_client';
  AssistantClient _client = AssistantClient.claudeCode;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final saved = AssistantClient.values.where((c) => c.name == prefs.getString(_clientKey)).firstOrNull;
      if (saved != null && mounted) setState(() => _client = saved);
    }).catchError((_) {});
  }

  void _pick(AssistantClient client) {
    setState(() => _client = client);
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_clientKey, client.name)).catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final assistant = Assistant.instance;
    return ListenableBuilder(
      listenable: assistant,
      builder: (context, _) => AssistantCard(
        running: assistant.running,
        url: assistant.url,
        client: _client,
        onClientChanged: _pick,
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

/// The assistant switch and, while it is on, how to connect from the chosen
/// program and what was done.
class AssistantCard extends StatelessWidget {
  const AssistantCard({
    super.key,
    required this.running,
    required this.url,
    required this.client,
    required this.onClientChanged,
    required this.activity,
    required this.onChanged,
  });

  final bool running;
  final String? url;
  final AssistantClient client;
  final ValueChanged<AssistantClient> onClientChanged;
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
    final snippet = url == null ? null : client.snippet(url!);
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
          title: const Text("Let an AI assistant edit my games"),
          subtitle: Text(running
              ? "On until you switch it off or close the app"
              : "An AI assistant on this computer, such as Claude, can read your games and edit them"),
          value: running,
          onChanged: onChanged,
        ),
        if (running && url != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Connect with", style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                _ClientPicker(client: client, onChanged: onClientChanged),
                const SizedBox(height: 12),
                Text(client.instructions, style: theme.textTheme.bodyMedium),
                if (snippet != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: SelectableText(snippet, style: mono)),
                      IconButton(
                        tooltip: client.isCommand ? "Copy command" : "Copy settings",
                        icon: const Icon(Icons.copy_outlined),
                        onPressed: () => _copy(context, snippet),
                      ),
                    ],
                  ),
                ],
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

/// The programs as one segmented button. There are more than fit side by
/// side, so the row scrolls, and it brings the chosen one into view.
class _ClientPicker extends StatefulWidget {
  const _ClientPicker({required this.client, required this.onChanged});

  final AssistantClient client;
  final ValueChanged<AssistantClient> onChanged;

  @override
  State<_ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends State<_ClientPicker> {
  final Map<AssistantClient, GlobalKey> _keys = {for (final c in AssistantClient.values) c: GlobalKey()};
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _reveal(animate: false);
  }

  @override
  void didUpdateWidget(_ClientPicker old) {
    super.didUpdateWidget(old);
    if (old.client != widget.client) _reveal(animate: true);
  }

  /// Centres the chosen program in the row. Only this row moves, never the
  /// page around it.
  void _reveal({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final label = _keys[widget.client]?.currentContext?.findRenderObject() as RenderBox?;
      final row = context.findRenderObject() as RenderBox?;
      if (!mounted || label == null || row == null || !_scroll.hasClients) return;
      final centre = label.localToGlobal(label.size.center(Offset.zero), ancestor: row).dx;
      final target = (_scroll.offset + centre - row.size.width / 2).clamp(0.0, _scroll.position.maxScrollExtent);
      if (animate) {
        _scroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 8),
        child: SegmentedButton<AssistantClient>(
          segments: [
            for (final c in AssistantClient.values) ButtonSegment(value: c, label: Text(c.label, key: _keys[c])),
          ],
          selected: {widget.client},
          showSelectedIcon: false,
          onSelectionChanged: (picked) => widget.onChanged(picked.single),
        ),
      );
}
