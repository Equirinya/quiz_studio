import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:quiz_show/features/session/boards/map_arrows.dart';
import 'package:quiz_show/game/game.dart';

/// Where the window onto a map has to start so that the bubble at [x] (a
/// fraction of the canvas) sits in its middle, without running off either
/// end of the canvas.
double mapScrollOffset(double x, double canvasWidth, double viewportWidth) {
  final most = canvasWidth - viewportWidth;
  return most <= 0 ? 0 : (x * canvasWidth - viewportWidth / 2).clamp(0.0, most).toDouble();
}

/// The map as the audience sees it: every category a bubble holding its
/// questions, connected by arrows in the order they are played.
///
/// The canvas may be wider than the screen. The board then shows a window
/// onto it and glides to wherever the game is: when a question opens, its
/// category's bubble is brought to the middle, as far as the ends of the
/// canvas allow.
class MapBoard extends StatefulWidget {
  const MapBoard({super.key, required this.group, required this.state, required this.imageFile});

  final CategoryGroup group;
  final SessionState state;

  /// Resolves a media file name to a local file, or null when it is missing.
  final File? Function(String name) imageFile;

  @override
  State<MapBoard> createState() => _MapBoardScrollState();
}

class _MapBoardScrollState extends State<MapBoard> {
  final ScrollController _scroll = ScrollController();

  /// The category the window was last moved to.
  String? _focus;
  bool _placed = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _follow(MapLayout map, double canvasWidth, double viewportWidth) {
    if (!mounted || !_scroll.hasClients) return;
    final current = widget.state.current?.categoryId;
    final focus = current != null && map.nodes.containsKey(current) ? current : null;
    if (_placed && focus == _focus) return;
    final first = !_placed;
    _placed = true;
    // With no question open the window stays where the last one left it.
    if (focus == null) return;
    _focus = focus;
    final target = mapScrollOffset(map.nodes[focus]!.x, canvasWidth, viewportWidth);
    if (first) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 900), curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final map = layoutMap(widget.group);
    return LayoutBuilder(
      builder: (context, box) {
        final canvasWidth = box.maxWidth * map.widthFactor;
        WidgetsBinding.instance.addPostFrameCallback((_) => _follow(map, canvasWidth, box.maxWidth));
        return SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: canvasWidth,
            height: box.maxHeight,
            child: MapCanvas(group: widget.group, state: widget.state, imageFile: widget.imageFile, viewportWidth: box.maxWidth),
          ),
        );
      },
    );
  }
}

/// The whole map canvas, drawn at whatever size it is given. [MapBoard]
/// scrolls it for the audience; the editor lays its handles over it.
class MapCanvas extends StatefulWidget {
  const MapCanvas({super.key, required this.group, required this.state, required this.imageFile, required this.viewportWidth});

  final CategoryGroup group;
  final SessionState state;
  final File? Function(String name) imageFile;

  /// Width of one screen; bubbles are sized against this, not against a
  /// canvas that may be several screens wide.
  final double viewportWidth;

  /// The width of a bubble of scale 1 on a canvas of [canvas] laid out as
  /// [map], seen through a window [viewportWidth] wide.
  static double bubbleWidth(MapLayout map, Size canvas, double viewportWidth) =>
      min(min(canvas.width / map.columns * 0.72, canvas.height / map.rows * 1.4), viewportWidth * 0.28);

  @override
  State<MapCanvas> createState() => _MapBoardState();
}

class _MapBoardState extends State<MapCanvas> {
  final Map<String, GlobalKey> _keys = {};

  /// How large each bubble turned out, so arrows can meet their edges. A
  /// bubble's height depends on its content and is only known once laid out.
  Map<String, Size> _sizes = const {};

