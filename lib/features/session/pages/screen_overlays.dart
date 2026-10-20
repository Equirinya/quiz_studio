import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';

/// The card the gamemaster put over the screen: a title, a text, an image,
/// in any combination. The dimmed backdrop fades; the card itself comes and
/// goes with [animation].
class CardOverlay extends StatelessWidget {
  const CardOverlay({
    super.key,
    required this.card,
    required this.imageFile,
    this.videoBuilder,
    this.animation = CardAnimation.fade,
  });

  final OverlayCard? card;

  /// Resolves a media file name to a local file, or null when it is missing.
  final File? Function(String name) imageFile;

  /// Builds the player for a video file. Left out where video cannot play
  /// (tests, devices that are not presenting); the card's text shows instead.
  final Widget Function(File file)? videoBuilder;
  final CardAnimation animation;

  static Duration durationOf(CardAnimation animation) => switch (animation) {
        CardAnimation.off => Duration.zero,
        CardAnimation.fade => const Duration(milliseconds: 350),
        CardAnimation.bounce => const Duration(milliseconds: 900),
        CardAnimation.spin || CardAnimation.flip => const Duration(milliseconds: 700),
        _ => const Duration(milliseconds: 550),
      };

  /// [child] coming in as [t] goes from 0 to 1, and going out as it falls
  /// back; [t] is already curved.
  static Widget transition(CardAnimation animation, Animation<double> t, Widget child) {
    switch (animation) {
      case CardAnimation.off:
        return child;
      case CardAnimation.fade:
        return FadeTransition(opacity: t, child: child);
      case CardAnimation.slideUp:
      case CardAnimation.slideDown:
        final from = Offset(0, animation == CardAnimation.slideUp ? 1.2 : -1.2);
        return SlideTransition(position: Tween(begin: from, end: Offset.zero).animate(t), child: child);
      case CardAnimation.bounce:
        return ScaleTransition(scale: t, child: child);
      case CardAnimation.zoom:
        return FadeTransition(
          opacity: t,
          child: ScaleTransition(scale: Tween(begin: 2.2, end: 1.0).animate(t), child: child),
        );
      case CardAnimation.spin:
        return ScaleTransition(
          scale: t,
          child: RotationTransition(turns: Tween(begin: -1.0, end: 0.0).animate(t), child: child),
        );
      case CardAnimation.flip:
        return AnimatedBuilder(
          animation: t,
          child: child,
          builder: (context, child) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY((1 - t.value) * pi / 2),
            child: Opacity(opacity: t.value < 0.02 ? 0 : 1, child: child),
          ),
        );
    }
  }

  static Curve curveIn(CardAnimation animation) => switch (animation) {
        CardAnimation.bounce => Curves.elasticOut,
        CardAnimation.slideUp || CardAnimation.slideDown => Curves.easeOutBack,
        CardAnimation.spin => Curves.easeOutCubic,
        CardAnimation.flip => Curves.easeOutCubic,
        _ => Curves.easeOutCubic,
      };

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    final duration = durationOf(animation);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final video = card?.video == null || videoBuilder == null ? null : imageFile(card!.video!);
          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                opacity: card == null ? 0 : 1,
                duration: animation == CardAnimation.off ? Duration.zero : const Duration(milliseconds: 300),
                child: ColoredBox(color: video != null ? Colors.black : Colors.black.withValues(alpha: 0.72)),
              ),
              AnimatedSwitcher(
                duration: duration,
                // Going off screen is quicker and never springs.
                reverseDuration: animation == CardAnimation.off ? Duration.zero : const Duration(milliseconds: 320),
                switchInCurve: curveIn(animation),
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, t) => transition(
                  // A clip plays full screen; it only fades.
                  video != null && animation != CardAnimation.off ? CardAnimation.fade : animation,
                  t,
                  child,
                ),
                child: card == null
                    ? const SizedBox.expand(key: ValueKey('no-card'))
                    : video != null
                        ? Center(key: ValueKey('video-${card.video}'), child: videoBuilder!(video))
                        : _CardBody(
                            key: ValueKey('${card.title}|${card.text}|${card.image}'),
                            card: card,
                            box: box,
                            imageFile: imageFile,
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({super.key, required this.card, required this.box, required this.imageFile});

  final OverlayCard card;
  final BoxConstraints box;
  final File? Function(String name) imageFile;

  @override
  Widget build(BuildContext context) {
    final unit = box.maxHeight / 100;
    final scheme = Theme.of(context).colorScheme;
    final builtin = builtinImage(card.image);
    final file = card.image == null || builtin != null ? null : imageFile(card.image!);
    final ImageProvider? image = builtin != null ? AssetImage(builtin.asset) : (file == null ? null : FileImage(file));
    final hasText = (card.title ?? '').isNotEmpty || (card.text ?? '').isNotEmpty;
    // A picture on its own fills the screen, without a frame around it.
    if (image != null && !hasText) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(unit * 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(unit * 3),
            child: Image(image: image, fit: BoxFit.contain),
          ),
        ),
      );
    }
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: box.maxWidth * 0.8, maxHeight: box.maxHeight * 0.84),
        padding: EdgeInsets.all(unit * 4),
        decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(unit * 4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((card.title ?? '').isNotEmpty)
              Text(
                card.title!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: unit * 6, fontWeight: FontWeight.w700, color: scheme.primary),
              ),
            if (image != null)
              Flexible(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: unit * 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(unit * 2),
                    child: Image(image: image, fit: BoxFit.contain),
                  ),
                ),
              ),
            if ((card.text ?? '').isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: (card.title ?? '').isNotEmpty && image == null ? unit * 2 : 0),
                child: Text(
                  card.text!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: unit * 4.5, color: scheme.onSurface),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Plays one-shot animations over the screen as they come in on [effects].
