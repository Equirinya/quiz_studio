import 'package:flutter/material.dart';

/// Dims everything but a rounded square in the middle and marks its corners.
/// Painters taken over from v1's companion page.
class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    const cutoutSize = 260.0;

    return CustomPaint(
      painter: _OverlayPainter(
        cutoutSize: cutoutSize,
      ),
      child: SizedBox.expand(
        child: Center(
          child: SizedBox(
            width: cutoutSize,
            height: cutoutSize,
            child: _ScanCorners(),
          ),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final double cutoutSize;

  _OverlayPainter({required this.cutoutSize});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final half = cutoutSize / 2;

    final outer = Rect.fromLTWH(0, 0, size.width, size.height);
    final inner = Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half);

    final path = Path()
      ..addRect(outer)
      ..addRRect(RRect.fromRectAndRadius(inner, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _ScanCorners extends StatelessWidget {
  const _ScanCorners();

  @override
  Widget build(BuildContext context) {
    var accent = Theme.of(context).colorScheme.primary;
    const len = 28.0;
    const thick = 3.5;
    const r = 16.0;

    Widget corner({required Alignment align}) {
      return Align(
        alignment: align,
        child: CustomPaint(
          size: const Size(len, len),
          painter: _CornerPainter(
            alignment: align,
            color: accent,
            length: len,
            thickness: thick,
            radius: r,
          ),
        ),
      );
    }

    return Stack(
      children: [
        corner(align: Alignment.topLeft),
        corner(align: Alignment.topRight),
        corner(align: Alignment.bottomLeft),
        corner(align: Alignment.bottomRight),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Alignment alignment;
  final Color color;
  final double length;
  final double thickness;
  final double radius;

  const _CornerPainter({
    required this.alignment,
    required this.color,
    required this.length,
    required this.thickness,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final isLeft = alignment.x < 0;
    final isTop = alignment.y < 0;

    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;
    final dx = isLeft ? length : -length;
    final dy = isTop ? length : -length;
    final cx = isLeft ? radius : size.width - radius;
    final cy = isTop ? radius : size.height - radius;

    final path = Path()
      ..moveTo(x + dx, y)
      ..lineTo(cx, y)
      ..arcToPoint(
        Offset(x, cy),
        radius: Radius.circular(radius),
        clockwise: !((isLeft && isTop) || (!isLeft && !isTop)),
      )
      ..lineTo(x, y + dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