  void _measure() {
    if (!mounted) return;
    final sizes = <String, Size>{
      for (final entry in _keys.entries)
        if (entry.value.currentContext?.findRenderObject() case final RenderBox box when box.hasSize) entry.key: box.size,
    };
    final changed = sizes.length != _sizes.length || sizes.entries.any((e) => _sizes[e.key] != e.value);
    if (changed) setState(() => _sizes = sizes);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final group = widget.group;
    final state = widget.state;
    final map = layoutMap(group);
    final labels = mapShowsLabels(group);
    _keys.removeWhere((id, _) => !map.nodes.containsKey(id));
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        // A bubble gets most of its cell, but never grows absurdly large on
        // a map with only a few of them. Arrows need room between bubbles.
        final bubbleWidth = MapCanvas.bubbleWidth(map, size, widget.viewportWidth);
        final unit = bubbleWidth / 13;
        Offset at(MapPoint point) => Offset(point.x * size.width, point.y * size.height);
        Rect rectOf(String id) {
          final bubble = _sizes[id] ?? Size(bubbleWidth * map.scaleOf(id), bubbleWidth * map.scaleOf(id) * 0.5);
          return Rect.fromCenter(center: at(map.nodes[id]!), width: bubble.width, height: bubble.height);
        }

        bool done(String categoryId) {
          final category = group.categories.firstWhere((c) => c.id == categoryId);
          return category.questions.isNotEmpty &&
              category.questions.every((q) => state.played.contains(QuestionRef(category.id, q.id).key));
        }

        Widget centred(MapPoint point, Widget child) => Positioned(
              left: at(point).dx,
              top: at(point).dy,
              child: FractionalTranslation(translation: const Offset(-0.5, -0.5), child: child),
            );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ConnectionsPainter(
                  arrows: [
                    for (final (from, to) in map.edges)
                      // The way out of a finished bubble lights up: this is
                      // where the game goes next.
                      (routeArrow(rectOf(from), rectOf(to), gap: unit * 0.5), done(from)),
                  ],
                  lines: [for (final line in map.decorations.whereType<MapLine>()) (at(line.from), at(line.to))],
                  color: scheme.outline,
                  activeColor: scheme.primary,
                  lineColor: scheme.outline,
                  width: unit * 0.3,
                ),
              ),
            ),
            for (final image in map.decorations.whereType<MapImage>())
              if (widget.imageFile(image.image) case final file?)
                centred(
                  image.center,
                  ClipRRect(
                    borderRadius: BorderRadius.circular(unit),
                    child: Image.file(file, width: image.width * size.width, fit: BoxFit.contain),
                  ),
                ),
            for (final title in map.decorations.whereType<MapTitle>())
              centred(
                title.center,
                Text(
                  title.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: unit * 1.5 * title.size, fontWeight: FontWeight.w700, color: scheme.onSurface),
                ),
              ),
            for (final category in group.categories)
              centred(
                map.nodes[category.id]!,
                _Bubble(
                  key: _keys.putIfAbsent(category.id, GlobalKey.new),
                  category: category,
                  state: state,
                  // A resized bubble grows as a whole, text and all.
                  width: bubbleWidth * map.scaleOf(category.id),
                  unit: unit * map.scaleOf(category.id),
                  labels: labels,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.category, required this.state, required this.width, required this.unit, required this.labels});

  final Category category;
  final SessionState state;
  final double width;
  final double unit;
  final bool labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final refs = [for (final question in category.questions) QuestionRef(category.id, question.id)];
    final done = refs.isNotEmpty && refs.every((ref) => state.played.contains(ref.key));
    final active = state.current?.categoryId == category.id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: width,
      padding: EdgeInsets.all(unit * 0.9),
      decoration: BoxDecoration(
        color: done ? scheme.surfaceContainerLow : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(unit * 2.2),
        border: Border.all(color: active ? scheme.primary : scheme.outlineVariant, width: unit * (active ? 0.3 : 0.1)),
        // Lifts the bubbles off the board, and the one in play a bit more.
        boxShadow: done
            ? null
            : [
                // The bubble in play glows; the others cast a soft shadow.
                BoxShadow(
                  color: (active ? scheme.primary : Colors.black).withValues(alpha: active ? 0.45 : 0.16),
                  blurRadius: unit * (active ? 3.5 : 2.6),
                  spreadRadius: active ? unit * 0.2 : 0,
                  offset: active ? Offset.zero : Offset(0, unit * 0.5),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            category.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: unit * 1.25,
              fontWeight: FontWeight.w700,
              color: done ? scheme.outline : scheme.onSurface,
            ),
          ),
          SizedBox(height: unit * 0.6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: unit * 0.4,
            runSpacing: unit * 0.4,
            children: [
              for (final (i, question) in category.questions.indexed)
                Builder(builder: (context) {
                  final played = state.played.contains(refs[i].key);
                  final open = state.current == refs[i];
                  return Container(
                    constraints: BoxConstraints(maxWidth: width - unit * 1.8),
                    padding: EdgeInsets.symmetric(horizontal: unit * 0.7, vertical: unit * 0.3),
                    decoration: BoxDecoration(
                      color: open
                          ? scheme.primary
                          : played
                              ? Colors.transparent
                              : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(unit),
                    ),
                    child: Text(
                      labels ? (question.description ?? question.pointsPlus.toString()) : question.pointsPlus.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: unit,
                        fontWeight: FontWeight.w600,
                        decoration: played ? TextDecoration.lineThrough : null,
                        color: open
                            ? scheme.onPrimary
                            : played
                                ? scheme.outline
                                : scheme.onPrimaryContainer,
                      ),
                    ),
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionsPainter extends CustomPainter {
  _ConnectionsPainter({
    required this.arrows,
    required this.lines,
    required this.color,
    required this.activeColor,
    required this.lineColor,
    required this.width,
  });

  /// Each arrow, and whether it leads on from a finished bubble.
  final List<(MapArrow, bool)> arrows;
  final List<(Offset, Offset)> lines;
  final Color color;
  final Color activeColor;
  final Color lineColor;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (arrow, active) in arrows) {
      // In a narrow gap the head shrinks with the arrow instead of filling it.
      final head = min(width * 4.2, (arrow.end - arrow.start).distance * 0.55);
      final paint = Paint()
        ..color = active ? activeColor : color
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? width * 1.35 : width
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawPath(arrow.shaft(head), paint)
        ..drawPath(arrow.head(head), Paint()..color = paint.color);
    }
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    for (final (from, to) in lines) {
      canvas.drawLine(from, to, linePaint);
    }
  }

  // Cheap to paint, and the arrows move with every measured bubble.
  @override
  bool shouldRepaint(_ConnectionsPainter old) => true;
}