class ScreenEffectLayer extends StatefulWidget {
  const ScreenEffectLayer({super.key, required this.effects});

  final Stream<Effect>? effects;

  @override
  State<ScreenEffectLayer> createState() => ScreenEffectLayerState();
}

class ScreenEffectLayerState extends State<ScreenEffectLayer> with TickerProviderStateMixin {
  late final AnimationController _confetti = AnimationController(vsync: this, duration: const Duration(milliseconds: 3800));
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final AnimationController _fireworks = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000));
  late final AnimationController _balloons = AnimationController(vsync: this, duration: const Duration(milliseconds: 6500));
  late final AnimationController _stars = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final AnimationController _spotlight = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500));
  StreamSubscription<Effect>? _sub;
  int _seed = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.effects?.listen((effect) {
      if (effect is VisualEffect) play(effect.name);
    });
  }

  /// Starts [name]; a running animation of the same kind restarts.
  void play(String name) {
    switch (name) {
      case screenEffectConfetti:
        setState(() => _seed++);
        _confetti.forward(from: 0);
      case screenEffectFlash:
        _flash.forward(from: 0);
      case screenEffectFireworks:
        setState(() => _seed++);
        _fireworks.forward(from: 0);
      case screenEffectBalloons:
        setState(() => _seed++);
        _balloons.forward(from: 0);
      case screenEffectStars:
        setState(() => _seed++);
        _stars.forward(from: 0);
      case screenEffectSpotlight:
        _spotlight.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _confetti.dispose();
    _flash.dispose();
    _fireworks.dispose();
    _balloons.dispose();
    _stars.dispose();
    _spotlight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = [scheme.primary, scheme.tertiary, scheme.secondary, Colors.amber, Colors.white];
    final bright = [Colors.redAccent, Colors.amber, Colors.lightBlueAccent, Colors.greenAccent, Colors.purpleAccent, Colors.pinkAccent];
    Widget layer(AnimationController controller, CustomPainter Function() painter) => AnimatedBuilder(
          animation: controller,
          builder: (context, _) => controller.isAnimating ? CustomPaint(painter: painter()) : const SizedBox(),
        );
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The spotlight darkens the room, so it goes under everything else.
          layer(_spotlight, () => SpotlightPainter(progress: _spotlight.value)),
          layer(_balloons, () => BalloonsPainter(progress: _balloons.value, seed: _seed, colors: bright)),
          layer(_fireworks, () => FireworksPainter(progress: _fireworks.value, seed: _seed, colors: bright)),
          layer(_stars, () => StarsPainter(progress: _stars.value, seed: _seed, colors: [...colors, Colors.yellowAccent])),
          AnimatedBuilder(
            animation: _confetti,
            builder: (context, _) => _confetti.isAnimating
                ? CustomPaint(
                    painter: ConfettiPainter(
                      progress: _confetti.value,
                      seed: _seed,
                      colors: [scheme.primary, scheme.tertiary, scheme.secondary, Colors.amber, Colors.white],
                    ),
                  )
                : const SizedBox(),
          ),
          AnimatedBuilder(
            animation: _flash,
            builder: (context, _) => _flash.isAnimating
                ? ColoredBox(color: Colors.white.withValues(alpha: (1 - _flash.value) * 0.85))
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}

/// Paper snippets falling from the top edge, each on its own path.
class ConfettiPainter extends CustomPainter {
  ConfettiPainter({required this.progress, required this.seed, required this.colors, this.count = 180});

  /// 0 at the start of the animation, 1 at its end.
  final double progress;
  final int seed;
  final List<Color> colors;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    // Everything fades out over the last fifth.
    final fade = progress < 0.8 ? 1.0 : (1 - progress) / 0.2;
    for (var i = 0; i < count; i++) {
      final x0 = random.nextDouble();
      final delay = random.nextDouble() * 0.3;
      final speed = 0.9 + random.nextDouble() * 0.9;
      final sway = (random.nextDouble() - 0.5) * 0.12;
      final swayRate = 4 + random.nextDouble() * 6;
      final spin = (random.nextDouble() - 0.5) * 30;
      final length = size.height * (0.012 + random.nextDouble() * 0.014);
      final color = colors[random.nextInt(colors.length)];
      final t = progress - delay;
      if (t <= 0) continue;
      final dx = (x0 + sway * sin(t * swayRate)) * size.width;
      final dy = (-0.05 + t * speed * 1.25) * size.height;
      if (dy > size.height + length) continue;
      canvas
        ..save()
        ..translate(dx, dy)
        ..rotate(t * spin)
        // Squashing one axis over time reads as the snippet tumbling.
        ..scale(1, 0.35 + 0.65 * cos(t * swayRate * 2).abs())
        ..drawRect(
          Rect.fromCenter(center: Offset.zero, width: length, height: length * 1.7),
          Paint()..color = color.withValues(alpha: fade),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => old.progress != progress || old.seed != seed;
}

/// Rockets that rise from the bottom edge and burst into sparks that fall.
class FireworksPainter extends CustomPainter {
  FireworksPainter({required this.progress, required this.seed, required this.colors, this.rockets = 7});

  final double progress;
  final int seed;
  final List<Color> colors;
  final int rockets;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    for (var r = 0; r < rockets; r++) {
      final start = random.nextDouble() * 0.45;
      final x = size.width * (0.12 + random.nextDouble() * 0.76);
      final apex = size.height * (0.15 + random.nextDouble() * 0.3);
      final color = colors[random.nextInt(colors.length)];
      final sparks = 50 + random.nextInt(30);
      final reach = size.height * (0.14 + random.nextDouble() * 0.12);
      // Each rocket: a quarter of the time rising, the rest bursting.
      final t = (progress - start) / 0.55;
      final angles = [for (var i = 0; i < sparks; i++) random.nextDouble() * 2 * pi];
      final speeds = [for (var i = 0; i < sparks; i++) 0.5 + random.nextDouble() * 0.5];
      if (t <= 0 || t >= 1) continue;
      if (t < 0.3) {
        final rise = Curves.easeOutQuad.transform(t / 0.3);
        final y = size.height - (size.height - apex) * rise;
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + size.height * 0.05),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, color.withValues(alpha: 0)],
            ).createShader(Rect.fromLTWH(x - 2, y, 4, size.height * 0.05))
            ..strokeWidth = size.height * 0.006
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(Offset(x, y), size.height * 0.006, Paint()..color = Colors.white);
        continue;
      }
      final b = (t - 0.3) / 0.7;
      final spread = Curves.easeOutCubic.transform(b);
      final fall = b * b * size.height * 0.08;
      final fade = (1 - b).clamp(0.0, 1.0);
      if (b < 0.15) {
        canvas.drawCircle(
          Offset(x, apex),
          reach * 0.5 * (1 - b / 0.15),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.6 * (1 - b / 0.15))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, reach * 0.2),
        );
      }
      for (var i = 0; i < sparks; i++) {
        final distance = reach * speeds[i] * spread;
        final at = Offset(x + cos(angles[i]) * distance, apex + sin(angles[i]) * distance + fall);
        final tail = Offset(x + cos(angles[i]) * distance * 0.85, apex + sin(angles[i]) * distance * 0.85 + fall * 0.8);
        canvas.drawLine(
          tail,
          at,
          Paint()
            ..color = color.withValues(alpha: fade)
            ..strokeWidth = size.height * 0.004
            ..strokeCap = StrokeCap.round,
        );
        // Some sparks twinkle white.
        if (i % 4 == 0) canvas.drawCircle(at, size.height * 0.0035, Paint()..color = Colors.white.withValues(alpha: fade));
      }
    }
  }

  @override
  bool shouldRepaint(FireworksPainter old) => old.progress != progress || old.seed != seed;
}

