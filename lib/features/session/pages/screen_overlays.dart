import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:quiz_show/core/theme.dart';
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
                            key: ValueKey('${card.title}|${card.text}|${card.image}|${card.style.name}'),
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
    if (card.style == CardStyle.silentFilm) return _SilentFilmCard(card: card, image: image, unit: unit);
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
    final poster = card.style == CardStyle.poster;
    final plain = card.style == CardStyle.plain;
    // Words straight on the dimmed screen need a shadow to stand out.
    final shadows = plain ? [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: unit * 1.5)] : null;
    final titleStyle = switch (card.style) {
      CardStyle.poster => TextStyle(
          fontSize: unit * 9,
          fontWeight: FontWeight.w900,
          letterSpacing: unit * 0.3,
          height: 1.05,
          color: scheme.onPrimary,
        ),
      CardStyle.plain => TextStyle(fontSize: unit * 9, fontWeight: FontWeight.w800, color: Colors.white, shadows: shadows),
      _ => TextStyle(fontSize: unit * 6, fontWeight: FontWeight.w700, color: scheme.primary),
    };
    final textStyle = switch (card.style) {
      CardStyle.poster => TextStyle(fontSize: unit * 5, fontWeight: FontWeight.w600, color: scheme.onPrimary),
      CardStyle.plain => TextStyle(fontSize: unit * 6.5, fontWeight: FontWeight.w600, color: Colors.white, shadows: shadows),
      _ => TextStyle(fontSize: unit * 4.5, color: scheme.onSurface),
    };
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: box.maxWidth * (plain ? 0.9 : 0.8), maxHeight: box.maxHeight * 0.84),
        padding: EdgeInsets.all(unit * (poster ? 5 : 4)),
        decoration: plain
            ? null
            : poster
                ? BoxDecoration(
                    color: scheme.primary,
                    border: Border.all(color: scheme.onPrimary, width: unit * 0.8),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: unit * 4, offset: Offset(0, unit))],
                  )
                : BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(unit * 4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((card.title ?? '').isNotEmpty)
              Text(
                poster ? card.title!.toUpperCase() : card.title!,
                textAlign: TextAlign.center,
                style: titleStyle,
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
                child: Text(card.text!, textAlign: TextAlign.center, style: textStyle),
              ),
          ],
        ),
      ),
    );
  }
}

/// An intertitle of a silent film: cream serif letters on black inside an
/// Art Deco frame, with the grain, scratches and vignette of old film stock.
/// A picture is shown in sepia.
class _SilentFilmCard extends StatelessWidget {
  const _SilentFilmCard({required this.card, required this.image, required this.unit});

  final OverlayCard card;
  final ImageProvider? image;
  final double unit;

  static const Color cream = Color(0xFFEDE3C8);
  static const Color black = Color(0xFF0D0B08);

  /// Turns any picture brown like an old print.
  static const ColorFilter sepia = ColorFilter.matrix([
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final title = card.title ?? '';
    final text = card.text ?? '';
    final serif = TextStyle(fontFamily: kSerifFamily, fontFamilyFallback: kSerifFallback, color: cream, height: 1.35);
    return ColoredBox(
      color: black,
      child: CustomPaint(
        // The same card gets the same specks every time it is shown.
        foregroundPainter: _FilmStockPainter(seed: Object.hash(title, text, card.image), unit: unit),
        child: CustomPaint(
          painter: _IntertitleFramePainter(unit: unit, color: cream),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: unit * 16, vertical: unit * 12),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: serif.copyWith(fontSize: unit * 5.5, letterSpacing: unit * 0.8, fontWeight: FontWeight.w600),
                    ),
                  if (title.isNotEmpty && (text.isNotEmpty || image != null))
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: unit * 2.5),
                      child: _Flourish(unit: unit, color: cream),
                    ),
                  if (image != null)
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: text.isNotEmpty ? unit * 3 : 0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(border: Border.all(color: cream, width: unit * 0.3)),
                          child: ColorFiltered(colorFilter: sepia, child: Image(image: image!, fit: BoxFit.contain)),
                        ),
                      ),
                    ),
                  if (text.isNotEmpty)
                    Text(text, textAlign: TextAlign.center, style: serif.copyWith(fontSize: unit * 5.6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A short rule with a diamond in the middle, between title and text.
class _Flourish extends StatelessWidget {
  const _Flourish({required this.unit, required this.color});

  final double unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget line() => Container(width: unit * 12, height: unit * 0.25, color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: unit * 1.5),
          child: Transform.rotate(angle: pi / 4, child: Container(width: unit * 1.4, height: unit * 1.4, color: color)),
        ),
        line(),
      ],
    );
  }
}

