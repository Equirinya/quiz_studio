import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

// Safari on the iPad has the standard Fullscreen API; other browsers there
// (and older Safari) only the webkit-prefixed one, so both are tried.

bool _flag(String name) => web.document.getProperty<JSAny?>(name.toJS).dartify() == true;

/// Whether the browser lets a page take the whole screen: desktop browsers
/// and Safari on the iPad do, Safari on the iPhone does not.
bool get fullscreenSupported => web.document.fullscreenEnabled || _flag('webkitFullscreenEnabled');

bool get isFullscreen =>
    web.document.fullscreenElement != null || web.document.getProperty<JSAny?>('webkitFullscreenElement'.toJS) != null;

Future<void> setFullscreen(bool on) async {
  try {
    final root = web.document.documentElement;
    if (root == null) return;
    if (on && !isFullscreen) {
      if (web.document.fullscreenEnabled) {
        await root.requestFullscreen().toDart;
      } else {
        root.callMethod<JSAny?>('webkitRequestFullscreen'.toJS);
      }
    } else if (!on && isFullscreen) {
      if (web.document.fullscreenElement != null) {
        await web.document.exitFullscreen().toDart;
      } else {
        web.document.callMethod<JSAny?>('webkitExitFullscreen'.toJS);
      }
    }
  } catch (_) {
    // Refused, e.g. not from a tap: the page stays as it is.
  }
}

void Function() onFullscreenChange(void Function() onChange) {
  final listener = ((web.Event _) {
    onChange();
    // Safari on the iPad does not always tell the page its new size when it
    // enters or leaves full screen, which left the app at its old size with
    // empty bands above and below. Telling it again, now and once the
    // animation is done, makes it fill the screen.
    web.window.dispatchEvent(web.Event('resize'));
    web.window.setTimeout((() => web.window.dispatchEvent(web.Event('resize'))).toJS, 400.toJS);
  }).toJS;
  web.document.addEventListener('fullscreenchange', listener);
  web.document.addEventListener('webkitfullscreenchange', listener);
  return () {
    web.document.removeEventListener('fullscreenchange', listener);
    web.document.removeEventListener('webkitfullscreenchange', listener);
  };
}

/// The page behind the app takes the app's background, so whatever the app
/// does not cover (the edges in full screen, a bounce) is not white.
void setPageBackground(int argb) {
  final hex = '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  web.document.documentElement?.setAttribute('style', 'background-color: $hex');
  web.document.body?.style.backgroundColor = hex;
}