/// Balloons floating up from below the screen, swaying on their strings.
class BalloonsPainter extends CustomPainter {
  BalloonsPainter({required this.progress, required this.seed, required this.colors, this.count = 28});

  final double progress;
  final int seed;
  final List<Color> colors;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    for (var i = 0; i < count; i++) {
      final x0 = random.nextDouble();
      final delay = random.nextDouble() * 0.35;
      final speed = 0.8 + random.nextDouble() * 0.5;
      final radius = size.height * (0.04 + random.nextDouble() * 0.03);
      final swayRate = 2 + random.nextDouble() * 3;
      final color = colors[random.nextInt(colors.length)];
      final t = progress - delay;
      if (t <= 0) continue;
      final x = (x0 + 0.03 * sin(t * swayRate * pi)) * size.width;
      final y = size.height + radius * 3 - t * speed * (size.height + radius * 6) * 1.4;
      if (y < -radius * 4) continue;
      final body = Rect.fromCenter(center: Offset(x, y), width: radius * 1.7, height: radius * 2.1);
      final string = Path()
        ..moveTo(x, body.bottom + radius * 0.15)
        ..quadraticBezierTo(x + radius * 0.4 * sin(t * swayRate * 4), body.bottom + radius * 1.4, x, body.bottom + radius * 2.6);
      canvas.drawPath(
        string,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.06,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x - radius * 0.15, body.bottom + radius * 0.2)
          ..lineTo(x + radius * 0.15, body.bottom + radius * 0.2)
          ..lineTo(x, body.bottom - radius * 0.05)
          ..close(),
        Paint()..color = color,
      );
      canvas.drawOval(body, Paint()..color = color);
      // A shine on the upper left.
      canvas.drawOval(
        Rect.fromCenter(center: body.center + Offset(-radius * 0.35, -radius * 0.45), width: radius * 0.4, height: radius * 0.65),
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(BalloonsPainter old) => old.progress != progress || old.seed != seed;
}

/// Stars shooting out from the middle of the screen, spinning as they go.
class StarsPainter extends CustomPainter {
  StarsPainter({required this.progress, required this.seed, required this.colors, this.count = 60});