/// Two thin rules around the screen with stepped Art Deco corners.
class _IntertitleFramePainter extends CustomPainter {
  _IntertitleFramePainter({required this.unit, required this.color});

  final double unit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.3;
    final outer = Rect.fromLTWH(unit * 5, unit * 5, size.width - unit * 10, size.height - unit * 10);
    final inner = outer.deflate(unit * 1.6);
    canvas.drawRect(outer, paint);
    canvas.drawRect(inner, paint..strokeWidth = unit * 0.15);
    // Each corner: two steps cut inwards and a diamond where they meet.
    final step = unit * 3;
    final fill = Paint()..color = color;
    for (final (corner, dx, dy) in [
      (inner.topLeft, 1.0, 1.0),
      (inner.topRight, -1.0, 1.0),
      (inner.bottomLeft, 1.0, -1.0),
      (inner.bottomRight, -1.0, -1.0),
    ]) {
      final path = Path()
        ..moveTo(corner.dx + dx * step * 2, corner.dy)
        ..lineTo(corner.dx + dx * step * 2, corner.dy + dy * step)
        ..lineTo(corner.dx + dx * step, corner.dy + dy * step)
        ..lineTo(corner.dx + dx * step, corner.dy + dy * step * 2)
        ..lineTo(corner.dx, corner.dy + dy * step * 2);
      canvas.drawPath(path, paint..strokeWidth = unit * 0.25);
      final centre = Offset(corner.dx + dx * step * 2, corner.dy + dy * step * 2);
      final d = unit * 0.9;
      canvas.drawPath(
        Path()
          ..moveTo(centre.dx, centre.dy - d)
          ..lineTo(centre.dx + d, centre.dy)
          ..lineTo(centre.dx, centre.dy + d)
          ..lineTo(centre.dx - d, centre.dy)
          ..close(),
        fill,
      );
    }
    // A small fan in the middle of the top and bottom rules.
    for (final (y, dir) in [(inner.top, 1.0), (inner.bottom, -1.0)]) {
      final x = inner.center.dx;
      for (var i = -2; i <= 2; i++) {
        canvas.drawLine(Offset(x, y), Offset(x + i * unit * 1.2, y + dir * unit * 2.4), paint..strokeWidth = unit * 0.15);
      }
    }
  }

  @override
  bool shouldRepaint(_IntertitleFramePainter old) => old.unit != unit || old.color != color;
}

/// Old film stock over the card: dust, a few scratches, a dark vignette.
class _FilmStockPainter extends CustomPainter {
  _FilmStockPainter({required this.seed, required this.unit});

  final int seed;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
          stops: const [0.55, 1],
        ).createShader(rect),
    );
    final dust = Paint();
    for (var i = 0; i < 900; i++) {
      final light = random.nextBool();
      dust.color = (light ? const Color(0xFFEDE3C8) : Colors.black).withValues(alpha: 0.05 + random.nextDouble() * 0.12);
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
        unit * (0.04 + random.nextDouble() * 0.12),
        dust,
      );
    }
    final scratch = Paint()..strokeWidth = unit * 0.08;
    for (var i = 0; i < 4; i++) {
      final x = random.nextDouble() * size.width;
      final top = random.nextDouble() * size.height * 0.5;
      scratch.color = const Color(0xFFEDE3C8).withValues(alpha: 0.08 + random.nextDouble() * 0.1);
      canvas.drawLine(Offset(x, top), Offset(x + (random.nextDouble() - 0.5) * unit, top + size.height * (0.3 + random.nextDouble() * 0.5)), scratch);
    }
  }

  @override
  bool shouldRepaint(_FilmStockPainter old) => old.seed != seed || old.unit != unit;
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
