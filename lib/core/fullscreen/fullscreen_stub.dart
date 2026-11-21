/// Outside a browser: the app has the whole screen already.
bool get fullscreenSupported => false;

bool get isFullscreen => false;

Future<void> setFullscreen(bool on) async {}

/// Calls [onChange] when the page enters or leaves full screen; returns
/// what stops listening.
void Function() onFullscreenChange(void Function() onChange) => () {};

/// Only a browser has a page behind the app.
void setPageBackground(int argb) {}
