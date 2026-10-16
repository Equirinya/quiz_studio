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
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _confetti.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
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
