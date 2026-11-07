import 'dart:math';

import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';

/// How far a Fragenhagel has come, drawn on the big screen in one of the
/// [ProgressStyle]s. [done] items of [total] are behind; at [done] == [total]
/// the round is over and every style celebrates in its own way.
class RapidProgress extends StatelessWidget {
  const RapidProgress({super.key, required this.style, required this.done, required this.total, required this.unit});

  final ProgressStyle style;
  final int done;
  final int total;

  /// A hundredth of the screen's height.
  final double unit;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    // Glides to each new value instead of jumping.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: fraction),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) => switch (style) {
        ProgressStyle.off => const SizedBox(),
        ProgressStyle.bar => _Bar(value: value, unit: unit),
        ProgressStyle.dots => total > 24 ? _Bar(value: value, unit: unit) : _Dots(done: done, total: total, unit: unit),
        ProgressStyle.battery => _Battery(value: value, full: done >= total && total > 0, unit: unit),
        ProgressStyle.thermometer => _Thermometer(value: value, full: done >= total && total > 0, unit: unit),
        ProgressStyle.flux => FluxCapacitor(value: value, unleashed: done >= total && total > 0, size: unit * 34),
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.unit});

  final double value;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(unit * 2),
      child: SizedBox(
        height: unit * 3,
        child: LinearProgressIndicator(value: value, backgroundColor: scheme.surfaceContainerHighest, color: scheme.primary),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.done, required this.total, required this.unit});

  final int done;
  final int total;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.symmetric(horizontal: unit * 0.6),
            width: i == done ? unit * 4 : unit * 2.6,
            height: i == done ? unit * 4 : unit * 2.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done ? scheme.primary : scheme.surfaceContainerHighest,
              border: i == done ? Border.all(color: scheme.primary, width: unit * 0.5) : null,
            ),
          ),
      ],
    );
  }
}

/// A battery that charges segment by segment, from red over yellow to green.
class _Battery extends StatelessWidget {
  const _Battery({required this.value, required this.full, required this.unit});

  final double value;
  final bool full;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        width: unit * 60,
        height: unit * 12,
        child: CustomPaint(painter: _BatteryPainter(value, full, scheme.onSurface)),
      ),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  _BatteryPainter(this.value, this.full, this.frame);

  final double value;
  final bool full;
  final Color frame;

  static const segments = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * 0.08;
    final tip = size.width * 0.04;
    final body = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - tip - stroke, size.height - stroke);
    final color = Color.lerp(
      Color.lerp(Colors.red, Colors.amber, (value * 2).clamp(0, 1)),
      Colors.greenAccent.shade700,
      ((value - 0.5) * 2).clamp(0, 1),
    )!;
    if (full) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(body.inflate(stroke), Radius.circular(size.height * 0.25)),
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.2),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(size.height * 0.18)),
      Paint()
        ..color = frame
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(body.right + stroke / 2, size.height * 0.3, tip, size.height * 0.4),
        Radius.circular(tip * 0.4),
      ),
      Paint()..color = frame,
    );
    final inner = body.deflate(stroke * 1.4);
    final gap = inner.width * 0.012;
    final width = (inner.width - gap * (segments - 1)) / segments;
    final filled = value * segments;
    for (var i = 0; i < segments; i++) {
      final share = (filled - i).clamp(0.0, 1.0);
      if (share <= 0) break;
      final left = inner.left + i * (width + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, inner.top, width * share, inner.height), Radius.circular(width * 0.15)),
        Paint()..color = color,
      );
    }
    if (full) {
      // A lightning bolt across the full battery.
      final c = body.center;
      final h = body.height * 0.7;
      final bolt = Path()
        ..moveTo(c.dx + h * 0.08, c.dy - h / 2)
        ..lineTo(c.dx - h * 0.22, c.dy + h * 0.06)
        ..lineTo(c.dx - h * 0.02, c.dy + h * 0.06)
        ..lineTo(c.dx - h * 0.1, c.dy + h / 2)
        ..lineTo(c.dx + h * 0.22, c.dy - h * 0.08)
        ..lineTo(c.dx + h * 0.02, c.dy - h * 0.08)
        ..close();
      canvas.drawPath(bolt, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_BatteryPainter old) => old.value != value || old.full != full || old.frame != frame;
}

/// A thermometer lying on its side whose red rises with every item.
class _Thermometer extends StatelessWidget {
  const _Thermometer({required this.value, required this.full, required this.unit});

