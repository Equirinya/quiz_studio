import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:quiz_show/features/player/pages/player_page.dart';
import 'package:quiz_show/features/player/widgets/scanner_overlay.dart';
import 'package:quiz_show/features/session/pages/sessions_page.dart';
import 'package:quiz_show/features/session/session_links.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/game/game.dart';

/// Joins a session from the code on the presenter's screen: scanned with the
/// camera where there is one, pasted as a link everywhere.
class JoinSessionPage extends StatefulWidget {
  const JoinSessionPage({super.key});

  @override
  State<JoinSessionPage> createState() => _JoinSessionPageState();
}

class _JoinSessionPageState extends State<JoinSessionPage> {
  static final bool _hasScanner = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  final MobileScannerController? _scanner =
      _hasScanner ? MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates) : null;
  final TextEditingController _link = TextEditingController();
  bool _busy = false;
  String? _error;

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
      await SessionRepository.instance.join(link);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "Could not join. The code may no longer be valid.";
        });
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => link.role == Role.player
          ? PlayerPage(sessionId: link.sessionId, teamId: link.teamId!)
          : ControlPage(sessionId: link.sessionId, title: "Session", asMember: true),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final paste = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _link,
            enabled: !_busy,
            decoration: InputDecoration(labelText: "Or paste the link", errorText: _error),
            onSubmitted: _join,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _busy ? null : () => _join(_link.text), child: const Text("Join")),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text("Join a session")),
      body: Column(
        children: [
          Expanded(
            child: _scanner == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        "Open \"Connect devices\" on the presenting device, copy the link there and paste it below.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Stack(
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
