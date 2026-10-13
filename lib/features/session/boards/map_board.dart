import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';

/// The map: every category a bubble holding its questions, connected in the
/// order they are played, with branches where several follow the same one.
/// Titles, pictures and lines placed in the editor lie around them.
class MapBoard extends StatelessWidget {
  const MapBoard({super.key, required this.group, required this.state, required this.imageFile});

  final CategoryGroup group;
  final SessionState state;

  /// Resolves a media file name to a local file, or null when it is missing.
  final File? Function(String name) imageFile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final map = layoutMap(group);
    final labels = mapShowsLabels(group);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final cellWidth = size.width / map.columns;
        final cellHeight = size.height / map.rows;
        // A bubble gets most of its cell, but never grows absurdly large on
        // a map with only a few of them.
        final bubbleWidth = min(min(cellWidth * 0.8, cellHeight * 1.5), size.width * 0.3);
        final unit = bubbleWidth / 13;
        Offset at(MapPoint point) => Offset(point.x * size.width, point.y * size.height);

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
                  edges: [for (final (from, to) in map.edges) (at(map.nodes[from]!), at(map.nodes[to]!))],
                  lines: [for (final line in map.decorations.whereType<MapLine>()) (at(line.from), at(line.to))],
                  color: scheme.secondary,
                  lineColor: scheme.outline,
                  width: unit * 0.45,
                ),
              ),
            ),
            for (final image in map.decorations.whereType<MapImage>())
              if (imageFile(image.image) case final file?)
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
                _Bubble(category: category, state: state, width: bubbleWidth, unit: unit, labels: labels),
              ),
          ],
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.category, required this.state, required this.width, required this.unit, required this.labels});

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
        border: Border.all(color: active ? scheme.primary : scheme.outlineVariant, width: unit * (active ? 0.3 : 0.12)),
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
  _ConnectionsPainter({required this.edges, required this.lines, required this.color, required this.lineColor, required this.width});

  final List<(Offset, Offset)> edges;
  final List<(Offset, Offset)> lines;
  final Color color;
  final Color lineColor;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    for (final (from, to) in edges) {
      // An S-curve that leaves and arrives along the main direction, like
      // the connectors of an organisation chart.
      final path = Path()..moveTo(from.dx, from.dy);
      if ((to.dx - from.dx).abs() >= (to.dy - from.dy).abs()) {
        final mid = (from.dx + to.dx) / 2;
        path.cubicTo(mid, from.dy, mid, to.dy, to.dx, to.dy);
      } else {
        final mid = (from.dy + to.dy) / 2;
        path.cubicTo(from.dx, mid, to.dx, mid, to.dx, to.dy);
      }
      canvas.drawPath(path, paint);
    }
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = width * 0.6
      ..strokeCap = StrokeCap.round;
    for (final (from, to) in lines) {
      canvas.drawLine(from, to, linePaint);
    }
  }

  @override
  bool shouldRepaint(_ConnectionsPainter old) =>
      old.color != color || old.width != width || !_same(old.edges, edges) || !_same(old.lines, lines);

  static bool _same(List<(Offset, Offset)> a, List<(Offset, Offset)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
