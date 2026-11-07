import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/session/boards/map_board.dart';
import 'package:quiz_show/game/game.dart';

/// Arranges a map board by hand: drag the bubbles, connect them, and add
/// titles, pictures and lines around them.
///
/// It shows the board exactly as the presenter will, on a 16:9 stage, with
/// handles on top. Everything is kept in fractions of the stage, so the
/// result fits any screen. [onSave] receives the whole `mapLayout`.
class MapEditor extends StatefulWidget {
  const MapEditor({
    super.key,
    required this.group,
    required this.onSave,
    required this.imageFile,
    this.pickImage,
  });

  final CategoryGroup group;
  final void Function(Map<String, dynamic> layout) onSave;
  final File? Function(String name) imageFile;

  /// Lets the user choose and upload a picture; returns its media name.
  /// The picture tool is hidden when this is null.
  final Future<String?> Function()? pickImage;

  @override
  State<MapEditor> createState() => _MapEditorState();
}

class _MapEditorState extends State<MapEditor> {
  /// The layout being edited; saved after every completed change.
  late Map<String, dynamic> _layout = _copy(widget.group.data['mapLayout']);

  /// Index into the decorations, or null.
  int? _selected;

  /// The bubble picked for resizing, or null.
  String? _bubble;

  /// Scrolls the stage when the canvas is wider than one screen. Moved with
  /// the slider below it, so that dragging on the stage always moves things.
  final ScrollController _scroll = ScrollController();

  /// While something is held against the left or right edge of the stage,
  /// the stage scrolls that way and the thing travels with it.
  Timer? _edgeScroll;
  final GlobalKey _stageKey = GlobalKey();

