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
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
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
// Custom painter — a game-show buzzer seen from above: a dark box with a
// metal collar, and the lit cap in it
// ---------------------------------------------------------------------------

class _BuzzerPainter extends CustomPainter {
  _BuzzerPainter({required this.isEnabled, required this.isPressed, required this.color});

  final bool isEnabled;
  final bool isPressed;

  /// The cap's colour; red unless the team has its own.
  final Color color;

  static const Color _defaultCap = Color(0xFFCC1010);

  /// Seen from a little in front: circles look slightly flattened.
  static const double _tilt = 0.9;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final hsl = HSLColor.fromColor(isEnabled ? color : const Color(0xFF6A6A6A));
    final mid = hsl.toColor();
    final dark = hsl.withLightness((hsl.lightness * 0.6).clamp(0.0, 1.0)).toColor();
    final side = hsl.withLightness((hsl.lightness * 0.4).clamp(0.0, 1.0)).toColor();
    final highlight = hsl.withLightness((hsl.lightness + 0.22).clamp(0.0, 0.9)).toColor();

    // The box: its top face, and below it the front edge that gives it depth.
    final radius = Radius.circular(w * 0.16);
    final top = RRect.fromLTRBR(w * 0.04, h * 0.05, w * 0.96, h * 0.87, radius);
    final front = RRect.fromLTRBR(w * 0.04, h * 0.13, w * 0.96, h * 0.95, radius);
    canvas.drawRRect(
      front.shift(Offset(0, h * 0.02)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.04),
    );
    canvas.drawRRect(front, Paint()..color = const Color(0xFF101010));
    canvas.drawRRect(
      top,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3C3C3C), Color(0xFF1C1C1C)],
        ).createShader(top.outerRect),
    );
    // A thin light edge along the top face.
    canvas.drawRRect(
      top.deflate(w * 0.006),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.008
        ..color = Colors.white.withValues(alpha: 0.08),
    );

    final center = Offset(w / 2, h * 0.46);
    Rect circle(double r, [double dy = 0]) => Rect.fromCenter(center: center + Offset(0, dy), width: r * 2, height: r * 2 * _tilt);

    // The collar the cap sits in: brushed metal around a dark well.
    final collar = circle(w * 0.38);
    canvas.drawOval(
      collar,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB0B0B0), Color(0xFF5A5A5A), Color(0xFF8C8C8C)],
        ).createShader(collar),
    );
    canvas.drawOval(circle(w * 0.335), Paint()..color = const Color(0xFF0C0C0C));

    // The cap: its side shows below the top while up, and disappears into
    // the collar while pressed.
    final r = w * 0.31;
    final depth = isPressed ? h * 0.012 : h * 0.05;
    final lift = isPressed ? 0.0 : -h * 0.02;
    final capSide = circle(r, lift + depth);
    final capTop = circle(r, lift);
    if (isEnabled && !isPressed) {
      canvas.drawOval(
        capTop,
        Paint()
          ..color = mid.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.07),
      );
    }
    canvas.drawOval(capSide, Paint()..color = side);
    canvas.drawRect(
      Rect.fromLTRB(capTop.left, capTop.center.dy, capTop.right, capSide.center.dy),
      Paint()..color = side,
    );
    canvas.drawOval(
      capTop,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          radius: 0.95,
          colors: [highlight, mid, dark],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(capTop),
    );
    // A glossy reflection on the upper left, and a faint rim of light.
    final shine = Rect.fromCenter(
      center: capTop.center + Offset(-r * 0.3, -r * 0.38 * _tilt),
      width: r * 0.75,
      height: r * 0.38,
    );
    canvas.drawOval(
      shine,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: isEnabled ? 0.45 : 0.15), Colors.white.withValues(alpha: 0)],
        ).createShader(shine),
    );
    canvas.drawOval(
      capTop.deflate(w * 0.004),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.006
        ..color = Colors.white.withValues(alpha: isEnabled ? 0.18 : 0.06),
    );
  }

  @override
  bool shouldRepaint(_BuzzerPainter old) => old.isEnabled != isEnabled || old.isPressed != isPressed || old.color != color;
}
