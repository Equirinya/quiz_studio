import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// The shape of a whiteboard on a device held sideways, and upright. A
/// drawing remembers which it was made on, so it looks the same on the
/// controller and on the big screen.
const double kWhiteboardAspect = kDefaultDrawingAspect;

/// The board shape that makes the most of [space] without getting so long
/// or so tall that it no longer fits a tile on the big screen.
double whiteboardAspectFor(Size space) {
  if (space.height <= 0) return kWhiteboardAspect;
  final ratio = space.width / space.height;
  return ratio >= 1 ? ratio.clamp(1.2, 1.6).toDouble() : ratio.clamp(0.62, 0.85).toDouble();
}

/// Paper, guides and ink of a whiteboard.
class WhiteboardPainter extends CustomPainter {
  WhiteboardPainter({
    required this.strokes,
    this.background = 'blank',
    this.listRows = 5,
    this.paper = Colors.white,
    this.ink = const Color(0xFF1B1B1F),
    this.guide = const Color(0x33000000),
    this.fontFamily,
    this.version = 0,
  });

  /// Bumped by whoever changes [strokes] in place, so the board is painted
  /// again; a new list of strokes does that by itself.
  final int version;

  /// The app's font, which a painter does not pick up from the theme.
  final String? fontFamily;

  final List<Stroke> strokes;
  final String background;
  final int listRows;
  final Color paper;
  final Color ink;
  final Color guide;

  /// Ink points painted so far, counted in debug builds only, for the
  /// whiteboard load benchmark (tool/whiteboard_load_test.dart).
  static int debugPaintedPoints = 0;

  @override
  void paint(Canvas canvas, Size size) {
    assert(() {
      debugPaintedPoints += strokes.fold(0, (sum, s) => sum + s.length);
      return true;
    }());
    // Over a picture the paper is left out, so the picture shows through.
    if (background != 'image') canvas.drawRect(Offset.zero & size, Paint()..color = paper);
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
              style: TextStyle(
                color: guide.withValues(alpha: 0.55),
                fontSize: rowHeight * 0.42,
                fontWeight: FontWeight.w600,
                fontFamily: fontFamily,
              ),
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
  bool shouldRepaint(WhiteboardPainter old) =>
      !identical(old.strokes, strokes) ||
      old.version != version ||
      old.background != background ||
      old.listRows != listRows ||
      old.paper != paper ||
      old.ink != ink ||
      old.guide != guide ||
      old.fontFamily != fontFamily;
}

/// A drawing, read-only.
///
/// Boards are shown live on the host while teams write, a dozen at a time
/// next to a running countdown. So each is read from its string only when
/// that string changes, and drawn once into a picture of its own that the
/// screen then just shows, rather than every stroke again on every frame.
class DrawingView extends StatefulWidget {
  const DrawingView({super.key, required this.drawing, this.background = 'blank', this.listRows = 5, this.backgroundImage});

  final String? drawing;
  final String background;
  final int listRows;

  /// The picture drawn on, for the "image" background; without it the ink
  /// is shown on plain paper.
  final ImageProvider? backgroundImage;

  @override
  State<DrawingView> createState() => _DrawingViewState();
}

class _DrawingViewState extends State<DrawingView> {
  late List<Stroke> _strokes = decodeDrawing(widget.drawing);

  @override
  void didUpdateWidget(DrawingView old) {
    super.didUpdateWidget(old);
    if (old.drawing != widget.drawing) _strokes = decodeDrawing(widget.drawing);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: drawingAspect(widget.drawing),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: WhiteboardSurface(
          background: widget.background,
          backgroundImage: widget.backgroundImage,
          ink: _InkPicture(
            board: WhiteboardPainter(
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              strokes: _strokes,
              background: widget.backgroundImage == null && widget.background == 'image' ? 'blank' : widget.background,
              listRows: widget.listRows,
            ),
          ),
        ),
      ),
    );
  }
}

/// [board] drawn into an image at the size it takes on screen, in its own
/// layer, and drawn again only when the board or that size changes.
class _InkPicture extends LeafRenderObjectWidget {
  const _InkPicture({required this.board});

  final WhiteboardPainter board;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderInkPicture(board);

  @override
  void updateRenderObject(BuildContext context, _RenderInkPicture renderObject) => renderObject.board = board;
}

class _RenderInkPicture extends RenderBox {
  _RenderInkPicture(this._board);

