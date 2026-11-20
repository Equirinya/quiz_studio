import 'dart:async';

import 'package:flutter/material.dart';

import 'package:quiz_show/core/host_clock.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// A volume from 0 to 100 that follows the finger here and is sent when let
/// go, so the big screen is not asked twenty times on the way.
class VolumeSlider extends StatefulWidget {
  const VolumeSlider({super.key, required this.value, required this.onChanged, this.label});

  final int value;
  final ValueChanged<int> onChanged;

  /// Written above the slider.
  final String? label;

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  int? _drag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = _drag ?? widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label case final label?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        Row(
          children: [
            Icon(Icons.volume_down, color: theme.colorScheme.onSurfaceVariant),
            Expanded(
              child: Slider(
                value: value.toDouble(),
                max: 100,
                divisions: 20,
                label: "$value %",
                onChanged: (v) => setState(() => _drag = v.round()),
                onChangeEnd: (v) {
                  widget.onChanged(v.round());
                  setState(() => _drag = null);
                },
              ),
            ),
            Icon(Icons.volume_up, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ],
    );
  }
}

/// The open question's sound or clip: play and pause, stop, a bar to see
/// and move where it is, and its volume. Its place is worked out from the
/// host's clock, so it moves along without the big screen sending it.
class MediaControls extends StatefulWidget {
  const MediaControls({super.key, required this.state, required this.question, required this.send, this.presenting = false});

  final SessionState state;
  final Question? question;
  final void Function(Command) send;

  /// This device is the host: its clock is the host's.
  final bool presenting;

  @override
  State<MediaControls> createState() => _MediaControlsState();
}

class _MediaControlsState extends State<MediaControls> {
  Timer? _tick;

  /// Where the bar is while it is being dragged.
  int? _drag;

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(MediaControls old) {
    super.didUpdateWidget(old);
    _follow();
  }

  /// Moves the bar along while the sound plays.
  void _follow() {
    final running = widget.state.mediaClock?.running == true;
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _hostNow => DateTime.now().millisecondsSinceEpoch - (widget.presenting ? 0 : HostClock.offset ?? 0);

  static String _time(int ms) {
    final seconds = ms ~/ 1000;
    return "${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = widget.state;
    final question = widget.question;
    final send = widget.send;
    final hasSound = question?.hasMediaAt(state.revealed, state.standing) ?? false;
    final listening = (state.phase == Phase.question || state.phase == Phase.buzzered) && !state.waitingForBets;
    final playing = state.media == MediaPlayback.playing;
    final clock = state.mediaClock;
    final duration = clock?.durationMs;
    final canSeek = clock != null && duration != null && duration > 0;
    final position = _drag ?? clock?.positionAt(_hostNow) ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton.filled(
              key: const ValueKey('mediaPlay'),
              tooltip: playing ? l10n.pause : l10n.play,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: playing
                  ? () => send(const SetMedia(MediaPlayback.paused))
                  : hasSound && listening
                  ? () => send(const SetMedia(MediaPlayback.playing))
                  : null,
            ),
            IconButton(
              key: const ValueKey('mediaStop'),
              tooltip: l10n.stop,
              icon: const Icon(Icons.stop),
              onPressed: state.media != MediaPlayback.stopped ? () => send(const SetMedia(MediaPlayback.stopped)) : null,
            ),
            const Spacer(),
            Text(
              canSeek ? "${_time(position)} / ${_time(duration)}" : _time(position),
              style: theme.textTheme.labelLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
        Slider(
          key: const ValueKey('mediaPosition'),
          value: canSeek ? position.clamp(0, duration).toDouble() : 0,
          max: canSeek ? duration.toDouble() : 1,
          label: _time(position),
          onChanged: canSeek ? (v) => setState(() => _drag = v.round()) : null,
          onChangeEnd: canSeek
              ? (v) {
                  send(SeekMedia(v.round()));
                  setState(() => _drag = null);
                }
              : null,
        ),
        VolumeSlider(
          key: const ValueKey('mediaVolume'),
          value: state.mediaVolume,
          label: l10n.mediaVolume,
          onChanged: (volume) => send(SetMediaVolume(volume)),
        ),
      ],
    );
  }
}
