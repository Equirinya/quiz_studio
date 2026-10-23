import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:quiz_show/features/player/pages/player_page.dart';
import 'package:quiz_show/features/player/recent_sessions.dart';
import 'package:quiz_show/features/player/widgets/scanner_overlay.dart';
import 'package:quiz_show/features/session/pages/sessions_page.dart';
import 'package:quiz_show/features/session/session_links.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/game/game.dart';

/// Joins a session from the code on the presenter's screen: scanned with the
/// camera where there is one, pasted as a link everywhere.
class JoinSessionPage extends StatefulWidget {
  const JoinSessionPage({super.key, this.initialLink, this.asGuest = false});

  /// Whether this device can scan a join code with its camera.
  static final bool hasScanner = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// A code the system handed over, scanned with the camera app: joined
  /// right away.
  final String? initialLink;

  /// Reached from the welcome screen, without setting up an account: says
  /// what joining agrees to.
  final bool asGuest;

  @override
  State<JoinSessionPage> createState() => _JoinSessionPageState();
}

class _JoinSessionPageState extends State<JoinSessionPage> {
  static final bool _hasScanner = JoinSessionPage.hasScanner;

  final MobileScannerController? _scanner = _hasScanner ? MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates) : null;
  final TextEditingController _link = TextEditingController();
  bool _busy = false;
  String? _error;
  List<RecentSession> _recent = const [];

  @override
  void initState() {
    super.initState();
    RecentSessions.load().then((recent) {
      if (mounted) setState(() => _recent = recent);
    });
    if (widget.initialLink != null) {
      _link.text = widget.initialLink!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _join(widget.initialLink!));
    }
  }

  @override
  void dispose() {
    _scanner?.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _join(String raw) async {
    if (_busy) return;
    final link = SessionJoinLink.tryParse(raw);
    if (link == null) {
      setState(() => _error = "That is not a Quiz Studio session code.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionRepository.instance.join(link).timeout(const Duration(seconds: 6));
    } catch (_) {
      // Without the internet the code still works on the presenter's own
      // network; only a code without a local address is a dead end.
      if (link.lan.isEmpty) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = "Could not join. The code may no longer be valid.";
          });
        }
        return;
      }
    }
    await RecentSessions.remember(link);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            link.role == Role.player ? PlayerPage(link: link) : ControlPage(sessionId: link.sessionId, title: "Session", joinLink: link),
      ),
    );
  }

  static String _ago(int millis) {
    final minutes = (DateTime.now().millisecondsSinceEpoch - millis) ~/ 60000;
    if (minutes < 2) return "just now";
    if (minutes < 60) return "$minutes minutes ago";
    if (minutes < 60 * 24) return "${minutes ~/ 60} hours ago";
    return "${minutes ~/ (60 * 24)} days ago";
  }

  @override
  Widget build(BuildContext context) {
    final paste = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Getting back in after closing the app, without the code.
          for (final recent in _recent.take(3))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(recent.link.role == Role.player ? Icons.touch_app_outlined : Icons.tune),
              title: Text(recent.link.role == Role.player ? "Rejoin as a team's device" : "Rejoin as controller"),
              subtitle: Text("Joined ${_ago(recent.joinedAtMillis)}"),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _join(recent.link.link),
            ),
          TextField(
            controller: _link,
            enabled: !_busy,
            // Next to the camera it is the other way in; on its own, the only one.
            decoration: InputDecoration(labelText: _scanner == null ? "Join link" : "Or paste the link", errorText: _error),
            onSubmitted: _join,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _busy ? null : () => _join(_link.text), child: const Text("Join")),
          ),
          if (widget.asGuest)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () =>
                    launchUrl(Uri.parse('https://equirinya.github.io/quiz_studio/privacy.html'), mode: LaunchMode.externalApplication),
                child: const Text(
                  "By joining you agree to the terms and privacy policy. No account or name needed.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text("Join a session")),
      // Without a camera there is nothing to scan: the link is the way in.
      body: _scanner == null
          ? Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link, size: 48, color: Theme.of(context).colorScheme.primary),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(32, 16, 32, 0),
                        child: Text(
                          "Open \"Connect devices\" on the presenting device, copy the join link there and paste it here.",
                          textAlign: TextAlign.center,
                        ),
                      ),
                      paste,
                    ],
                  ),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _scanner,
                        onDetect: (capture) {
                          final raw = capture.barcodes.firstOrNull?.rawValue;
                          if (raw != null) _join(raw);
                        },
                      ),
                      const ScannerOverlay(),
                    ],
                  ),
                ),
                paste,
              ],
            ),
    );
  }
}
