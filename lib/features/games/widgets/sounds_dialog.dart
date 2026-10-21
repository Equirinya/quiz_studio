import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/game/game.dart';

const Map<String, String> _slotLabels = {
  musicBackground: "Board music",
  musicCalm: "Calm music",
  musicExciting: "Thrilling music",
};

const Map<String, String> _effectLabels = {
  effectAnswerCorrect: "Right answer",
  effectAnswerWrong: "Wrong answer",
  effectAnswerClosed: "Question closed",
  effectReveal: "Reveal",
  effectQuestionOpen: "Question opens",
  effectLockIn: "Team locks in",
  effectNextItem: "Next Fragenhagel item",
  effectCountdown: "Last 10 seconds",
  effectTimesUp: "Time's up",
  effectSteal: "Steal",
  effectFanfare: "Fully solved",
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
  bool isGame = false,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => SoundsDialog(gameId: gameId, title: title, data: data, save: save, isGame: isGame),
    );

class SoundsDialog extends StatefulWidget {
  const SoundsDialog({super.key, required this.gameId, required this.title, required this.data, required this.save, this.isGame = false});

  final String gameId;
  final String title;
  final Map<String, dynamic> data;
  final void Function(Map<String, dynamic> update) save;

  /// The game's own sounds, the top level: nothing above it but the app's.
  final bool isGame;

  @override
  State<SoundsDialog> createState() => _SoundsDialogState();
}

class _CustomEffect {
  _CustomEffect(String name, this.file) : name = TextEditingController(text: name);

  final TextEditingController name;
  String? file;
}

class _SoundsDialogState extends State<SoundsDialog> {
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
    _preview?.dispose();
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

  // Made on the first listen: a player per dialog is only needed then.
  AudioPlayer? _preview;

  static const String _ownFile = '\u0000own';

  /// One moment: a menu of what can play, and for an own file the button to
  /// pick it. A built-in sound can be listened to right here.
  Widget _effectRow(String key) {
    final value = _builtIn[key];
    final builtins = builtinSoundsFor(key);
    final isOwn = value != null && value != silentSound && !value.startsWith(builtinSoundPrefix);
    final picked = value != null && value.startsWith(builtinSoundPrefix) ? builtinSound(value) : null;
    final fallback = widget.isGame
        ? (defaultEffectSounds[key] == null ? "Nothing" : "App default: ${builtinSound(defaultEffectSounds[key]!)?.label}")
        : "As set above";
    void set(String? next) {
      setState(() => next == null ? _builtIn.remove(key) : _builtIn[key] = next);
      _saveEffects();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey('$key/$value'),
              initialValue: isOwn ? _ownFile : value ?? '',
              isExpanded: true,
              decoration: InputDecoration(labelText: _effectLabels[key], isDense: true),
              items: [
                DropdownMenuItem(value: '', child: Text(fallback)),
                for (final sound in builtins) DropdownMenuItem(value: sound.key, child: Text(sound.label)),
                const DropdownMenuItem(value: silentSound, child: Text("Silent")),
                DropdownMenuItem(value: _ownFile, child: Text(isOwn ? "Own file" : "Own file…")),
              ],
              onChanged: (next) {
                if (next == null || next == _ownFile) {
                  // Picking the file happens with the button next to it.
                  if (!isOwn) setState(() => _choosingOwn.add(key));
                  return;
                }
                _choosingOwn.remove(key);
                set(next.isEmpty ? null : next);
              },
            ),
          ),
          if (picked != null)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: "Listen",
              onPressed: () => (_preview ??= AudioPlayer()).play(AssetSource(picked.asset)),
            ),
          if (isOwn || _choosingOwn.contains(key))
            MediaButton(
              gameId: widget.gameId,
              kind: MediaKind.audio,
              name: isOwn ? value : null,
              onChanged: (name) {
                _choosingOwn.remove(key);
                set(name);
              },
            ),
        ],
      ),
    );
  }

  /// Moments where "Own file…" was chosen but no file picked yet.
  final Set<String> _choosingOwn = {};

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
              Text(
                widget.isGame
                    ? "What plays during this game. Anything not set uses the sounds that come with the app."
                    : "Anything left on \"As set above\" comes from the board or the game.",
                style: theme.textTheme.bodySmall,
              ),
              header("Music"),
              for (final slot in musicSlots)
                _row(_slotLabels[slot]!, _slots[slot], (name) {
                  setState(() => name == null ? _slots.remove(slot) : _slots[slot] = name);
                  widget.save({slot: name});
                }),
              header("Sounds at moments of the show"),
              for (final key in builtInEffects) _effectRow(key),
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
