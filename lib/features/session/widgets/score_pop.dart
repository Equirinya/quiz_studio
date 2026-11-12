import 'dart:async';

import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';

/// Points as the scoreboard shows a change: "+600", "−50", "0".
String signedPoints(int points) => points > 0
    ? "+$points"
    : points < 0
    ? "−${-points}"
    : "0";

/// "+600" popping up for a team for a few seconds whenever its score changes,
/// whatever changed it: on its own where it is placed, or, with a [child]
/// (the team's score box), just below that child on top of everything else
/// on the screen, so nothing laid out after it can cover it.
///
/// Changes already in [log] when the first pop-up of this app was built are
/// not shown again, nor are any shown before; a screen built anew (e.g. the
/// board coming back as the question closes) still shows the newest ones.
class ScorePop extends StatefulWidget {
  const ScorePop({super.key, required this.teamId, required this.log, required this.size, this.delay = Duration.zero, this.child});

  /// The score box to pop up under; without one the pop-up sits in place.
  final Widget? child;

  final String teamId;

  /// The latest score changes, oldest first; see [SessionState.scoreLog].
  final List<ScoreChange> log;

  /// The text height; everything else scales with it.
  final double size;

  /// When several teams score at once they pop up one after another.
  final Duration delay;

  @override
  State<ScorePop> createState() => _ScorePopState();
}

class _ScorePopState extends State<ScorePop> with SingleTickerProviderStateMixin {
  /// The newest change any pop-up in this app has dealt with, so a screen
  /// built anew neither misses a change nor shows an old one again.
  static int? _handledUpTo;

  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  late int _seen;
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController()..show();
  int? _delta;
  Timer? _start;

  static int _newest(List<ScoreChange> log) => log.isEmpty ? 0 : log.last.id;

  @override
  void initState() {
    super.initState();
    final newest = _newest(widget.log);
    // A new session (ids start again) or the very first screen: nothing old pops up.
    if (_handledUpTo == null || _handledUpTo! > newest) _handledUpTo = newest;
    _seen = _handledUpTo!;
    _check();
  }

  @override
  void didUpdateWidget(ScorePop old) {
    super.didUpdateWidget(old);
    if (_newest(widget.log) < _seen) _seen = _newest(widget.log);
    _check();
  }

  void _check() {
    final fresh = [
      for (final change in widget.log)
        if (change.id > _seen && change.teamId == widget.teamId) change,
    ];
    final newest = _newest(widget.log);
    if (newest > _seen) _seen = newest;
    if (newest > (_handledUpTo ?? 0)) _handledUpTo = newest;
    if (fresh.isEmpty) return;
    final delta = fresh.fold(0, (sum, change) => sum + change.delta);
    if (delta == 0) return;
    _start?.cancel();
    _start = Timer(widget.delay, () {
      if (!mounted) return;
      setState(() => _delta = delta);
      _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (child == null) return _pill(context);
    if (Overlay.maybeOf(context) == null) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          child,
          Positioned(bottom: -widget.size, child: _pill(context)),
        ],
      );
    }
    return OverlayPortal(
      controller: _portal,
      // The overlay hands its child the whole screen; the pill takes only its own size.
      overlayChildBuilder: (context) => Align(
        alignment: Alignment.topLeft,
        child: CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomCenter,
          followerAnchor: Alignment.topCenter,
          offset: Offset(0, -widget.size * 0.5),
          child: _pill(context),
        ),
      ),
      child: CompositedTransformTarget(link: _link, child: child),
    );
  }

  Widget _pill(BuildContext context) {
    final delta = _delta;
    if (delta == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final good = delta > 0;
    final background = good ? Colors.green.shade600 : scheme.error;
    final foreground = good ? Colors.white : scheme.onError;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          if (_controller.isCompleted || t == 0 && !_controller.isAnimating) return const SizedBox.shrink();
          // Pops in with a little overshoot, stays, then drifts down and fades.
          final grow = Curves.easeOutBack.transform((t / 0.18).clamp(0.0, 1.0));
          final fade = t < 0.8 ? 1.0 : 1 - Curves.easeIn.transform((t - 0.8) / 0.2);
          final drift = t < 0.8 ? 0.0 : (t - 0.8) / 0.2;
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, drift * widget.size * 0.6),
              child: Transform.scale(scale: 0.5 + 0.5 * grow, child: child),
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: widget.size * 0.45, vertical: widget.size * 0.12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(widget.size),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: widget.size * 0.4, offset: Offset(0, widget.size * 0.1)),
            ],
          ),
          child: Text(
            signedPoints(delta),
            style: TextStyle(fontSize: widget.size, fontWeight: FontWeight.w800, color: foreground, height: 1.1),
          ),
        ),
      ),
    );
  }
}
