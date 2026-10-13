import 'package:flutter/material.dart';

import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/game/game.dart';

/// One team's answer, drawn for whoever may see it: the gamemaster all
/// along, the audience once it is revealed. [fontSize] scales it from a
/// phone card to a projector tile.
class AnswerView extends StatelessWidget {
  const AnswerView({super.key, required this.spec, required this.answer, this.fontSize = 16});

  final CompanionSpec spec;
  final PlayerAnswer? answer;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: fontSize, color: scheme.onSurface);
    final answer = this.answer;
    if (answer == null || answer.isEmpty) return Text("–", style: style.copyWith(color: scheme.outline));
    String option(List<String> list, int index) => index >= 0 && index < list.length ? list[index] : "?";

    switch (spec.kind) {
      case CompanionKind.whiteboard:
        return DrawingView(drawing: answer.drawing, background: spec.background, listRows: spec.listRows);
      case CompanionKind.text:
        return Text(answer.text ?? "", style: style);
      case CompanionKind.number:
      case CompanionKind.slider:
        return Text(
          formatNumber(answer.number ?? 0, unit: spec.unit),
          style: style.copyWith(fontSize: fontSize * 1.5, fontWeight: FontWeight.w700),
        );
      case CompanionKind.choice:
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
/// with its own time ([hostClock] true); any other device counts from the
/// moment it first saw the round, which is right to within the network delay.
class RoundCountdown extends StatefulWidget {
  const RoundCountdown({super.key, required this.openedAt, required this.endsAt, this.hostClock = false, this.height = 8});

  final int? openedAt;
  final int endsAt;
  final bool hostClock;
  final double height;

  @override
  State<RoundCountdown> createState() => _RoundCountdownState();
}

class _RoundCountdownState extends State<RoundCountdown> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  late int _offset = _measureOffset();

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  /// How far this device's clock is ahead of the host's, as far as it can tell.
  int _measureOffset() => widget.hostClock || widget.openedAt == null ? 0 : _now() - widget.openedAt!;

  @override
  void didUpdateWidget(RoundCountdown old) {
    super.didUpdateWidget(old);
    if (old.openedAt != widget.openedAt) _offset = _measureOffset();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _ticker,
      builder: (context, _) {
        final total = widget.openedAt == null ? null : widget.endsAt - widget.openedAt!;
        final left = (widget.endsAt - (_now() - _offset)).clamp(0, total ?? 1 << 31);
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
    );
  }
}