  final double value;
  final bool full;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        width: unit * 70,
        height: unit * 10,
        child: CustomPaint(painter: _ThermometerPainter(value, full, scheme.onSurface, scheme.surfaceContainerHighest)),
      ),
    );
  }
}

class _ThermometerPainter extends CustomPainter {
  _ThermometerPainter(this.value, this.full, this.frame, this.glass);

  final double value;
  final bool full;
  final Color frame;
  final Color glass;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final tube = size.height * 0.36;
    final bulb = Offset(r, r);
    final tubeRect = Rect.fromLTWH(r, r - tube / 2, size.width - r - tube / 2, tube);
    // Cold blue at the start, through yellow and orange, to hot red at the end.
    final red = value < 0.5
        ? Color.lerp(Colors.lightBlue, Colors.amber, value * 2)!
        : Color.lerp(Colors.orange, Colors.red.shade700, (value - 0.5) * 2)!;
    final outline = Paint()
      ..color = frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.06;
    // Glass first, the tube under the bulb, so the two read as one piece.
    canvas.drawRRect(RRect.fromRectAndRadius(tubeRect, Radius.circular(tube / 2)), Paint()..color = glass);
    canvas.drawRRect(RRect.fromRectAndRadius(tubeRect, Radius.circular(tube / 2)), outline);
    canvas.drawCircle(bulb, r * 0.92, Paint()..color = glass);
    canvas.drawCircle(bulb, r * 0.92, outline);
    if (full) {
      canvas.drawCircle(
        bulb,
        r * 1.3,
        Paint()
          ..color = red.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
      );
    }
    final mercury = tube * 0.55;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r, r - mercury / 2, (tubeRect.width - tube * 0.3) * value + r * 0.2, mercury),
        Radius.circular(mercury / 2),
      ),
      Paint()..color = red,
    );
    canvas.drawCircle(bulb, r * 0.7, Paint()..color = red);
    // Scale marks along the tube.
    final marks = Paint()
      ..color = frame.withValues(alpha: 0.6)
      ..strokeWidth = size.height * 0.03;
    for (var i = 1; i < 10; i++) {
      final x = tubeRect.left + tubeRect.width * i / 10;
      canvas.drawLine(Offset(x, tubeRect.top - size.height * 0.06), Offset(x, tubeRect.top - size.height * 0.16), marks);
    }
  }

  @override
  bool shouldRepaint(_ThermometerPainter old) => old.value != value || old.full != full || old.frame != frame;
}

/// The flux capacitor: three arms of lights meeting in a Y. The lights come
/// on and pulse faster as the round goes on; when the last item is done
/// rays of energy stream out of its core.
class FluxCapacitor extends StatefulWidget {
  const FluxCapacitor({super.key, required this.value, required this.unleashed, required this.size});

  /// 0 to 1: how charged it is.
  final double value;

  /// The round is over: the beam goes off.
  final bool unleashed;
  final double size;

  @override
  State<FluxCapacitor> createState() => _FluxCapacitorState();
}

class _FluxCapacitorState extends State<FluxCapacitor> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  late final AnimationController _beam = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    if (widget.unleashed) _beam.value = 1;
  }

  @override
  void didUpdateWidget(FluxCapacitor old) {
    super.didUpdateWidget(old);
    if (widget.unleashed && !old.unleashed) _beam.forward(from: 0);
    if (!widget.unleashed && old.unleashed) _beam.value = 0;
  }

  @override
  void dispose() {
    _pulse.dispose();
    _beam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _beam]),
          builder: (context, _) => CustomPaint(
            painter: FluxPainter(charge: widget.value, pulse: _pulse.value, beam: widget.unleashed ? _beam.value : 0),
          ),
        ),
      ),
    );
  }
}

class FluxPainter extends CustomPainter {
  FluxPainter({required this.charge, required this.pulse, required this.beam});

  final double charge;

  /// 0 to 1, round and round: where the travelling light is.
  final double pulse;

  /// 0 to 1 once unleashed: the beam's life, from first flash to a steady glow.
  final double beam;

