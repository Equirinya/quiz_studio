import 'package:flutter/material.dart';

import 'package:quiz_show/features/games/widgets/script_format.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// The game's script for reading during the show. It opens at the section
/// of the open question (or its category, or the board on screen), unless
/// the place it was left at is already close to it; see [scriptStaysPut].
class ScriptSheet extends StatefulWidget {
  const ScriptSheet({super.key, required this.game, this.current, this.groupId, this.lastOffset, this.onScrolled});

  final GameContent game;
  final QuestionRef? current;
  final String? groupId;

  /// Where the script was scrolled to when it was closed last; null at first.
  final double? lastOffset;

  /// Reports the scroll position, to pass back as [lastOffset] next time.
  final ValueChanged<double>? onScrolled;

  @override
  State<ScriptSheet> createState() => _ScriptSheetState();
}

class _ScriptSheetState extends State<ScriptSheet> {
  late final ScrollController _scroll = ScrollController(initialScrollOffset: widget.lastOffset ?? 0);
  final _content = GlobalKey();
  final _keys = <String, GlobalKey>{};

  late final String _target = GameScript.targetKey(widget.game, current: widget.current, groupId: widget.groupId);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => widget.onScrolled?.call(_scroll.offset));
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Top and bottom of a section in scroll pixels.
  (double, double)? _extent(String key) {
    final box = _keys[key]?.currentContext?.findRenderObject() as RenderBox?;
    final content = _content.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || content == null || !box.attached) return null;
    final top = box.localToGlobal(Offset.zero, ancestor: content).dy;
    return (top, top + box.size.height);
  }

  void _open() {
    if (!mounted || !_scroll.hasClients) return;
    final extent = _extent(_target);
    if (extent == null) return;
    final stays = scriptStaysPut(
      lastOffset: widget.lastOffset,
      viewport: _scroll.position.viewportDimension,
      sectionTop: extent.$1,
      sectionBottom: extent.$2,
    );
    if (!stays) _jumpTo(_target);
  }

  void _jumpTo(String key, {bool animate = false}) {
    final extent = _extent(key);
    if (extent == null || !_scroll.hasClients) return;
    final offset = extent.$1.clamp(0.0, _scroll.position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    } else {
      _scroll.jumpTo(offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final game = widget.game;
    final script = GameScript.of(game);
    final sections = GameScript.sections(game);
    final current = GameScript.targetKey(game, current: widget.current, groupId: widget.groupId);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: [
                Expanded(child: Text(l10n.script, style: theme.textTheme.titleMedium)),
                TextButton.icon(
                  onPressed: () => _jumpTo(current, animate: true),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(l10n.scriptToCurrent),
                ),
              ],
            ),
          ),
          if (!script.hasTextFor(game))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(l10n.scriptEmpty, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: Column(
                key: _content,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final section in sections)
                    Column(
                      key: _keys.putIfAbsent(section.key, GlobalKey.new),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ScriptDivider(section: section, highlight: section.key == current),
                        ScriptText(text: script.text(section.key)),
                      ],
                    ),
                  // Room to bring the last section to the top.
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
