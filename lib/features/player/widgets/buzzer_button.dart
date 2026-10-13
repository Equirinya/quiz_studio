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
  });

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
            )
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom painter — draws the layered 3-D buzzer look
// ---------------------------------------------------------------------------

class _BuzzerPainter extends CustomPainter {
  _BuzzerPainter({required this.isEnabled, required this.isPressed});

  final bool isEnabled;
  final bool isPressed;

  // Active red palette
  static const Color _outerRim = Color(0xFF5A0000);   // very dark rim
  static const Color _darkRed = Color(0xFF7A0000);
  static const Color _midRed = Color(0xFFCC1010);
  static const Color _brightHighlight = Color(0xFFFF5555);

  // Disabled gray palette
  static const Color _outerRimGray = Color(0xFF1A1A1A);
  static const Color _darkGray = Color(0xFF2E2E2E);
  static const Color _midGray = Color(0xFF5A5A5A);
  static const Color _brightGray = Color(0xFF9A9A9A);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // -- Palette selection --
    final Color outerRim = isEnabled ? _outerRim : _outerRimGray;
    final Color darkC = isEnabled ? _darkRed : _darkGray;
    final Color midC = isEnabled ? _midRed : _midGray;
    final Color highlightC = isEnabled ? _brightHighlight : _brightGray;

    // 1. Drop shadow beneath the whole button
    final shadowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..color = Colors.black.withValues(alpha: isPressed ? 0.9 : 0.1);
    canvas.drawCircle(
      center + Offset(0, isPressed ? 4 : 10),
      radius * 0.95,
      shadowPaint,
    );

    // 3. Main button face — slightly smaller
    final faceRadius = radius * 0.90;
    final facePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        radius: 1.1,
        colors: [highlightC, midC, darkC, outerRim],
        stops: const [0.0, 0.25, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: faceRadius));
    canvas.drawCircle(center, faceRadius, facePaint);

    // 5. Inner subtle rim highlight (bottom-right subtle bounce)
    final innerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..shader = RadialGradient(
        center: const Alignment(0.5, 0.5),
        radius: 1.0,
        colors: [
          highlightC.withValues(alpha: 0.25),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: faceRadius));
    canvas.drawCircle(center, faceRadius - 1, innerRimPaint);
  }

  @override
  bool shouldRepaint(_BuzzerPainter old) =>
      old.isEnabled != isEnabled || old.isPressed != isPressed;
}