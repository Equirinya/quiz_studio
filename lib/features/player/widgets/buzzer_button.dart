import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A large, round buzzer-style button with a radial gradient and haptic feedback.
///
/// Fires [onPressed] immediately on touch (pointer-down).
/// While held down, it produces a series of vibrations that simulate
/// the feel of pressing a heavy mechanical buzzer.

class BuzzerButton extends StatefulWidget {
  const BuzzerButton({
    super.key,
    required this.onPressed,
    this.size = 200.0,
    this.label,
    this.color,
  });

  /// The cap's colour, the team's own when it has one; red otherwise.
  final Color? color;

  /// Called as soon as the user touches the button.
  /// Set to [null] to disable the button.
  final VoidCallback? onPressed;

  /// Diameter of the button in logical pixels. Defaults to 200.
  final double size;

  /// Optional label shown inside the button.
  final String? label;

  bool get _isEnabled => onPressed != null;

  @override
  State<BuzzerButton> createState() => _BuzzerButtonState();
}

class _BuzzerButtonState extends State<BuzzerButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  Timer? _vibrationTimer;
  int _vibrationCount = 0;

  // ---------- press depth animation ----------
  late final AnimationController _pressController;
  late final Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _stopVibration();
    _pressController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Haptics: initial strong impact, then fading buzzing while held
  // ------------------------------------------------------------------

  Future<void> _startVibration() async {
    _vibrationCount = 0;

    // Immediate heavy impact on touch-down
    await HapticFeedback.heavyImpact();

    // Buzz pattern: fast at first, then slows and fades
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      if (!_isPressed) {
        _stopVibration();
        return;
      }
      _vibrationCount++;

      // First 3 pulses: medium impact (mechanical "thud")
      // Next 3: light (dying resonance)
      // After that: stop automatically
      if (_vibrationCount <= 3) {
        await HapticFeedback.mediumImpact();
      } else if (_vibrationCount <= 6) {
        await HapticFeedback.lightImpact();
      } else {
        _stopVibration();
      }
    });
  }

  void _stopVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  // ------------------------------------------------------------------
  // Pointer handlers — fire onPressed instantly at pointer-down
  // ------------------------------------------------------------------

  void _handlePointerDown(PointerDownEvent _) {
    if (!widget._isEnabled) return;
    setState(() => _isPressed = true);
    _pressController.forward();
    widget.onPressed?.call();
    _startVibration();
  }

  void _handlePointerUp(PointerUpEvent _) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _pressController.reverse();
    _stopVibration();
  }

  void _handlePointerCancel(PointerCancelEvent _) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _pressController.reverse();
    _stopVibration();
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget._isEnabled;
    final double size = widget.size;

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: ScaleTransition(
        scale: _pressAnimation,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _BuzzerPainter(
              isEnabled: enabled,
              isPressed: _isPressed,
              color: widget.color ?? _BuzzerPainter._defaultCap,
            )
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom painter — a game-show buzzer: a dark base with a lit cap on top
// ---------------------------------------------------------------------------

class _BuzzerPainter extends CustomPainter {
  _BuzzerPainter({required this.isEnabled, required this.isPressed, required this.color});

  final bool isEnabled;
  final bool isPressed;

  /// The cap's colour; red unless the team has its own.
  final Color color;

  static const Color _defaultCap = Color(0xFFCC1010);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final hsl = HSLColor.fromColor(isEnabled ? color : const Color(0xFF6A6A6A));
    final mid = hsl.toColor();
    final dark = hsl.withLightness((hsl.lightness * 0.55).clamp(0.0, 1.0)).toColor();
    final rim = hsl.withLightness((hsl.lightness * 0.35).clamp(0.0, 1.0)).toColor();
    final highlight = hsl.withLightness((hsl.lightness + 0.25).clamp(0.0, 0.92)).toColor();

    // The base: a dark housing with a lighter top ring the cap sits in.
    final bezelY = h * 0.60;
    final base = RRect.fromLTRBR(w * 0.06, bezelY, w * 0.94, h * 0.94, Radius.circular(w * 0.10));
    canvas.drawRRect(
      base.shift(Offset(0, h * 0.03)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.04),
    );
    canvas.drawRRect(
      base,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A3A3A), Color(0xFF151515)],
        ).createShader(base.outerRect),
    );
    final ring = Rect.fromCenter(center: Offset(w / 2, bezelY), width: w * 0.88, height: h * 0.20);
    canvas.drawOval(
      ring,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8A8A8A), Color(0xFF2A2A2A)],
        ).createShader(ring),
    );
    canvas.drawOval(ring.deflate(w * 0.03), Paint()..color = const Color(0xFF101010));

    // The cap: a dome that sinks into the ring while pressed.
    final sink = isPressed ? h * 0.06 : 0.0;
    final capWidth = w * 0.72;
    final capBottom = bezelY + sink * 0.4;
    final capTop = h * 0.10 + sink;
    final capRect = Rect.fromLTRB((w - capWidth) / 2, capTop, (w + capWidth) / 2, capBottom + (capBottom - capTop) * 0.25);
    final cap = Path()
      ..moveTo(capRect.left, capBottom)
      ..cubicTo(capRect.left, capTop - h * 0.02, capRect.right, capTop - h * 0.02, capRect.right, capBottom)
      ..arcToPoint(Offset(capRect.left, capBottom), radius: Radius.elliptical(capWidth / 2, h * 0.07), clockwise: true)
      ..close();
    if (isEnabled && !isPressed) {
      canvas.drawPath(
        cap,
        Paint()
          ..color = mid.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06),
      );
    }
    canvas.drawPath(
      cap,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.55),
          radius: 1.0,
          colors: [highlight, mid, dark, rim],
          stops: const [0.0, 0.35, 0.75, 1.0],
        ).createShader(capRect),
    );
    // A soft shine across the top of the cap.
    final peak = capBottom - 0.75 * (capBottom - (capTop - h * 0.02));
    final shine = Rect.fromLTWH(capRect.left + capWidth * 0.18, peak + h * 0.035, capWidth * 0.34, h * 0.08);
    canvas.drawOval(shine, Paint()..color = Colors.white.withValues(alpha: isEnabled ? 0.28 : 0.12));
  }

  @override
  bool shouldRepaint(_BuzzerPainter old) => old.isEnabled != isEnabled || old.isPressed != isPressed || old.color != color;
}