  WhiteboardPainter _board;
  set board(WhiteboardPainter value) {
    final changed = value.shouldRepaint(_board);
    _board = value;
    if (changed) {
      _drop();
      markNeedsPaint();
    }
  }

  ui.Image? _image;

  void _drop() {
    _image?.dispose();
    _image = null;
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.smallest;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    // As many pixels as the board covers on the screen, scaling included.
    final transform = getTransformTo(null);
    final scale = math.sqrt(transform.storage[0] * transform.storage[0] + transform.storage[1] * transform.storage[1]);
    final ratio = math.min(scale <= 0 ? 1.0 : scale, 4096 / math.max(size.width, size.height));
    final width = (size.width * ratio).ceil();
    final height = (size.height * ratio).ceil();
    var image = _image;
    if (image == null || image.width != width || image.height != height) {
      _drop();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(width / size.width, height / size.height);
      _board.paint(canvas, size);
      final picture = recorder.endRecording();
      image = _image = picture.toImageSync(width, height);
      picture.dispose();
    }
    context.canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      offset & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  void dispose() {
    _drop();
    super.dispose();
  }
}

/// Paper, an optional picture on it, and the ink on top. The picture is
/// fitted whole into the board and centred, the same way everywhere, so ink
/// lands on the same spot of it on every screen.
class WhiteboardSurface extends StatelessWidget {
  const WhiteboardSurface({super.key, required this.background, required this.backgroundImage, required this.ink});

  final String background;
  final ImageProvider? backgroundImage;
  final Widget ink;

  @override
  Widget build(BuildContext context) {
    final picture = background == 'image' ? backgroundImage : null;
    if (picture == null) return ink;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.white),
        Image(image: picture, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, _, _) => const SizedBox()),
        ink,
      ],
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
    this.aspect = kWhiteboardAspect,
    this.backgroundImage,
  });

  /// The picture to draw on, for the "image" background. May arrive after
  /// the board is on screen; the paper is plain until then.
  final ImageProvider? backgroundImage;

  /// Width / height of the board. Read once: a board keeps its shape even
  /// if the device is turned while drawing.
  final double aspect;

  /// Called with the encoded drawing after every stroke, undo and clear.
  final ValueChanged<String> onChanged;
  final String? initial;
  final bool enabled;
  final String background;
  final int listRows;

  @override
  State<WhiteboardPad> createState() => _WhiteboardPadState();
}

/// Whether iPadOS may treat Apple Pencil strokes as handwriting (Scribble).
/// While it may, it holds back the start of every stroke to decide, so it
/// is turned off while a board is on screen (ios/Runner/AppDelegate.swift).
class _PencilDrawing {
  static const _channel = MethodChannel('quiz_show/pencil');
  static int _boards = 0;

  static bool get _applies => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static void _set(bool drawing) {
    if (!_applies) return;
    _channel.invokeMethod<bool>('drawing', drawing).catchError((Object _) => false);
  }

  static void add() {
    if (_boards++ == 0) _set(true);
  }

  static void remove() {
    if (--_boards == 0) _set(false);
  }
}

class _WhiteboardPadState extends State<WhiteboardPad> {
  @override
  void initState() {
    super.initState();
    _PencilDrawing.add();
  }

  @override
  void dispose() {
    _PencilDrawing.remove();
    super.dispose();
  }

  late final List<Stroke> _strokes = decodeDrawing(widget.initial);
  late final double _aspect = widget.initial == null ? widget.aspect : drawingAspect(widget.initial);

  /// Counts changes to [_strokes], which is changed in place.
  int _version = 0;

  void _change(VoidCallback change) => setState(() {
    change();
    _version++;
  });

  void _emit() => widget.onChanged(encodeDrawing(_strokes, aspect: _aspect));

  InkPoint _point(Offset local, Size size) =>
      ((local.dx / size.width).clamp(0.0, 1.0).toDouble(), (local.dy / size.height).clamp(0.0, 1.0).toDouble());

  /// The pointer drawing or erasing right now; any other is ignored, so a
  /// second finger never draws a line across the board.
  int? _pointer;
  bool _pointerIsPen = false;
  bool _erasing = false;

  /// A pen (Apple Pencil, Android stylus, Surface pen) has touched this
  /// board: from then on fingers do not draw, so a palm resting on the
  /// screen while writing leaves no marks.
  bool _penSeen = false;

  static bool _isPen(PointerEvent e) =>
      e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus;

