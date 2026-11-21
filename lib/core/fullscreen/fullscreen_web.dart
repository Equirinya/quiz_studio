import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Whether the browser lets a page take the whole screen: desktop browsers
/// and Safari on the iPad do, Safari on the iPhone does not.
bool get fullscreenSupported => web.document.fullscreenEnabled;

bool get isFullscreen => web.document.fullscreenElement != null;

Future<void> setFullscreen(bool on) async {
  try {
    if (on && !isFullscreen) {
      await web.document.documentElement?.requestFullscreen().toDart;
    } else if (!on && isFullscreen) {
      await web.document.exitFullscreen().toDart;
    }
  } catch (_) {
    // Refused, e.g. not from a tap: the page stays as it is.
  }
}

void Function() onFullscreenChange(void Function() onChange) {
  final listener = ((web.Event _) => onChange()).toJS;
  web.document.addEventListener('fullscreenchange', listener);
  return () => web.document.removeEventListener('fullscreenchange', listener);
}
