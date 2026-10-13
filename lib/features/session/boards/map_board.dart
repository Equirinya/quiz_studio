import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:quiz_show/features/session/boards/map_arrows.dart';
import 'package:quiz_show/game/game.dart';

/// The map: every category a bubble holding its questions, connected by
/// arrows in the order they are played, with branches where several follow
/// the same one. Titles, pictures and lines placed in the editor lie around
/// them.
class MapBoard extends StatefulWidget {
  const MapBoard({super.key, required this.group, required this.state, required this.imageFile});

  final CategoryGroup group;
  final SessionState state;

  /// Resolves a media file name to a local file, or null when it is missing.
  final File? Function(String name) imageFile;

  @override
  State<MapBoard> createState() => _MapBoardState();
}

class _MapBoardState extends State<MapBoard> {
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
        final cellWidth = size.width / map.columns;
        final cellHeight = size.height / map.rows;
        // A bubble gets most of its cell, but never grows absurdly large on
        // a map with only a few of them. Arrows need room between bubbles.
        final bubbleWidth = min(min(cellWidth * 0.72, cellHeight * 1.4), size.width * 0.28);
        final unit = bubbleWidth / 13;
        Offset at(MapPoint point) => Offset(point.x * size.width, point.y * size.height);
        Rect rectOf(String id) {
          final bubble = _sizes[id] ?? Size(bubbleWidth, bubbleWidth * 0.5);
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
                  width: bubbleWidth,
                  unit: unit,
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
    final head = width * 4.2;
    for (final (arrow, active) in arrows) {
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