  final double progress;
  final int seed;
  final List<Color> colors;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final centre = size.center(Offset.zero);
    final reach = size.longestSide * 0.7;
    final fade = progress < 0.6 ? 1.0 : (1 - progress) / 0.4;
    for (var i = 0; i < count; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final radius = size.height * (0.012 + random.nextDouble() * 0.022);
      final spin = (random.nextDouble() - 0.5) * 12;
      final color = colors[random.nextInt(colors.length)];
      final distance = reach * speed * Curves.easeOutCubic.transform(progress);
      final at = centre + Offset(cos(angle), sin(angle)) * distance;
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(progress * spin)
        ..drawPath(_star(radius), Paint()..color = color.withValues(alpha: fade))
        ..restore();
    }
  }

  static Path _star(double radius) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final point = Offset(cos(a) * r, sin(a) * r);
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(StarsPainter old) => old.progress != progress || old.seed != seed;
}

/// The room goes dark except for a spotlight that sweeps across and settles
/// in the middle, then the lights come back.
class SpotlightPainter extends CustomPainter {
  SpotlightPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = progress < 0.1 ? progress / 0.1 : (progress > 0.85 ? (1 - progress) / 0.15 : 1.0);
    final sweep = Curves.easeInOutSine.transform((progress / 0.7).clamp(0.0, 1.0));
    // From the left edge across to the right, then back to the middle.
    final x = sweep < 0.6 ? size.width * (0.1 + sweep / 0.6 * 0.8) : size.width * (0.9 - (sweep - 0.6) / 0.4 * 0.4);
    final y = size.height * (0.5 + 0.08 * sin(sweep * pi * 3));
    final radius = size.height * 0.24;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black.withValues(alpha: 0.82 * dark));
    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.18),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SpotlightPainter old) => old.progress != progress;
}
