import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

String _slotLabel(AppLocalizations l10n, String slot) => switch (slot) {
  musicBackground => l10n.boardMusic,
  musicCalm => l10n.calmMusic,
  _ => l10n.thrillingMusic,
};

String _effectLabel(AppLocalizations l10n, String key) => switch (key) {
  effectAnswerCorrect => l10n.effectRightAnswer,
  effectAnswerWrong => l10n.effectWrongAnswer,
  effectAnswerClosed => l10n.effectQuestionClosed,
  effectReveal => l10n.effectReveal,
  effectQuestionOpen => l10n.effectQuestionOpens,
  effectLockIn => l10n.effectTeamLocksIn,
  effectNextItem => l10n.effectNextItem,
  effectCountdown => l10n.effectLastTenSeconds,
  effectTimesUp => l10n.effectTimesUp,
  effectSteal => l10n.effectSteal,
  _ => l10n.effectFullySolved,
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
}) => showDialog<void>(
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

  // Made on the first listen: a player per dialog is only needed then.
  AudioPlayer? _preview;

  /// The row whose sound is playing, so its button can stop it again.
  String? _playing;

  static const String _ownFile = '\u0000own';

  Future<void> _listen(String row, String? asset, String? ownFile) async {
    final player = _preview ??= AudioPlayer();
    await player.stop();
    if (_playing == row) {
      setState(() => _playing = null);
      return;
    }
    setState(() => _playing = row);
    player.onPlayerComplete.first.then((_) {
      if (mounted && _playing == row) setState(() => _playing = null);
    });
    try {
      if (asset != null) {
        await player.play(AssetSource(asset));
      } else if (ownFile != null) {
        await MediaService.instance.ensureCached(widget.gameId, ownFile);
        await player.play(DeviceFileSource(MediaService.instance.localFile(widget.gameId, ownFile).path));
      }
    } catch (_) {
      if (mounted) setState(() => _playing = null);
    }
  }

  /// One slot or moment, the same for music and sounds: a menu of what can
  /// play (the default, the sounds that come with the app, silence, an own
  /// file), a button to listen to it, and for an own file the button to pick
  /// it.
  Widget _choice({
    required String row,
    required String label,
    required String? value,
    required List<BuiltinSound> builtins,
    required BuiltinSound? fallback,
    required ValueChanged<String?> set,
  }) {
    final isOwn = value != null && value != silentSound && !value.startsWith(builtinSoundPrefix);
    final picked = value == null ? null : builtins.where((sound) => sound.key == value).firstOrNull;
    final fallbackLabel = widget.isGame ? (fallback == null ? context.l10n.nothing : context.l10n.appDefault(fallback.label)) : context.l10n.asSetAbove;
    // What the listen button plays: the choice, or what the default is here.
    final asset = picked?.asset ?? (value == null && widget.isGame ? fallback?.asset : null);
    final canListen = asset != null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey('$row/$value'),
              initialValue: isOwn ? _ownFile : value ?? '',
              isExpanded: true,
              decoration: InputDecoration(labelText: label, isDense: true),
              items: [
                DropdownMenuItem(value: '', child: Text(fallbackLabel)),
                for (final sound in builtins) DropdownMenuItem(value: sound.key, child: Text(sound.label)),
                DropdownMenuItem(value: silentSound, child: Text(context.l10n.silent)),
                DropdownMenuItem(value: _ownFile, child: Text(isOwn ? context.l10n.ownFile : context.l10n.ownFileMenu)),
              ],
              onChanged: (next) {
                if (next == null || next == _ownFile) {
                  // Picking the file happens with the button next to it.
                  if (!isOwn) setState(() => _choosingOwn.add(row));
                  return;
                }
                _choosingOwn.remove(row);
                set(next.isEmpty ? null : next);
              },
            ),
          ),
          if (!isOwn)
            IconButton(
              icon: Icon(_playing == row ? Icons.stop : Icons.play_arrow),
              tooltip: _playing == row ? context.l10n.stop : context.l10n.listen,
              onPressed: canListen ? () => _listen(row, asset, null) : null,
            ),
          if (isOwn || _choosingOwn.contains(row))
            MediaButton(
              gameId: widget.gameId,
              kind: MediaKind.audio,
              name: isOwn ? value : null,
              onChanged: (name) {
                _choosingOwn.remove(row);
                set(name);
              },
            ),
        ],
      ),
    );
  }

  Widget _effectRow(String key) => _choice(
    row: key,
    label: _effectLabel(context.l10n, key),
    value: _builtIn[key],
    builtins: builtinSoundsFor(key),
    fallback: defaultEffectSounds[key] == null ? null : builtinSound(defaultEffectSounds[key]!),
    set: (next) {
      setState(() => next == null ? _builtIn.remove(key) : _builtIn[key] = next);
      _saveEffects();
    },
  );

  Widget _musicRow(String slot) => _choice(
    row: slot,
    label: _slotLabel(context.l10n, slot),
    value: _slots[slot],
    builtins: builtinMusicTracks,
    fallback: defaultMusicTrack(slot),
    set: (next) {
      setState(() => next == null ? _slots.remove(slot) : _slots[slot] = next);
      widget.save({slot: next});
    },
  );

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
                    ? context.l10n.soundsGameText
                    : context.l10n.soundsLevelText,
                style: theme.textTheme.bodySmall,
              ),
              header(context.l10n.music),
              for (final slot in musicSlots) _musicRow(slot),
              header(context.l10n.soundsAtMoments),
              for (final key in builtInEffects) _effectRow(key),
              header(context.l10n.ownEffects),
              for (final effect in _custom)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: effect.name,
                          decoration: InputDecoration(labelText: context.l10n.name),
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
                        tooltip: context.l10n.remove,
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
                  label: Text(context.l10n.addEffect),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.done))],
    );
  }
}
