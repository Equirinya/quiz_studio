import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';

/// An information screen on the big screen: its picture, its text and the
/// time left, whichever it has. A break, the rules, the next round.
class InfoBoard extends StatelessWidget {
  const InfoBoard({super.key, required this.group, required this.state, required this.unit, required this.imageFile});

  final CategoryGroup group;
  final SessionState state;
  final double unit;
  final File? Function(String name) imageFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = (group.text ?? '').trim();
    final picture = group.imagePath == null ? null : imageFile(group.imagePath!);
    final timer = state.timer;
    final clock = timer == null ? null : _Clock(timer: timer, unit: unit);
    final words = text.isEmpty
        ? null
        : Text(
            text,
            textAlign: picture == null ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              // Shorter texts larger.
              fontSize: unit * (text.length <= 40 ? 7 : (text.length <= 160 ? 4.6 : 3.4)),
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: scheme.onSurface,
            ),
          );
    final image = picture == null
        ? null
        : ClipRRect(
            borderRadius: BorderRadius.circular(unit * 2),
            child: Image.file(picture, fit: BoxFit.contain, gaplessPlayback: true),
          );
    // The text and the clock together; beside the picture when there is one.
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: picture == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (words != null) Flexible(child: words),
        if (words != null && clock != null) SizedBox(height: unit * 4),
        ?clock,
      ],
    );
    if (image == null) return Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: unit * 6), child: column));
    if (words == null && clock == null) return Center(child: image);
    return Row(
      children: [
        Expanded(flex: 3, child: Center(child: image)),
        SizedBox(width: unit * 4),
        Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: column)),
      ],
    );
  }
}

/// The time left in large digits, "4:59"; red for the last ten seconds.
class _Clock extends StatefulWidget {
  const _Clock({required this.timer, required this.unit});

  final QuestionTimer timer;
  final double unit;

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timer = widget.timer;
    // This is the host's screen: its own clock is the one the timer uses.
    final left = timer.running ? ((timer.endsAtMillis - DateTime.now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, 1 << 30) : 0;
    final text = left >= 3600
        ? '${left ~/ 3600}:${(left % 3600 ~/ 60).toString().padLeft(2, '0')}:${(left % 60).toString().padLeft(2, '0')}'
        : '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
    return Text(
      text,
      style: TextStyle(
        fontSize: widget.unit * 14,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: left <= 10 ? scheme.error : scheme.primary,
        height: 1,
      ),
    );
  }
}
