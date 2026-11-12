import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "Match pairs" on a team's device: every left-hand item has a slot, and the
/// right-hand items wait in a tray until they are dragged onto one.
///
/// - Drop on an empty slot: placed. Drop on a filled one: the two swap (the
///   other goes back where the dragged one came from). Drop on the tray: back.
/// - Tapping works too: tap an answer, then its slot. Tapping a placed answer
///   picks it up again, to move it or tap the tray to put it back.
/// - With many pairs the slots scroll, also by themselves while dragging near
///   their top or bottom edge. The tray sits under the slots on an upright
///   phone and beside them when there is room (tablets, phones held sideways).
class MatchInput extends StatefulWidget {
  const MatchInput({
    super.key,
    required this.left,
    required this.right,
    required this.onChanged,
    this.enabled = true,
    this.leftImages = const [],
    this.rightImages = const {},
  });

  /// A picture per left-hand item, where it has one and it has arrived.
  final List<ImageProvider?> leftImages;

  /// Pictures of right-hand items, by their original index.
  final Map<int, ImageProvider> rightImages;

  /// The left-hand items, in their order.
  final List<String> left;

  /// The right-hand items as shown (already shuffled): original index and text.
  final List<(int, String)> right;

  final bool enabled;

  /// For each left-hand item, the original index of the right-hand item put
  /// there, or -1.
  final ValueChanged<List<int>> onChanged;

  @override
  State<MatchInput> createState() => _MatchInputState();
}

class _MatchInputState extends State<MatchInput> {
  late final List<int> _pairs = List.filled(widget.left.length, -1);

  /// The answer picked up by a tap, waiting for a tap on its slot.
  int? _selected;

  /// The answer being dragged; its place shows a faint ghost meanwhile.
  int? _dragging;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _slotsKey = GlobalKey();
  Timer? _autoScroll;
  double _slotWidth = 180;
  double _scrollSpeed = 0;

