import 'package:flutter/material.dart';

import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/game/game.dart';

const Map<String, String> _slotLabels = {
  musicBackground: "Background music",
  musicCalm: "Calm music",
  musicExciting: "Exciting music",
};

const Map<String, String> _effectLabels = {
  effectAnswerCorrect: "Right answer",
  effectAnswerWrong: "Wrong answer",
  effectAnswerClosed: "Question closed",
  effectReveal: "Reveal",
};

/// Music and sound effects of one level: the game, a group, a category or a
/// question. What is set here overrides the levels above it.
///
/// [data] is the stored document; [save] receives partial updates for it.
Future<void> showSoundsDialog(
  BuildContext context, {
  required String gameId,
  required String title,
  required Map<String, dynamic> data,
  required void Function(Map<String, dynamic> update) save,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _SoundsDialog(gameId: gameId, title: title, data: data, save: save),
    );

class _SoundsDialog extends StatefulWidget {
  const _SoundsDialog({required this.gameId, required this.title, required this.data, required this.save});

  final String gameId;
  final String title;
  final Map<String, dynamic> data;
  final void Function(Map<String, dynamic> update) save;

  @override
  State<_SoundsDialog> createState() => _SoundsDialogState();
}

class _CustomEffect {
  _CustomEffect(String name, this.file) : name = TextEditingController(text: name);

  final TextEditingController name;
  String? file;
}

class _SoundsDialogState extends State<_SoundsDialog> {
  late final Map<String, String> _slots;
  late final Map<String, String> _builtIn;
  late final List<_CustomEffect> _custom;

  @override
  void initState() {
    super.initState();
    final config = MusicConfig.fromMap(widget.data);
    _slots = Map.of(config.slots);
    _builtIn = {
      for (final key in builtInEffects)
        if (config.effects[key] != null) key: config.effects[key]!,
    };
    final names = <String>{
      ...(widget.data['musicCustomEffect'] as List? ?? const []).whereType<String>(),
      ...config.effects.keys.where((key) => !builtInEffects.contains(key)),
    };
    _custom = [for (final name in names) _CustomEffect(name, config.effects[name])];
  }

  @override
  void dispose() {
    for (final effect in _custom) {
      effect.name.dispose();
    }
    super.dispose();
  }

  void _saveEffects() => widget.save({
        'musicEffects': {
          ..._builtIn,
          for (final effect in _custom)
            if (effect.file != null && effect.name.text.trim().isNotEmpty) effect.name.text.trim(): effect.file,
        },
        'musicCustomEffect': [
          for (final effect in _custom)
            if (effect.name.text.trim().isNotEmpty) effect.name.text.trim(),
        ],
      });

  Widget _row(String label, String? file, ValueChanged<String?> onChanged) => Row(
        children: [
          Expanded(child: Text(label)),
          MediaButton(gameId: widget.gameId, kind: MediaKind.audio, name: file, onChanged: onChanged),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget header(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Anything left empty here is taken from the level above.", style: theme.textTheme.bodySmall),
              header("Music"),
              for (final slot in musicSlots)
                _row(_slotLabels[slot]!, _slots[slot], (name) {
                  setState(() => name == null ? _slots.remove(slot) : _slots[slot] = name);
                  widget.save({slot: name});
                }),
              header("Effects"),
              for (final key in builtInEffects)
                _row(_effectLabels[key]!, _builtIn[key], (name) {
                  setState(() => name == null ? _builtIn.remove(key) : _builtIn[key] = name);
                  _saveEffects();
                }),
              header("Your own effects"),
              for (final effect in _custom)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: effect.name,
                          decoration: const InputDecoration(labelText: "Name"),
                          onChanged: (_) => _saveEffects(),
                        ),
                      ),
                      MediaButton(
                        gameId: widget.gameId,
                        kind: MediaKind.audio,
                        name: effect.file,
                        onChanged: (name) {
                          setState(() => effect.file = name);
                          _saveEffects();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: "Remove",
                        onPressed: () {
                          setState(() => _custom.remove(effect));
                          _saveEffects();
                          WidgetsBinding.instance.addPostFrameCallback((_) => effect.name.dispose());
                        },
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _custom.add(_CustomEffect('', null))),
                  icon: const Icon(Icons.add),
                  label: const Text("Add effect"),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Done"))],
    );
  }
}
