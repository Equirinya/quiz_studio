import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'companion_pages/buzzer_page.dart';

enum QRFunction {
  buzzer (true),
  unknown (false);

  final bool teamRequired;

  const QRFunction(this.teamRequired);

  static QRFunction fromString(String value) {
    return QRFunction.values.where((e) => e.name.toLowerCase() == value.toLowerCase()).firstOrNull ?? QRFunction.unknown;
  }
}

class QRPayload {
  final String sessionId;
  final QRFunction function;
  final String? teamIndex;

  const QRPayload({
    required this.sessionId,
    required this.function,
    this.teamIndex,
  });

  /// Parses `quiz-studio://{sessionId}/{function}/{teamIndex?}`
  static QRPayload? tryParse(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme != 'quiz-studio') return null;

      final segments = uri.pathSegments;

      // Expected: ["session", sessionId, function, teamIndex?]
      if (segments.length < 3) return null;
      if (segments[0] != "session") return null;

      final encodedSessionId = segments[1];

      // restore padding for base64 if removed
      final normalized = encodedSessionId.padRight(
        encodedSessionId.length + (4 - encodedSessionId.length % 4) % 4,
        '=',
      );

      final sessionId = utf8.decode(base64Url.decode(normalized));

      final function = QRFunction.fromString(segments[2]);

      final teamIndex = segments.length >= 4 ? segments[3] : null;

      return QRPayload(
        sessionId: sessionId,
        function: function,
        teamIndex: teamIndex,
      );
    } catch (e) {
      print("Error parsing QR code: $e");
      return null;
    }
  }
}

class CompanionPage extends StatefulWidget {
  const CompanionPage({super.key, required this.controller});
  final MobileScannerController controller;

  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage> {

  bool _processing = false;


  @override
  void initState() {
    super.initState();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() => _processing = true);
    widget.controller.stop();

    final payload = QRPayload.tryParse(raw);

    if (!mounted) return;

    if (payload == null) {
      _showError('Invalid QR code.\nExpected format:\nquiz-studio:/session/{sessionId}/{function}');
      return;
    }

    await _navigate(payload);

    // Resume scanner when returning
    if (mounted) {
      setState(() => _processing = false);
      widget.controller.start();
    }
  }

  Future<void> _navigate(QRPayload payload) async {
    Widget destination;

    switch (payload.function) {
      case QRFunction.buzzer:
        destination = BuzzerPage(sessionId: payload.sessionId, teamIndex: int.tryParse(payload.teamIndex??"0")??0);
        break;
      case QRFunction.unknown:
        _showError('Unknown function in QR code.');
        return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
    setState(() => _processing = false);
    widget.controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: widget.controller,
            onDetect: _onDetect,
          ),

          _ScannerOverlay(),

          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.flash_on_rounded),
                      onPressed: widget.controller.toggleTorch,
                      tooltip: 'Toggle torch',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.flip_camera_ios_rounded),
                      onPressed: widget.controller.switchCamera,
                      tooltip: 'Flip camera',
                    ),
                  ],
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: AnimatedOpacity(
                opacity: _processing ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded),
                    const SizedBox(height: 10),
                    Text(
                      'Point at a Quiz Studio QR code',
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_processing) CircularProgressIndicator(),
        ],
      ),
    );
  }
}

// ─── Scanner Overlay (cutout + corners) ──────────────────────────────────────

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    const cutoutSize = 260.0;

    return CustomPaint(
      painter: _OverlayPainter(
        cutoutSize: cutoutSize,
      ),
      child: SizedBox.expand(
        child: Center(
          child: SizedBox(
            width: cutoutSize,
            height: cutoutSize,
            child: _ScanCorners(),
          ),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final double cutoutSize;

  _OverlayPainter({required this.cutoutSize});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final half = cutoutSize / 2;

    final outer = Rect.fromLTWH(0, 0, size.width, size.height);
    final inner = Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half);

    final path = Path()
      ..addRect(outer)
      ..addRRect(RRect.fromRectAndRadius(inner, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withOpacity(0.62),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _ScanCorners extends StatelessWidget {
  const _ScanCorners();

  @override
  Widget build(BuildContext context) {
    var accent = Theme.of(context).colorScheme.primary;
    const len = 28.0;
    const thick = 3.5;
    const r = 16.0;

    Widget corner({required Alignment align}) {
      return Align(
        alignment: align,
        child: CustomPaint(
          size: const Size(len, len),
          painter: _CornerPainter(
            alignment: align,
            color: accent,
            length: len,
            thickness: thick,
            radius: r,
          ),
        ),
      );
    }

    return Stack(
      children: [
        corner(align: Alignment.topLeft),
        corner(align: Alignment.topRight),
        corner(align: Alignment.bottomLeft),
        corner(align: Alignment.bottomRight),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Alignment alignment;
  final Color color;
  final double length;
  final double thickness;
  final double radius;

  const _CornerPainter({
    required this.alignment,
    required this.color,
    required this.length,
    required this.thickness,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final isLeft = alignment.x < 0;
    final isTop = alignment.y < 0;

    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;
    final dx = isLeft ? length : -length;
    final dy = isTop ? length : -length;
    final cx = isLeft ? radius : size.width - radius;
    final cy = isTop ? radius : size.height - radius;

    final path = Path()
      ..moveTo(x + dx, y)
      ..lineTo(cx, y)
      ..arcToPoint(
        Offset(x, cy),
        radius: Radius.circular(radius),
        clockwise: !((isLeft && isTop) || (!isLeft && !isTop)),
      )
      ..lineTo(x, y + dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