  @override
  void dispose() {
    _autoScroll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  String _text(int item) => widget.right.firstWhere((entry) => entry.$1 == item, orElse: () => (item, '?')).$2;

  List<int> get _tray => [
    for (final (item, _) in widget.right)
      if (!_pairs.contains(item)) item,
  ];

  /// Puts [item] into [slot], or back into the tray when [slot] is null.
  void _place(int item, int? slot) {
    final from = _pairs.indexOf(item);
    if (from == slot || (slot == null && from < 0)) {
      setState(() => _selected = null);
      return;
    }
    setState(() {
      if (slot == null) {
        _pairs[from] = -1;
      } else {
        final previous = _pairs[slot];
        if (from >= 0) _pairs[from] = previous;
        _pairs[slot] = item;
      }
      _selected = null;
    });
    HapticFeedback.selectionClick();
    widget.onChanged(List.of(_pairs));
  }

  void _tapSlot(int slot) {
    final selected = _selected;
    if (selected != null) {
      _place(selected, slot);
    } else if (_pairs[slot] >= 0) {
      setState(() => _selected = _pairs[slot]);
      HapticFeedback.selectionClick();
    }
  }

  void _tapTrayItem(int item) {
    setState(() => _selected = _selected == item ? null : item);
    HapticFeedback.selectionClick();
  }

  void _dragStarted(int item) {
    setState(() {
      _dragging = item;
      _selected = null;
    });
    HapticFeedback.lightImpact();
  }

  void _dragEnded() {
    _autoScroll?.cancel();
    _autoScroll = null;
    if (mounted) setState(() => _dragging = null);
  }

  /// Scrolls the slots while an answer is held near their top or bottom edge.
  void _dragMoved(DragUpdateDetails details) {
    final box = _slotsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !_scroll.hasClients) return;
    final local = box.globalToLocal(details.globalPosition);
    final height = box.size.height;
    const edge = 64.0;
    var speed = 0.0;
    if (local.dx >= 0 && local.dx <= box.size.width) {
      if (local.dy < edge && local.dy > -edge) speed = -(edge - local.dy) / edge * 14;
      if (local.dy > height - edge && local.dy < height + edge * 0.5) speed = (local.dy - (height - edge)) / edge * 14;
    }
    _scrollSpeed = speed.clamp(-20, 20);
    if (_scrollSpeed == 0) {
      _autoScroll?.cancel();
      _autoScroll = null;
      return;
    }
    _autoScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      final target = (position.pixels + _scrollSpeed).clamp(position.minScrollExtent, position.maxScrollExtent);
      if (target != position.pixels) _scroll.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 600 || box.maxWidth > box.maxHeight * 1.2;
        final placed = _pairs.where((p) => p >= 0).length;
        final selected = _selected;
        final hint = !widget.enabled
            ? "Your pairs"
            : selected != null
            ? "Now tap where “${_text(selected)}” goes"
            : placed == widget.left.length
            ? "All placed · drag to swap"
            : "Drag each answer onto its partner";
        final header = Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                  child: Text(
                    hint,
                    key: ValueKey(hint),
                    style: theme.textTheme.bodyMedium?.copyWith(color: selected != null ? theme.colorScheme.primary : null),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Text(
                "$placed / ${widget.left.length}",
                style: theme.textTheme.labelLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        );
        // Smaller rows for many pairs on an upright phone, and on any short
        // screen (a phone held sideways), so more than two fit.
        final many = widget.left.length > 6;
        final slots = _slots(context, compact: many && (!wide || box.maxHeight < 520));
        final showTray = widget.enabled && (_tray.isNotEmpty || _dragging != null || _selected != null);
        if (wide) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              header,
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: slots),
                    if (widget.enabled) ...[
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _trayArea(context, maxHeight: box.maxHeight)),
                    ],
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            Flexible(child: slots),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: showTray
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _trayArea(context, maxHeight: box.maxHeight * 0.42),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        );
      },
    );
  }

  Widget _slots(BuildContext context, {required bool compact}) {
    return LayoutBuilder(
      builder: (context, box) {
        // Two halves with the arrow between: what a dragged answer is as wide as.
        _slotWidth = (box.maxWidth - 26) / 2;
        return Scrollbar(
          controller: _scroll,
          child: ListView.separated(
            key: _slotsKey,
            controller: _scroll,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: widget.left.length,
            separatorBuilder: (_, _) => SizedBox(height: compact ? 6 : 10),
            itemBuilder: (context, i) => _row(context, i, compact: compact),
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, int slot, {required bool compact}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textStyle = (compact ? theme.textTheme.bodyLarge : theme.textTheme.titleMedium);
    final minHeight = compact ? 48.0 : 56.0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(minHeight: minHeight),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  if (widget.leftImages.elementAtOrNull(slot) case final image?) ...[
                    _Thumb(image: image, size: minHeight - 8, zoomable: true),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      widget.left[slot],
                      style: textStyle?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward_rounded, size: 18, color: scheme.outline),
          ),
          Expanded(
            child: _slot(context, slot, minHeight: minHeight, textStyle: textStyle),
          ),
        ],
      ),
    );
  }

  Widget _slot(BuildContext context, int slot, {required double minHeight, TextStyle? textStyle}) {
    final scheme = Theme.of(context).colorScheme;
    final item = _pairs[slot];
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => widget.enabled && details.data != item,
      onAcceptWithDetails: (details) => _place(details.data, slot),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        final waiting = _selected != null && _selected != item;
        // An empty slot; also what stays behind while its answer is dragged.
        Widget empty({String? ghost}) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? () => _tapSlot(slot) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            constraints: BoxConstraints(minHeight: minHeight),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: hovering
                  ? scheme.primary.withValues(alpha: 0.14)
                  : waiting
                  ? scheme.primary.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hovering || waiting ? scheme.primary : scheme.outlineVariant, width: hovering ? 2.5 : 1.5),
            ),
            child: ghost != null
                ? Opacity(
                    opacity: 0.3,
                    child: Text(ghost, style: textStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  )
                : Icon(Icons.add_rounded, color: hovering || waiting ? scheme.primary : scheme.outlineVariant),
          ),
        );
        if (item < 0) return empty();
        final chip = _Chip(
          text: _text(item),
          image: widget.rightImages[item],
          style: textStyle,
          minHeight: minHeight,
          placed: true,
          selected: _selected == item,
          highlighted: hovering,
          locked: !widget.enabled,
          expand: true,
        );
        if (!widget.enabled) return chip;
        return LongPressDraggable<int>(
          data: item,
          // Short, so it feels like picking it up, but a swipe still scrolls.
          delay: const Duration(milliseconds: 140),
          hapticFeedbackOnStart: false,
          onDragStarted: () => _dragStarted(item),
          onDragUpdate: _dragMoved,
          onDragEnd: (_) => _dragEnded(),
          onDraggableCanceled: (_, _) => _dragEnded(),
          feedback: _feedback(context, item, _slotWidth, textStyle),
          // Kept in the tree (not swapped out) while dragging, or the
          // drag would lose its end callbacks.
          childWhenDragging: empty(ghost: _text(item)),
          child: GestureDetector(onTap: () => _tapSlot(slot), child: chip),
        );
      },
    );
  }

  Widget _trayArea(BuildContext context, {required double maxHeight}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tray = _tray;
    final style = widget.left.length > 6 ? theme.textTheme.bodyLarge : theme.textTheme.titleMedium;
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => _pairs.contains(details.data),
      onAcceptWithDetails: (details) => _place(details.data, null),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        final returning = _selected != null && _pairs.contains(_selected);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: returning ? () => _place(_selected!, null) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: maxHeight, minHeight: 64),
            decoration: BoxDecoration(
              color: hovering ? scheme.primary.withValues(alpha: 0.10) : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: hovering || returning ? scheme.primary : scheme.outlineVariant, width: hovering ? 2 : 1),
            ),
            child: tray.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        returning || _dragging != null ? "Drop here to take it back" : "All placed",
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(10),
                    child: LayoutBuilder(
                      builder: (context, box) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in tray)
                            ConstrainedBox(
                              key: ValueKey(item),
                              constraints: BoxConstraints(maxWidth: box.maxWidth),
                              child: Draggable<int>(
                                data: item,
                                onDragStarted: () => _dragStarted(item),
                                onDragUpdate: _dragMoved,
                                onDragEnd: (_) => _dragEnded(),
                                onDraggableCanceled: (_, _) => _dragEnded(),
                                feedback: _feedback(context, item, box.maxWidth, style),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: _Chip(text: _text(item), image: widget.rightImages[item], style: style, minHeight: 44, placed: false),
                                ),
                                child: GestureDetector(
                                  onTap: () => _tapTrayItem(item),
                                  child: _Chip(text: _text(item), image: widget.rightImages[item], style: style, minHeight: 44, placed: false, selected: _selected == item),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  /// What follows the finger: the answer, lifted a little.
  Widget _feedback(BuildContext context, int item, double maxWidth, TextStyle? style) {
    final theme = Theme.of(context);
    return Theme(
      data: theme,
      child: Transform.scale(
        scale: 1.06,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth.isFinite ? maxWidth : 280),
          child: Material(
            color: Colors.transparent,
            elevation: 8,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(12),
            child: _Chip(text: _text(item), image: widget.rightImages[item], style: style, minHeight: 44, placed: true),
          ),
        ),
      ),
    );
  }
}

