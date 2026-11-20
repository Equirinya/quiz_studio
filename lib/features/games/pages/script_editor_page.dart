import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/widgets/script_format.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// The gamemaster's script of one game, see [GameScript]; with
/// [categoryId] only that category's part of it.
class ScriptEditorPage extends StatefulWidget {
  const ScriptEditorPage({super.key, required this.gameId, this.categoryId});

  final String gameId;
  final String? categoryId;

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
          categoryId: widget.categoryId,
          save: (update) => GameRepository.instance.updateGame(widget.gameId, update),
        );
      },
    );
  }
}

/// The script as one document: the game's categories and questions as fixed
/// dividers in playing order, free formatted text between them.
class ScriptEditorView extends StatefulWidget {
  const ScriptEditorView({super.key, required this.game, required this.save, this.categoryId});

  final GameContent game;

  /// Only this category and its questions: the same sections as in the
  /// whole script, so what is written here is there too.
  final String? categoryId;

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

  final _scroll = ScrollController();

  /// Around each section's text field, to scroll to it.
  final _fieldKeys = <String, GlobalKey>{};

  // ── search ──
  bool _searching = false;
  final _query = TextEditingController();
  final _searchFocus = FocusNode();

  /// Every match, in document order: the section and where in its text.
  List<({String key, TextRange range})> _matches = const [];
  int _match = 0;

  static const _saveDelay = Duration(milliseconds: 800);

  /// The sections shown: all of the game's, or one category's.
  List<ScriptSection> get _sections {
    final all = GameScript.sections(widget.game);
    final category = widget.categoryId;
    return category == null ? all : [for (final section in all) if (section.categoryId == category) section];
  }

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
    // Matches move as the text changes.
    if (_searching) _findMatches();
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

  void _openSearch() {
    setState(() => _searching = true);
    _query.selection = TextSelection(baseOffset: 0, extentOffset: _query.text.length);
    _searchFocus.requestFocus();
    _findMatches();
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _matches = const [];
    });
    for (final controller in _controllers.values) {
      controller.setHighlights(const [], null);
    }
  }

  /// Looks for the query in every section, ignoring case, and marks what it
  /// finds; [jump] scrolls to the current match.
  void _findMatches({bool jump = false}) {
    final query = _query.text.toLowerCase();
    final found = <({String key, TextRange range})>[];
    if (query.isNotEmpty) {
      for (final section in _sections) {
        final text = (_controllers[section.key]?.text ?? GameScript.of(widget.game).text(section.key)).toLowerCase();
        for (var at = text.indexOf(query); at >= 0; at = text.indexOf(query, at + query.length)) {
          found.add((key: section.key, range: TextRange(start: at, end: at + query.length)));
        }
      }
    }
    setState(() {
      _matches = found;
      if (_match >= found.length) _match = 0;
    });
    _mark();
    if (jump) _reveal();
  }

  void _mark() {
    final script = GameScript.of(widget.game);
    for (final section in _sections) {
      final mine = [
        for (final (i, match) in _matches.indexed)
          if (match.key == section.key) (i, match.range),
      ];
      // Every section with a match needs its controller to show it.
      if (mine.isEmpty && !_controllers.containsKey(section.key)) continue;
      final current = mine.indexWhere((m) => m.$1 == _match);
      _controller(section.key, script).setHighlights([for (final m in mine) m.$2], current < 0 ? null : current);
    }
  }

  void _step(int by) {
    if (_matches.isEmpty) return;
    setState(() => _match = (_match + by) % _matches.length);
    _mark();
    _reveal();
  }

  /// Scrolls the current match to a third of the way down.
  void _reveal() {
    if (_matches.isEmpty) return;
    final match = _matches[_match];
    final editable = _findEditable(_fieldKeys[match.key]?.currentContext?.findRenderObject());
    if (editable == null) return;
    final caret = editable.getLocalRectForCaret(TextPosition(offset: match.range.start));
    final target = RenderAbstractViewport.of(editable).getOffsetToReveal(editable, 0.3, rect: caret).offset;
    final position = _scroll.position;
    _scroll.animateTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  static RenderEditable? _findEditable(RenderObject? object) {
    if (object == null || object is RenderEditable) return object as RenderEditable?;
    RenderEditable? found;
    object.visitChildren((child) => found ??= _findEditable(child));
    return found;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _query.dispose();
    _searchFocus.dispose();
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
    final sections = _sections;
    final category = widget.categoryId == null ? null : widget.game.category(widget.categoryId!);
    final searchShortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): _openSearch,
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _openSearch,
      if (_searching) const SingleActivator(LogicalKeyboardKey.escape): _closeSearch,
    };
    return CallbackShortcuts(
      bindings: searchShortcuts,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: _searching
                ? _searchField(context)
                : Text(category == null ? l10n.script : '${l10n.script} · ${category.name.isEmpty ? l10n.unnamed : category.name}'),
            actions: [
              if (_searching) ...[
                Center(
                  child: Text(
                    _matches.isEmpty ? '0/0' : '${_match + 1}/${_matches.length}',
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                IconButton(tooltip: l10n.scriptPreviousMatch, icon: const Icon(Icons.keyboard_arrow_up), onPressed: _matches.isEmpty ? null : () => _step(-1)),
                IconButton(tooltip: l10n.scriptNextMatch, icon: const Icon(Icons.keyboard_arrow_down), onPressed: _matches.isEmpty ? null : () => _step(1)),
                IconButton(tooltip: l10n.close, icon: const Icon(Icons.close), onPressed: _closeSearch),
              ] else
                IconButton(tooltip: l10n.scriptSearch, icon: const Icon(Icons.search), onPressed: _openSearch),
            ],
          ),
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
                // All of it laid out at once: with sections of very different
                // lengths, a lazily built list guesses its length and the
                // scrollbar jumps.
                child: Scrollbar(
                  controller: _scroll,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 160),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                          child: Text(l10n.scriptExplain, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ),
                        for (final section in sections) ...[
                          ScriptDivider(key: ValueKey('divider ${section.key}'), section: section),
                          Padding(
                            key: _fieldKeys.putIfAbsent(section.key, GlobalKey.new),
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
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, shift: true): () => _step(-1),
          const SingleActivator(LogicalKeyboardKey.escape): _closeSearch,
        },
        child: TextField(
          controller: _query,
          focusNode: _searchFocus,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: context.l10n.scriptSearchHint, border: InputBorder.none),
          onChanged: (_) {
            _match = 0;
            _findMatches(jump: true);
          },
          onSubmitted: (_) {
            _step(1);
            _searchFocus.requestFocus();
          },
        ),
      );
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
