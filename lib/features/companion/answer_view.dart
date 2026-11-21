import 'dart:async';

import 'package:flutter/material.dart';

import 'package:quiz_show/core/host_clock.dart';

import 'package:quiz_show/features/companion/connections.dart';
import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// One team's answer, drawn for whoever may see it: the gamemaster all
/// along, the audience once it is revealed. [fontSize] scales it from a
/// phone card to a projector tile.
class AnswerView extends StatelessWidget {
  const AnswerView({
    super.key,
    required this.spec,
    required this.answer,
    this.fontSize = 16,
    this.backgroundImage,
    this.matches = const [],
  });

  /// Whiteboards drawn on a picture: that picture, where this device has it.
  final ImageProvider? backgroundImage;

  /// An answer list, for the gamemaster: per line, the right answer it
  /// matches, shown beside it; null where it matches none.
  final List<String?> matches;

  final CompanionSpec spec;
  final PlayerAnswer? answer;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: fontSize, color: scheme.onSurface);
    final answer = this.answer;
    if (answer == null || answer.isEmpty) return Text("–", style: style.copyWith(color: scheme.outline));
    String option(List<String> list, int index) => index >= 0 && index < list.length ? context.l10n.deviceLabel(list[index]) : "?";

    switch (spec.kind) {
      case CompanionKind.connections:
        final progress = answer.connections!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConnectionsProgressRow(solved: progress.solved, mistakes: progress.mistakes, allowed: spec.mistakes, size: fontSize * 1.2),
            SizedBox(height: fontSize * 0.3),
            Text(
              "${context.l10n.foundOfFour(progress.solved.length)} · ${context.l10n.mistakeCount(progress.mistakes)}",
              style: style.copyWith(fontSize: fontSize * 0.85),
            ),
          ],
        );
      case CompanionKind.whiteboard:
        return DrawingView(
          drawing: answer.drawing,
          background: spec.background,
          listRows: spec.listRows,
          backgroundImage: backgroundImage,
        );
      case CompanionKind.text:
        return Text(answer.text ?? "", style: style);
      case CompanionKind.list:
        // Up to the last line the team filled in: of 20 lines with the 15th
        // the last written, 1 to 15. Empty lines before it stay, as "–".
        final items = answer.items ?? const <String>[];
        final used = items.take(items.lastIndexWhere((item) => item.trim().isNotEmpty) + 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, item) in used.indexed)
              if (matches.elementAtOrNull(i) case final match?)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text("${i + 1}. $item", style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    SizedBox(width: fontSize * 0.4),
                    Icon(Icons.check, size: fontSize, color: scheme.primary),
                    SizedBox(width: fontSize * 0.2),
                    Flexible(
                      child: Text(
                        context.l10n.matchesAnswer(match),
                        style: style.copyWith(fontSize: fontSize * 0.8, color: scheme.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  "${i + 1}. ${item.isEmpty ? "–" : item}",
                  style: item.isEmpty ? style.copyWith(color: scheme.outline) : style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          ],
        );
      case CompanionKind.number:
      case CompanionKind.slider:
        return Text(
          formatNumber(answer.number ?? 0, unit: spec.unit),
          style: style.copyWith(fontSize: fontSize * 1.5, fontWeight: FontWeight.w700),
        );
      case CompanionKind.choice:
        if (answer.choices case final picks?) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (picks.isEmpty) Text("–", style: style),
              for (final pick in picks) Text("${String.fromCharCode(0x41 + pick)}   ${option(spec.options, pick)}", style: style),
            ],
          );
        }
        final choice = answer.choice ?? -1;
        return Text("${String.fromCharCode(0x41 + choice)}   ${option(spec.options, choice)}", style: style);
      case CompanionKind.order:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (position, index) in (answer.order ?? const <int>[]).indexed)
              Text("${position + 1}. ${option(spec.options, index)}", style: style),
          ],
        );
      case CompanionKind.match:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, target) in (answer.pairs ?? const <int>[]).indexed)
              Text("${option(spec.options, i)}  →  ${target < 0 ? "–" : option(spec.targets, target)}", style: style),
          ],
        );
    }
  }
}