/// One right-hand answer, in the tray or in a slot.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.style,
    required this.minHeight,
    required this.placed,
    this.selected = false,
    this.highlighted = false,
    this.locked = false,
    this.expand = false,
    this.image,
  });

  final String text;
  final ImageProvider? image;
  final TextStyle? style;
  final double minHeight;
  final bool placed;
  final bool selected;
  final bool highlighted;
  final bool locked;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = selected
        ? scheme.primary
        : placed
        ? scheme.primaryContainer
        : scheme.secondaryContainer;
    final foreground = selected
        ? scheme.onPrimary
        : placed
        ? scheme.onPrimaryContainer
        : scheme.onSecondaryContainer;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlighted ? scheme.primary : Colors.transparent, width: 2.5),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (!locked && !placed) ...[
            Icon(Icons.drag_indicator_rounded, size: 18, color: foreground.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
          ],
          if (image != null) ...[_Thumb(image: image!, size: 36), const SizedBox(width: 8)],
          Flexible(
            child: Text(
              text,
              style: style?.copyWith(color: foreground),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (locked) ...[const SizedBox(width: 6), Icon(Icons.lock, size: 16, color: foreground.withValues(alpha: 0.7))],
        ],
      ),
    );
  }
}

/// A matching picture, small. Where [zoomable], a tap shows it large.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.image, required this.size, this.zoomable = false});

  final ImageProvider image;
  final double size;
  final bool zoomable;

  @override
  Widget build(BuildContext context) {
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image(image: image, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
    );
    if (!zoomable) return thumb;
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer(child: Image(image: image, fit: BoxFit.contain)),
          ),
        ),
      ),
      child: thumb,
    );
  }
}