  void _dragNearEdge(Offset pointer, double canvasWidth, void Function(double dx, double dy) move) {
    final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_scroll.hasClients) return;
    final x = box.globalToLocal(pointer).dx;
    const margin = 48.0;
    final direction = x < margin ? -1 : (x > box.size.width - margin ? 1 : 0);
    if (direction == 0) {
      _edgeScroll?.cancel();
      _edgeScroll = null;
      return;
    }
    _edgeScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || !_scroll.hasClients) return;
      final before = _scroll.offset;
      final after = (before + direction * 14).clamp(0.0, _scroll.position.maxScrollExtent).toDouble();
      if (after == before) return;
      _scroll.jumpTo(after);
      // Keep it under the finger: it moves on the canvas by what scrolled.
      setState(() => move((after - before) / canvasWidth, 0));
    });
  }

  void _stopEdgeScroll() {
    _edgeScroll?.cancel();
    _edgeScroll = null;
  }

  @override
  void dispose() {
    _edgeScroll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Connecting: the bubble the next tap will be drawn after.
  bool _connecting = false;
  String? _from;

  static Map<String, dynamic> _copy(Object? stored) {
    final map = stored is Map ? stored : const {};
    return {
      if (map['width'] is num) 'width': map['width'],
      'follows': Map<String, dynamic>.from(map['follows'] as Map? ?? const {}),
      'nodes': {
        for (final entry in (map['nodes'] as Map? ?? const {}).entries)
          entry.key as String: Map<String, dynamic>.from(entry.value as Map),
      },
      'decorations': [
        for (final entry in map['decorations'] as List? ?? const [])
          if (entry is Map) Map<String, dynamic>.from(entry),
      ],
    };
  }

  @override
  void didUpdateWidget(MapEditor old) {
    super.didUpdateWidget(old);
    // Categories may come and go while this is open; our own saves come back
    // unchanged, so taking the stored layout over is safe either way.
    if (old.group.data['mapLayout'] != widget.group.data['mapLayout'] && !_dragging) {
      _layout = _copy(widget.group.data['mapLayout']);
      if (_selected != null && _selected! >= _decorations.length) _selected = null;
    }
  }

  bool _dragging = false;

  List<Map<String, dynamic>> get _decorations => (_layout['decorations'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> get _nodes => _layout['nodes'] as Map<String, dynamic>;

  Map<String, dynamic> get _follows => _layout['follows'] as Map<String, dynamic>;

  /// The group as it would be with the layout being edited.
  CategoryGroup get _draft => CategoryGroup(
        id: widget.group.id,
        name: widget.group.name,
        type: widget.group.type,
        index: widget.group.index,
        color: widget.group.color,
        accentColor: widget.group.accentColor,
        categories: widget.group.categories,
        sounds: widget.group.sounds,
        data: {...widget.group.data, 'mapLayout': _layout},
      );

  void _save() => widget.onSave(_copy(_layout));

  void _change(VoidCallback change) {
    setState(change);
    _save();
  }

  static double _unit(double v) => v.clamp(0.0, 1.0).toDouble();

  // ── tools ──────────────────────────────────────────────────────────────────

  Future<void> _addTitle() async {
    final text = await promptText(context, title: "Add title", label: "Text");
    if (text == null) return;
    _change(() {
      _decorations.add({'type': 'title', 'text': text, 'x': 0.5, 'y': 0.08, 'size': 1.4});
      _selected = _decorations.length - 1;
    });
  }

  Future<void> _addImage() async {
    final name = await widget.pickImage!();
    if (name == null || !mounted) return;
    _change(() {
      _decorations.add({'type': 'image', 'image': name, 'x': 0.5, 'y': 0.5, 'width': 0.2});
      _selected = _decorations.length - 1;
    });
  }

  void _addLine() => _change(() {
        _decorations.add({'type': 'line', 'x1': 0.35, 'y1': 0.92, 'x2': 0.65, 'y2': 0.92});
        _selected = _decorations.length - 1;
      });

  Future<void> _editSelectedText() async {
    final decoration = _decorations[_selected!];
    final text = await promptText(context, title: "Edit title", initial: decoration['text'] as String, label: "Text");
    if (text != null) _change(() => decoration['text'] = text);
  }

  void _resize(double factor) => _change(() {
        final bubble = _bubble;
        if (bubble != null) {
          final node = _nodes.putIfAbsent(bubble, () => <String, dynamic>{}) as Map<String, dynamic>;
          node['scale'] = (((node['scale'] as num?) ?? 1) * factor).clamp(kMapMinScale, kMapMaxScale);
          return;
        }
        final decoration = _decorations[_selected!];
        if (decoration['type'] == 'title') {
          decoration['size'] = (((decoration['size'] as num?) ?? 1) * factor).clamp(0.5, 5.0);
        } else if (decoration['type'] == 'image') {
          decoration['width'] = (((decoration['width'] as num?) ?? 0.2) * factor).clamp(0.04, 1.0);
        }
      });

  /// Makes the canvas [by] screens wider or narrower.
  void _widen(double by) => _change(() {
        final current = layoutMap(_draft).widthFactor;
        _layout['width'] = (current + by).clamp(1.0, kMapMaxWidth);
      });

  void _tapBubble(String categoryId) {
    if (!_connecting) {
      // Picked for resizing.
      setState(() {
        _bubble = _bubble == categoryId ? null : categoryId;
        _selected = null;
      });
      return;
    }
    final from = _from;
    if (from == null) {
      setState(() => _from = categoryId);
    } else if (from == categoryId) {
      // Tapped twice: this bubble follows nothing, it starts a chain.
      _change(() {
        _follows[categoryId] = '';
        _from = null;
      });
    } else {
      _change(() {
        _follows[categoryId] = from;
        _from = null;
      });
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _selected == null ? null : _decorations[_selected!];
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // One screen of a canvas that may be wider; the slider
                        // below moves the window, the stage itself only drags
                        // what is on it.
                        final canvas = Size(box.maxWidth * layoutMap(_draft).widthFactor, box.maxHeight);
                        // The slider can only work out how far there is to go
                        // once the stage is laid out; it is told when that
                        // changes, also on the very first frame.
                        return NotificationListener<ScrollMetricsNotification>(
                          onNotification: (_) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() {});
                            });
                            return false;
                          },
                          child: SingleChildScrollView(
                            key: _stageKey,
                            controller: _scroll,
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            child: SizedBox.fromSize(size: canvas, child: _stage(canvas, box.maxWidth, scheme)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (layoutMap(_draft).widthFactor > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListenableBuilder(
              listenable: _scroll,
              builder: (context, _) {
                final most = _scroll.hasClients && _scroll.position.hasContentDimensions ? _scroll.position.maxScrollExtent : 0.0;
                return Row(
                  children: [
                    const Icon(Icons.swap_horiz, size: 18),
                    Expanded(
                      child: Slider(
                        value: most <= 0 ? 0 : (_scroll.offset / most).clamp(0.0, 1.0).toDouble(),
                        onChanged: most <= 0 ? null : (value) => _scroll.jumpTo(value * most),
                      ),
                    ),
                    Text("${formatNumber(layoutMap(_draft).widthFactor)} screens wide", style: theme.textTheme.bodySmall),
                  ],
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            _connecting
                ? (_from == null
                    ? "Tap the bubble that comes first."
                    : "Now tap the bubble that comes after it. Tap the same one again to make it a start.")
                : _bubble != null
                    ? "Drag to move. Use − and + below to change this bubble's size."
                    : selected != null
                        ? "Drag to move. Use the buttons below to change or remove it."
                        : "Drag things to place them. Tap a bubble, title, picture or line to select it.",
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        // The tools keep their places; the second row only acts on a selection.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                avatar: const Icon(Icons.timeline, size: 18),
                label: const Text("Connect"),
                selected: _connecting,
                onSelected: (on) => setState(() {
                  _connecting = on;
                  _from = null;
                  _selected = null;
                  _bubble = null;
                }),
              ),
              ActionChip(avatar: const Icon(Icons.title, size: 18), label: const Text("Title"), onPressed: _addTitle),
              if (widget.pickImage != null)
                ActionChip(avatar: const Icon(Icons.image_outlined, size: 18), label: const Text("Picture"), onPressed: _addImage),
              ActionChip(avatar: const Icon(Icons.horizontal_rule, size: 18), label: const Text("Line"), onPressed: _addLine),
              ActionChip(
                avatar: const Icon(Icons.unfold_less, size: 18),
                label: const Text("Narrower"),
                onPressed: layoutMap(_draft).widthFactor <= 1 ? null : () => _widen(-0.5),
              ),
              ActionChip(
                avatar: const Icon(Icons.unfold_more, size: 18),
                label: const Text("Wider"),
                onPressed: layoutMap(_draft).widthFactor >= kMapMaxWidth ? null : () => _widen(0.5),
              ),
              ActionChip(
                avatar: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text("Tidy up"),
                // Positions go back to automatic; sizes are kept.
                onPressed: _nodes.values.every((node) => (node as Map)['x'] == null)
                    ? null
                    : () => _change(() {
                          for (final node in _nodes.values) {
                            (node as Map)
                              ..remove('x')
                              ..remove('y');
                          }
                          _nodes.removeWhere((_, node) => (node as Map).isEmpty);
                        }),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: "Smaller",
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _bubble == null && (selected == null || selected['type'] == 'line') ? null : () => _resize(1 / 1.15),
              ),
              IconButton(
                tooltip: "Larger",
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _bubble == null && (selected == null || selected['type'] == 'line') ? null : () => _resize(1.15),
              ),
              IconButton(
                tooltip: "Edit text",
                icon: const Icon(Icons.edit_outlined),
                onPressed: selected?['type'] == 'title' ? _editSelectedText : null,
              ),
              IconButton(
                tooltip: "Remove",
                icon: const Icon(Icons.delete_outline),
                onPressed: selected == null
                    ? null
                    : () => _change(() {
                          _decorations.removeAt(_selected!);
                          _selected = null;
                        }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stage(Size size, double viewportWidth, ColorScheme scheme) {
    final draft = _draft;
    final map = layoutMap(draft);
    // Same sizing as the canvas itself, to put each handle over its bubble.
    final bubbleWidth = MapCanvas.bubbleWidth(map, size, viewportWidth);

    Widget handle({
      required Key key,
      required double x,
      required double y,
      required double width,
      required double height,
      required void Function(double dx, double dy) onMove,
      VoidCallback? onTap,
      bool outlined = false,
      bool round = false,
    }) =>
        Positioned(
          key: key,
          left: x * size.width - width / 2,
          top: y * size.height - height / 2,
          width: width,
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onPanStart: (_) => _dragging = true,
            onPanUpdate: (d) {
              setState(() => onMove(d.delta.dx / size.width, d.delta.dy / size.height));
              _dragNearEdge(d.globalPosition, size.width, onMove);
            },
            onPanEnd: (_) {
              _dragging = false;
              _stopEdgeScroll();
              _save();
            },
            onPanCancel: () {
              _dragging = false;
              _stopEdgeScroll();
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: round ? BoxShape.circle : BoxShape.rectangle,
                color: round ? scheme.primary : null,
                borderRadius: round ? null : BorderRadius.circular(10),
                border: outlined ? Border.all(color: scheme.primary, width: 2) : null,
              ),
            ),
          ),
        );

    // A title's handle is as large as the text MapBoard draws, plus a margin
    // to grab it by.
    Size titleSize(Map<String, dynamic> decoration) {
      final painter = TextPainter(
        text: TextSpan(
          text: decoration['text'] as String,
          style: TextStyle(
            fontSize: bubbleWidth / 13 * 1.5 * ((decoration['size'] as num?) ?? 1),
            fontWeight: FontWeight.w700,
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      return Size(painter.width + 20, painter.height + 12);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: MapCanvas(
              group: draft,
              state: const SessionState(),
              imageFile: widget.imageFile,
              viewportWidth: viewportWidth,
            ),
          ),
        ),
        // Tapping empty space lets go of the selection.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(() {
              _selected = null;
              _bubble = null;
            }),
          ),
        ),
        for (final category in widget.group.categories)
          handle(
            key: ValueKey('bubble-${category.id}'),
            x: map.nodes[category.id]!.x,
            y: map.nodes[category.id]!.y,
            width: bubbleWidth * map.scaleOf(category.id),
            height: bubbleWidth * 0.62,
            outlined: _from == category.id || _bubble == category.id,
            onTap: () => _tapBubble(category.id),
            onMove: (dx, dy) {
              final at = map.nodes[category.id]!;
              final node = _nodes.putIfAbsent(category.id, () => <String, dynamic>{}) as Map<String, dynamic>;
              // A bubble that only had a size so far starts from where the
              // automatic layout put it.
              node['x'] = _unit(((node['x'] as num?) ?? at.x) + dx);
              node['y'] = _unit(((node['y'] as num?) ?? at.y) + dy);
            },
          ),
        for (final (i, decoration) in _decorations.indexed)
          if (decoration['type'] == 'line') ...[
            // A line is moved by its two ends.
            for (final end in const ['1', '2'])
              handle(
                key: ValueKey('line-$i-$end'),
                x: (decoration['x$end'] as num).toDouble(),
                y: (decoration['y$end'] as num).toDouble(),
                width: _selected == i ? 22 : 30,
                height: _selected == i ? 22 : 30,
                round: _selected == i,
                onTap: () => setState(() {
                  _selected = i;
                  _bubble = null;
                }),
                onMove: (dx, dy) {
                  _selected = i;
                  decoration['x$end'] = _unit((decoration['x$end'] as num) + dx);
                  decoration['y$end'] = _unit((decoration['y$end'] as num) + dy);
                },
              ),
          ] else
            handle(
              key: ValueKey('decoration-$i'),
              x: (decoration['x'] as num).toDouble(),
              y: (decoration['y'] as num).toDouble(),
              width: decoration['type'] == 'image'
                  ? ((decoration['width'] as num?) ?? 0.2) * size.width
                  : titleSize(decoration).width,
              height: decoration['type'] == 'image'
                  ? ((decoration['width'] as num?) ?? 0.2) * size.width * 0.7
                  : titleSize(decoration).height,
              outlined: _selected == i,
              onTap: () => setState(() {
                  _selected = i;
                  _bubble = null;
                }),
              onMove: (dx, dy) {
                _selected = i;
                decoration['x'] = _unit((decoration['x'] as num) + dx);
                decoration['y'] = _unit((decoration['y'] as num) + dy);
              },
            ),
      ],
    );
  }
}