  /// The eraser end of a pen, a pen with its side button held, or the right
  /// mouse button.
  static bool _wantsEraser(PointerEvent e) =>
      e.kind == PointerDeviceKind.invertedStylus ||
      (e.kind == PointerDeviceKind.stylus && e.buttons & kSecondaryStylusButton != 0) ||
      (e.kind == PointerDeviceKind.mouse && e.buttons & kSecondaryMouseButton != 0);

  void _down(PointerDownEvent e, Size size) {
    final pen = _isPen(e);
    if (pen) {
      _penSeen = true;
      // A finger stroke under way when the pen lands was the palm.
      if (_pointer != null && !_pointerIsPen) {
        if (!_erasing) _change(_strokes.removeLast);
        _pointer = null;
      }
    } else if (_penSeen && e.kind == PointerDeviceKind.touch) {
      return;
    }
    if (_pointer != null) return;
    if (e.kind == PointerDeviceKind.mouse && e.buttons & (kPrimaryMouseButton | kSecondaryMouseButton) == 0) return;
    _pointer = e.pointer;
    _pointerIsPen = pen;
    _erasing = _wantsEraser(e);
    if (_erasing) {
      _erase(e.localPosition, size);
    } else {
      _change(() => _strokes.add([_point(e.localPosition, size)]));
    }
  }

  void _move(PointerMoveEvent e, Size size) {
    if (e.pointer != _pointer) return;
    if (_erasing) return _erase(e.localPosition, size);
    final last = _strokes.last.last;
    final previous = Offset(last.$1 * size.width, last.$2 * size.height);
    // Pens report far more often than the drawing can tell apart.
    if ((e.localPosition - previous).distance < 0.75) return;
    _change(() => _strokes.last.add(_point(e.localPosition, size)));
  }

  /// Ends the stroke; one without movement stays as a dot: the point of an
  /// "i", a decimal point.
  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _emit();
  }

  /// Removes every stroke that passes near [at].
  void _erase(Offset at, Size size) {
    final radius = math.max(12.0, size.height * 0.03);
    Offset px(InkPoint p) => Offset(p.$1 * size.width, p.$2 * size.height);
    bool hits(Stroke stroke) {
      for (var i = 0; i < stroke.length; i++) {
        final a = px(stroke[i]);
        final b = i + 1 < stroke.length ? px(stroke[i + 1]) : a;
        if (_distanceToSegment(at, a, b) <= radius) return true;
      }
      return false;
    }

    if (_strokes.any(hits)) _change(() => _strokes.removeWhere(hits));
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final length2 = ab.distanceSquared;
    if (length2 == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canEdit = widget.enabled && _strokes.isNotEmpty;
    // The board takes all the room it is given; undo and clear sit on it
    // rather than below it, so none of that room goes to a toolbar.
    return Center(
      child: AspectRatio(
        aspectRatio: _aspect,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Raw pointer events rather than a pan gesture: a stroke
                  // starts right where the pen lands (no drag slop eats the
                  // first millimetres), and the eager recognizer keeps a
                  // scrolling page around the board from taking the pen.
                  RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    gestures: {
                      if (widget.enabled)
                        EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                          EagerGestureRecognizer.new,
                          (_) {},
                        ),
                    },
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: !widget.enabled ? null : (e) => _down(e, size),
                      onPointerMove: !widget.enabled ? null : (e) => _move(e, size),
                      onPointerUp: !widget.enabled ? null : _up,
                      onPointerCancel: !widget.enabled ? null : _up,
                      child: SizedBox.fromSize(
                        size: size,
                        child: WhiteboardSurface(
                          background: widget.background,
                          backgroundImage: widget.backgroundImage,
                          ink: CustomPaint(
                            size: size,
                            painter: WhiteboardPainter(
                              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                              strokes: _strokes,
                              version: _version,
                              background: widget.backgroundImage == null && widget.background == 'image'
                                  ? 'blank'
                                  : widget.background,
                              listRows: widget.listRows,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.enabled)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(24),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: context.l10n.undo,
                              icon: const Icon(Icons.undo),
                              color: Colors.black87,
                              onPressed: canEdit
                                  ? () {
                                      _change(_strokes.removeLast);
                                      _emit();
                                    }
                                  : null,
                            ),
                            IconButton(
                              tooltip: context.l10n.clear,
                              icon: const Icon(Icons.delete_outline),
                              color: scheme.error,
                              onPressed: canEdit
                                  ? () {
                                      _change(_strokes.clear);
                                      _emit();
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
