import 'package:flutter/material.dart';

import 'package:quiz_show/l10n/l10n.dart';

import 'fullscreen_stub.dart' if (dart.library.js_interop) 'fullscreen_web.dart' as fullscreen;

/// In the web app: takes the whole screen, without the browser's bars, or
/// gives it back. Shows nothing where that is not possible (in the installed
/// apps, or Safari on an iPhone).
class FullscreenButton extends StatefulWidget {
  const FullscreenButton({super.key});

  @override
  State<FullscreenButton> createState() => _FullscreenButtonState();
}

class _FullscreenButtonState extends State<FullscreenButton> {
  late final void Function() _stop;

  @override
  void initState() {
    super.initState();
    // Also when the browser leaves full screen itself, e.g. with Esc.
    _stop = fullscreen.onFullscreenChange(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!fullscreen.fullscreenSupported) return const SizedBox.shrink();
    final on = fullscreen.isFullscreen;
    return IconButton(
      key: const ValueKey('fullscreen'),
      tooltip: on ? context.l10n.exitFullscreen : context.l10n.fullscreen,
      icon: Icon(on ? Icons.fullscreen_exit : Icons.fullscreen),
      onPressed: () => fullscreen.setFullscreen(!on),
    );
  }
}
