import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// `quiz-studio://` links the system hands to the app: a session code scanned
/// with the phone's own camera app, or an invite link tapped in a message.
///
/// Started as early as possible so the link that launched the app is not
/// missed; it waits in [pending] until the home page, which comes after
/// onboarding, takes it.
class IncomingLinks {
  IncomingLinks._();

  static final IncomingLinks instance = IncomingLinks._();

  /// The newest link nobody has handled yet.
  final ValueNotifier<String?> pending = ValueNotifier(null);

  /// Phones and tablets only: the desktop app is the presenter, it shows codes
  /// rather than scanning them.
  void start() {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    AppLinks().stringLinkStream.listen((link) => pending.value = link, onError: (Object _) {});
  }

  /// Takes the pending link, so it is handled once.
  String? take() {
    final link = pending.value;
    pending.value = null;
    return link;
  }
}
