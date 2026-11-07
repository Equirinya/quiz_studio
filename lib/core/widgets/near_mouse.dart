import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Tells [builder] whether the mouse is over the area it builds, padding
/// included. Without a mouse (a tablet) it always says yes, so nothing is out
/// of reach. Clicks pass through to whatever lies below.
class NearMouse extends StatefulWidget {
  const NearMouse({super.key, required this.builder});

  final Widget Function(bool near) builder;

  @override
  State<NearMouse> createState() => _NearMouseState();
}

class _NearMouseState extends State<NearMouse> {
  bool _over = false;
  final MouseTracker _tracker = RendererBinding.instance.mouseTracker;

  @override
  void initState() {
    super.initState();
    _tracker.addListener(_changed);
  }

  @override
  void dispose() {
    _tracker.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    hitTestBehavior: HitTestBehavior.translucent,
    onEnter: (_) => setState(() => _over = true),
    onExit: (_) => setState(() => _over = false),
    child: widget.builder(_over || !_tracker.mouseIsConnected),
  );
}

/// Fades [child] in when [shown], and out (and out of reach) otherwise.
class RevealedWhen extends StatelessWidget {
  const RevealedWhen(this.shown, {super.key, required this.child});

  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !shown,
    child: AnimatedOpacity(opacity: shown ? 1 : 0, duration: const Duration(milliseconds: 200), child: child),
  );
}