  static const _lights = 6;
  static const _hot = Color(0xFFFFF6C8);
  static const _glow = Color(0xFF7FD8FF);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final housing = RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.04, s * 0.04, s * 0.92, s * 0.92), Radius.circular(s * 0.06));
    canvas.drawRRect(housing, Paint()..color = const Color(0xFF2E3136));
    canvas.drawRRect(
      housing,
      Paint()
        ..color = const Color(0xFF8A9099)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018,
    );
    // The window in front of the works.
    final window = RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.12, s * 0.12, s * 0.76, s * 0.76), Radius.circular(s * 0.03));
    canvas.drawRRect(window, Paint()..color = const Color(0xFF15171A));

    final centre = Offset(s * 0.5, s * 0.56);
    final ends = [Offset(s * 0.22, s * 0.2), Offset(s * 0.78, s * 0.2), Offset(s * 0.5, s * 0.84)];
    final tube = Paint()
      ..color = const Color(0xFF4A4F57)
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.round;
    for (final end in ends) {
      canvas.drawLine(end, centre, tube);
    }

    // Faster and brighter the fuller it is.
    final lit = (charge * _lights).ceil().clamp(0, _lights);
    final speed = 1 + charge * 3;
    final travelling = (pulse * speed) % 1;
    for (final end in ends) {
      for (var i = 0; i < _lights; i++) {
        final t = 0.08 + 0.78 * i / (_lights - 1);
        final at = Offset.lerp(end, centre, t)!;
        final on = i < lit;
        final near = on ? max(0.0, 1 - (travelling - t).abs() * 6) : 0.0;
        final radius = s * (0.026 + 0.012 * near);
        if (on) {
          canvas.drawCircle(
            at,
            radius * 2.4,
            Paint()
              ..color = _glow.withValues(alpha: 0.25 + 0.45 * near)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.025),
          );
        }
        canvas.drawCircle(at, radius, Paint()..color = on ? Color.lerp(_hot, Colors.white, near)! : const Color(0xFF3A3E44));
      }
    }

    // The core glows with the charge.
    canvas.drawCircle(
      centre,
      s * (0.05 + 0.08 * charge),
      Paint()
        ..color = _glow.withValues(alpha: 0.2 + 0.6 * charge)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05),
    );
    canvas.drawCircle(centre, s * 0.045, Paint()..color = Color.lerp(const Color(0xFF555A61), _hot, charge)!);

    if (beam > 0) _paintBeam(canvas, size, centre, housing);
  }

  /// Charged: after a flash, rays of light keep streaming out of the core
  /// all round, turning slowly.
  void _paintBeam(Canvas canvas, Size size, Offset centre, RRect housing) {
    final s = size.width;
    final flash = beam < 0.25 ? beam / 0.25 : max(0.0, 1 - (beam - 0.25) / 0.35);
    final grow = Curves.easeOutExpo.transform((beam / 0.35).clamp(0.0, 1.0));
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.12, s * 0.12, s * 0.76, s * 0.76), Radius.circular(s * 0.03)));
    // A halo round the core, breathing.
    final hum = 0.85 + 0.15 * sin(pulse * 2 * pi * 4);
    canvas.drawCircle(
      centre,
      s * (0.12 + 0.06 * flash) * hum * grow,
      Paint()
        ..color = _glow.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05),
    );
    const rays = 16;
    for (var i = 0; i < rays; i++) {
      final angle = i / rays * 2 * pi + pulse * pi;
      final direction = Offset(cos(angle), sin(angle));
      // Each ray is a dash of light running outwards, then the next one.
      for (var wave = 0; wave < 2; wave++) {
        final t = (pulse * 3 + i * 0.37 + wave * 0.5) % 1;
        final inner = s * (0.07 + 0.3 * t) * grow;
        final outer = inner + s * 0.1 * grow;
        final alpha = (1 - t) * (0.6 + 0.4 * max(flash, 0.5));
        final from = centre + direction * inner;
        final to = centre + direction * outer;
        canvas.drawLine(
          from,
          to,
          Paint()
            ..color = _glow.withValues(alpha: alpha * 0.7)
            ..strokeWidth = s * 0.03
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.012),
        );
        canvas.drawLine(
          from,
          to,
          Paint()
            ..color = Color.lerp(Colors.white, _hot, t)!.withValues(alpha: alpha)
            ..strokeWidth = s * 0.012
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    canvas.restore();
    // The whole thing lights up for a moment.
    if (flash > 0) {
      canvas.drawRRect(housing, Paint()..color = Colors.white.withValues(alpha: 0.35 * flash));
    }
  }

  @override
  bool shouldRepaint(FluxPainter old) => old.charge != charge || old.pulse != pulse || old.beam != beam;
}