/// The time left in an answer round, as a shrinking bar and seconds.
///
/// The deadline is on the host's clock. The presenting device compares it
/// with its own time ([hostClock] true); any other device corrects for how
/// far its clock is off ([HostClock]), or, before it knows that, counts from
/// the moment it first saw the round. Paused ([pausedAt]), it stands still
/// at the time left then.
class RoundCountdown extends StatefulWidget {
  const RoundCountdown({
    super.key,
    required this.openedAt,
    required this.endsAt,
    this.hostClock = false,
    this.height = 8,
    this.pausedAt,
    this.held = 0,
  });

  final int? openedAt;
  final int endsAt;
  final bool hostClock;
  final double height;

  /// Host clock: when the timer was paused; null while it runs.
  final int? pausedAt;

  /// How long it was paused before, in all: not part of the time it was
  /// set for.
  final int held;

  @override
  State<RoundCountdown> createState() => _RoundCountdownState();
}

class _RoundCountdownState extends State<RoundCountdown> {
  /// Wakes the countdown when something on it will look different: the
  /// seconds, or the bar a pixel shorter. Not every frame: on the big
  /// screen each frame is the whole window drawn again, and a clock running
  /// at the display's rate kept the GPU (and its fans) busy for nothing.
  Timer? _tick;
  late int _offset = _measureOffset();

  /// Never more often than this, however long the bar.
  static const _fastest = 40;

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  /// How far this device's clock is ahead of the host's, by round, measured
  /// when the device first saw it: a countdown shown again later, e.g. after
  /// the team sat part of a round out, goes on where it was.
  static final Map<int, int> _offsets = {};

  int _measureOffset() {
    final opened = widget.openedAt;
    if (widget.hostClock) return 0;
    if (HostClock.offset case final offset?) return offset;
    if (opened == null) return 0;
    return _offsets.putIfAbsent(opened, () {
      if (_offsets.length > 20) _offsets.remove(_offsets.keys.first);
      return _now() - opened;
    });
  }

  @override
  void didUpdateWidget(RoundCountdown old) {
    super.didUpdateWidget(old);
    if (old.openedAt != widget.openedAt) _offset = _measureOffset();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// The next redraw: when the seconds change, or sooner when the bar of
  /// [width] pixels loses one before that.
  void _schedule(int left, int? total, double width) {
    _tick?.cancel();
    if (left <= 0) return;
    var wait = left % 1000 == 0 ? 1000 : left % 1000;
    if (total != null && total > 0 && width > 0) {
      final perPixel = (total / width).ceil();
      if (perPixel < wait) wait = perPixel;
    }
    _tick = Timer(Duration(milliseconds: wait < _fastest ? _fastest : wait), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // In a layer of its own, so nothing next to it is redrawn with it.
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, box) {
          final total = widget.openedAt == null ? null : widget.endsAt - widget.openedAt! - widget.held;
          // Read on every redraw: a closer measurement may have come in since.
          final offset = widget.hostClock ? 0 : (HostClock.offset ?? _offset);
          final paused = widget.pausedAt;
          final left = (widget.endsAt - (paused ?? (_now() - offset))).clamp(0, total == null || total < 0 ? 1 << 31 : total);
          if (paused == null) {
            _schedule(left, total, box.maxWidth.isFinite ? box.maxWidth : 1000);
          } else {
            // Nothing changes until it runs on, which brings a new widget.
            _tick?.cancel();
          }
          final seconds = (left / 1000).ceil();
          final urgent = seconds <= 5;
          return Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: total == null || total <= 0 ? null : left / total,
                  minHeight: widget.height,
                  borderRadius: BorderRadius.circular(widget.height),
                  color: urgent ? scheme.error : scheme.primary,
                ),
              ),
              SizedBox(width: widget.height * 1.5),
              if (paused != null) ...[
                Icon(Icons.pause_circle_outline, size: widget.height * 2.4, color: scheme.outline),
                SizedBox(width: widget.height * 0.5),
              ],
              Text(
                "$seconds s",
                style: TextStyle(
                  fontSize: widget.height * 2.2,
                  fontWeight: FontWeight.w700,
                  color: urgent ? scheme.error : scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
