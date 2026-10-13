import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';

/// Every whiteboard has this shape, so a drawing looks the same on the
/// tablet it was made on, on the controller and on the big screen.
const double kWhiteboardAspect = 4 / 3;

/// Paper, guides and ink of a whiteboard.
class WhiteboardPainter extends CustomPainter {
  WhiteboardPainter({
    required this.strokes,
    this.background = 'blank',
    this.listRows = 5,
    this.paper = Colors.white,
    this.ink = const Color(0xFF1B1B1F),
    this.guide = const Color(0x33000000),
  });

  final List<Stroke> strokes;
  final String background;
  final int listRows;
  final Color paper;
  final Color ink;
  final Color guide;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final guidePaint = Paint()
      ..color = guide
      ..strokeWidth = size.height * 0.004;
    switch (background) {
      case 'lines':
        for (var i = 1; i < 8; i++) {
          final y = size.height * i / 8;
          canvas.drawLine(Offset(size.width * 0.04, y), Offset(size.width * 0.96, y), guidePaint);
        }
      case 'grid':
        const columns = 16;
        final cell = size.width / columns;
        for (var x = cell; x < size.width - 1; x += cell) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), guidePaint);
        }
        for (var y = cell; y < size.height - 1; y += cell) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
        }
      case 'list':
        // Numbered rows to fill in, one answer per row.
        final rowHeight = size.height / listRows;
        for (var i = 0; i < listRows; i++) {
          final bottom = rowHeight * (i + 1) - rowHeight * 0.14;
          final number = TextPainter(
            text: TextSpan(
              text: '${i + 1}.',
              style: TextStyle(color: guide.withValues(alpha: 0.55), fontSize: rowHeight * 0.42, fontWeight: FontWeight.w600),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          number.paint(canvas, Offset(size.width * 0.03, bottom - number.height));
          canvas.drawLine(Offset(size.width * 0.12, bottom), Offset(size.width * 0.96, bottom), guidePaint);
        }
    }

    final inkPaint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.012
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(
          Offset(stroke[0].$1 * size.width, stroke[0].$2 * size.height),
          inkPaint.strokeWidth / 2,
          Paint()..color = ink,
        );
        continue;
      }
      final path = Path()..moveTo(stroke[0].$1 * size.width, stroke[0].$2 * size.height);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.$1 * size.width, point.$2 * size.height);
      }
      canvas.drawPath(path, inkPaint);
    }
  }

  @override
  bool shouldRepaint(WhiteboardPainter old) => true;
}

/// A drawing, read-only.
class DrawingView extends StatelessWidget {
  const DrawingView({super.key, required this.drawing, this.background = 'blank', this.listRows = 5});

  final String? drawing;
  final String background;
  final int listRows;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: kWhiteboardAspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: WhiteboardPainter(strokes: decodeDrawing(drawing), background: background, listRows: listRows),
        ),
      ),
    );
  }
}

/// A whiteboard to draw on with a finger or pen.
class WhiteboardPad extends StatefulWidget {
  const WhiteboardPad({
    super.key,
    required this.onChanged,
    this.initial,
    this.enabled = true,
    this.background = 'blank',
    this.listRows = 5,
  });

  /// Called with the encoded drawing after every stroke, undo and clear.
  final ValueChanged<String> onChanged;
  final String? initial;
  final bool enabled;
  final String background;
  final int listRows;

  @override
  State<WhiteboardPad> createState() => _WhiteboardPadState();
}

class _WhiteboardPadState extends State<WhiteboardPad> {
  late final List<Stroke> _strokes = decodeDrawing(widget.initial);

  void _emit() => widget.onChanged(encodeDrawing(_strokes));

  InkPoint _point(Offset local, Size size) =>
      ((local.dx / size.width).clamp(0.0, 1.0).toDouble(), (local.dy / size.height).clamp(0.0, 1.0).toDouble());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: AspectRatio(
            aspectRatio: kWhiteboardAspect,
            child: LayoutBuilder(
              builder: (context, box) {
                final size = box.biggest;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: !widget.enabled ? null : (d) => setState(() => _strokes.add([_point(d.localPosition, size)])),
                    onPanUpdate: !widget.enabled ? null : (d) => setState(() => _strokes.last.add(_point(d.localPosition, size))),
                    onPanEnd: !widget.enabled ? null : (_) => _emit(),
                    // A tap leaves a dot: the point of an "i", a decimal point.
                    onTapUp: !widget.enabled
                        ? null
                        : (d) {
                            setState(() => _strokes.add([_point(d.localPosition, size)]));
                            _emit();
                          },
                    child: CustomPaint(
                      size: size,
                      painter: WhiteboardPainter(strokes: _strokes, background: widget.background, listRows: widget.listRows),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: widget.enabled && _strokes.isNotEmpty
                  ? () {
                      setState(_strokes.removeLast);
                      _emit();
                    }
                  : null,
              icon: const Icon(Icons.undo),
              label: const Text("Undo"),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: widget.enabled && _strokes.isNotEmpty
                  ? () {
                      setState(_strokes.clear);
                      _emit();
                    }
                  : null,
              icon: Icon(Icons.delete_outline, color: widget.enabled && _strokes.isNotEmpty ? scheme.error : null),
              label: const Text("Clear"),
            ),
          ],
        ),
      ],
    );
  }
}
