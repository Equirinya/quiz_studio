import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/widgets/script_format.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// The gamemaster's script of one game, see [GameScript].
class ScriptEditorPage extends StatefulWidget {
  const ScriptEditorPage({super.key, required this.gameId});

  final String gameId;

  @override
  State<ScriptEditorPage> createState() => _ScriptEditorPageState();
}

class _ScriptEditorPageState extends State<ScriptEditorPage> {
  late final Stream<GameSnapshot> _game = GameRepository.instance.watchGame(widget.gameId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameSnapshot>(
      stream: _game,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.script)),
            body: Center(child: snapshot.hasError ? Text(context.l10n.gameNotAvailable) : const CupertinoActivityIndicator()),
          );
        }
        return ScriptEditorView(
          game: data.content,
          save: (update) => GameRepository.instance.updateGame(widget.gameId, update),
        );
      },
    );
  }
}

/// The script as one document: the game's categories and questions as fixed
/// dividers in playing order, free formatted text between them.
class ScriptEditorView extends StatefulWidget {
  const ScriptEditorView({super.key, required this.game, required this.save});

  final GameContent game;

  /// Stores an update of the game document.
  final Future<void> Function(Map<String, dynamic> update) save;

  @override
  State<ScriptEditorView> createState() => _ScriptEditorViewState();
}

class _ScriptEditorViewState extends State<ScriptEditorView> {
  final _controllers = <String, ScriptTextController>{};
  final _focus = <String, FocusNode>{};
  final _pending = <String, Timer>{};
  String? _activeKey;
  bool _failed = false;

  static const _saveDelay = Duration(milliseconds: 800);

  ScriptTextController _controller(String key, GameScript script) => _controllers.putIfAbsent(key, () {
    final controller = ScriptTextController(text: script.text(key));
    controller.addListener(() => _changed(key));
    return controller;
  });

  FocusNode _node(String key) => _focus.putIfAbsent(key, () {
    final node = FocusNode();
    node.addListener(() {
      if (node.hasFocus) {
        setState(() => _activeKey = key);
      } else {
        _flush(key);
      }
    });
    return node;
  });

  final _lastSaved = <String, String>{};

  /// Saves on their way, per section: until they are through, an older
  /// snapshot must not put the old text back.
  final _saving = <String, int>{};

  void _changed(String key) {
    final text = _controllers[key]!.text;
    if (text == (_lastSaved[key] ?? GameScript.of(widget.game).text(key))) return;
    _pending.remove(key)?.cancel();
    _pending[key] = Timer(_saveDelay, () => _flush(key));
  }

  void _flush(String key) {
    final timer = _pending.remove(key);
    if (timer == null) return;
    timer.cancel();
    final text = _controllers[key]?.text;
    if (text == null) return;
    _lastSaved[key] = text;
    _saving[key] = (_saving[key] ?? 0) + 1;
    widget.save(GameScript.of(widget.game).updateFor(key, text)).then((_) {
      if (mounted && _failed) setState(() => _failed = false);
    }, onError: (_) {
      if (mounted) setState(() => _failed = true);
    }).whenComplete(() => _saving[key] = _saving[key]! - 1);
  }

  @override
  void didUpdateWidget(ScriptEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Text from elsewhere (another editor, the assistant), but never into a
    // section that is being written in right now.
    final script = GameScript.of(widget.game);
    _controllers.forEach((key, controller) {
      if (_pending.containsKey(key) || (_saving[key] ?? 0) > 0 || (_focus[key]?.hasFocus ?? false)) return;
      final stored = script.text(key);
      if (controller.text != stored) {
        _lastSaved[key] = stored;
        controller.value = TextEditingValue(text: stored, selection: TextSelection.collapsed(offset: stored.length));
      }
    });
  }

  @override
  void dispose() {
    for (final key in [..._pending.keys]) {
      _flush(key);
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _format(void Function(ScriptTextController controller) apply) {
    final key = _activeKey;
    final controller = key == null ? null : _controllers[key];
    if (controller == null) return;
    apply(controller);
    _focus[key]?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final script = GameScript.of(widget.game);
    final sections = GameScript.sections(widget.game);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.script)),
      body: Column(
        children: [
          TextFieldTapRegion(child: _Toolbar(enabled: _activeKey != null, format: _format)),
          if (_failed)
            Container(
              width: double.infinity,
              color: theme.colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l10n.scriptNotSaved, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
            ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 160),
              itemCount: sections.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    child: Text(l10n.scriptExplain, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  );
                }
                final section = sections[index - 1];
                return Column(
                  key: ValueKey(section.key),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScriptDivider(section: section),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: TextField(
                        controller: _controller(section.key, script),
                        focusNode: _node(section.key),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration.collapsed(
                          hintText: _activeKey == section.key || section.kind == ScriptSectionKind.intro ? l10n.scriptWriteHere : null,
                          hintStyle: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.enabled, required this.format});

  final bool enabled;
  final void Function(void Function(ScriptTextController controller) apply) format;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    VoidCallback? run(void Function(ScriptTextController controller) apply) => enabled ? () => format(apply) : null;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(tooltip: l10n.scriptBold, icon: const Icon(Icons.format_bold), onPressed: run((c) => c.wrapSelection('**', '**'))),
            IconButton(tooltip: l10n.scriptItalic, icon: const Icon(Icons.format_italic), onPressed: run((c) => c.wrapSelection('*', '*'))),
            IconButton(tooltip: l10n.scriptHeading, icon: const Icon(Icons.title), onPressed: run((c) => c.toggleLinePrefix('# '))),
            IconButton(tooltip: l10n.scriptSubheading, icon: const Icon(Icons.text_fields), onPressed: run((c) => c.toggleLinePrefix('## '))),
            IconButton(tooltip: l10n.scriptBullet, icon: const Icon(Icons.format_list_bulleted), onPressed: run((c) => c.toggleLinePrefix('- '))),
            const SizedBox(width: 4),
            for (final color in ScriptColor.values)
              IconButton(
                tooltip: l10n.scriptColour,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.circle, color: enabled ? scriptColor(color, theme.brightness) : null),
                onPressed: run((c) => c.wrapSelection('{${color.name}}', '{/}')),
              ),
            const SizedBox(width: 4),
            IconButton(tooltip: l10n.scriptClearFormat, icon: const Icon(Icons.format_clear), onPressed: run((c) => c.clearFormatting())),
          ],
        ),
      ),
    );
  }
}
