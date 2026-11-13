import 'dart:io';

import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';

/// Put in order on the big screen: the entries mixed up, in the order the
/// teams' devices show them. With every reveal step the next entry, first
/// to last, slides into its place and shows what it is sorted by; the ones
/// still to come close up below.
///
/// Entries with pictures stand side by side, texts alone one above the other.
class OrderingBoard extends StatelessWidget {
  const OrderingBoard({super.key, required this.state, required this.question, required this.unit, required this.file});

  final SessionState state;
  final Question question;
  final double unit;

  /// The local copy of a media file of the game, when there is one.
  final File? Function(String? name) file;

  static const Duration _slide = Duration(milliseconds: 900);

  /// The entries' original indices in the order the devices show them.
  List<int> _shown() {
    final spec = question.companion;
    if (spec == null) return const [];
    return [
      for (final item in spec.toPublicMap(state.current?.key ?? '')['items'] as List? ?? const [])
        ((item as Map)['i'] as num).toInt(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = (question.ordering ?? const Ordering()).items;
    if (items.isEmpty) return const SizedBox();
    final shown = _shown();
    final placed = state.revealed.clamp(0, items.length);
    // Placed entries stand in their own place; the others follow in the
    // order they were shown.
    final waiting = [for (final index in shown) if (index >= placed) index];
    int slotOf(int index) => index < placed ? index : placed + waiting.indexOf(index);
    final pictures = items.any((item) => item.image != null);
    return LayoutBuilder(
      builder: (context, box) {
        final gap = unit * (pictures ? 1.2 : 0.8);
        final n = items.length;
        final Rect Function(int slot) rect;
        if (pictures) {
          final width = (box.maxWidth - gap * (n - 1)) / n;
          rect = (slot) => Rect.fromLTWH(slot * (width + gap), 0, width, box.maxHeight);
        } else {
          final height = ((box.maxHeight - gap * (n - 1)) / n).clamp(0.0, unit * 11).toDouble();
          final width = box.maxWidth.clamp(0.0, unit * 130).toDouble();
          final top = (box.maxHeight - (height * n + gap * (n - 1))) / 2;
          final left = (box.maxWidth - width) / 2;
          rect = (slot) => Rect.fromLTWH(left, top + slot * (height + gap), width, height);
        }
        // The entry going in place last moves over the others, not under them.
        final paintOrder = [for (var i = 0; i < n; i++) if (i != placed - 1) i, if (placed > 0) placed - 1];
        return Stack(
          children: [
            for (final index in paintOrder)
              AnimatedPositioned.fromRect(
                key: ValueKey(index),
                duration: _slide,
                curve: Curves.easeInOutCubic,
                rect: rect(slotOf(index)),
                child: _Lift(
                  placed: index < placed,
                  child: _Entry(
                  item: items[index],
                  place: index < placed ? index + 1 : null,
                  latest: index == placed - 1,
                  unit: unit,
                  file: file(items[index].image),
                  upright: pictures,
                ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Lifts an entry a little as it starts to move and sets it down again,
/// whenever [placed] changes; not when it first appears.
class _Lift extends StatefulWidget {
  const _Lift({required this.placed, required this.child});

  final bool placed;
  final Widget child;

  @override
  State<_Lift> createState() => _LiftState();
}

class _LiftState extends State<_Lift> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: OrderingBoard._slide, value: 1);

  @override
  void didUpdateWidget(_Lift old) {
    super.didUpdateWidget(old);
    if (old.placed != widget.placed) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final t = _controller.value;
      return Transform.scale(scale: 1 + 0.06 * (1 - (2 * t - 1) * (2 * t - 1)), child: child);
    },
    child: widget.child,
  );
}

/// One entry: its place once it is in it, picture, text and, in place,
/// what it is sorted by.
class _Entry extends StatelessWidget {
  const _Entry({
    required this.item,
    required this.place,
    required this.latest,
    required this.unit,
    required this.file,
    required this.upright,
  });

  final OrderItem item;

  /// From 1, once the entry is in its place.
  final int? place;

  /// The entry put in place last, which is lit up a little more.
  final bool latest;
  final double unit;
  final File? file;

  /// Picture above text (entries side by side) instead of in a row.
  final bool upright;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inPlace = place != null;
    final value = item.value.trim();
    return LayoutBuilder(
      builder: (context, box) {
        final size = upright ? box.maxWidth : box.maxHeight;
        final fontSize = upright ? (size * 0.11).clamp(unit * 1.8, unit * 3.4).toDouble() : (size * 0.38).clamp(unit * 1.8, unit * 4).toDouble();
        final badge = AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: fontSize * 1.9,
          height: fontSize * 1.9,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: inPlace ? scheme.primary : scheme.surfaceContainerHighest,
          ),
          child: Text(
            inPlace ? "$place" : "?",
            style: TextStyle(
              fontSize: fontSize * 0.95,
              fontWeight: FontWeight.w800,
              color: inPlace ? scheme.onPrimary : scheme.outline,
            ),
          ),
        );
        final text = item.text.trim().isEmpty
            ? null
            : Text(
                item.text,
                textAlign: upright ? TextAlign.center : TextAlign.start,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fontSize, height: 1.2, fontWeight: FontWeight.w600),
              );
        // What it is sorted by comes up once the entry is in its place.
        final shownValue = AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: Tween(begin: 0.6, end: 1.0).animate(animation), child: child),
          ),
          child: inPlace && value.isNotEmpty
              ? Container(
                  key: const ValueKey('value'),
                  padding: EdgeInsets.symmetric(horizontal: fontSize * 0.6, vertical: fontSize * 0.15),
                  decoration: BoxDecoration(color: scheme.tertiary, borderRadius: BorderRadius.circular(fontSize)),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: fontSize * 0.95, fontWeight: FontWeight.w800, color: scheme.onTertiary),
                  ),
                )
              : const SizedBox(key: ValueKey('none')),
        );
        Widget picture(double side) => SizedBox.square(
          dimension: side,
          child: file != null
              ? ClipRRect(borderRadius: BorderRadius.circular(unit * 1.2), child: Image.file(file!, fit: BoxFit.cover))
              : item.image != null
              ? Icon(Icons.image_outlined, size: side * 0.5, color: scheme.outline)
              : null,
        );
        final padding = unit * (upright ? 1 : 0.8);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: latest ? scheme.primaryContainer : (inPlace ? scheme.secondaryContainer : scheme.surfaceContainerHigh),
            borderRadius: BorderRadius.circular(unit * 2),
            border: Border.all(color: latest ? scheme.primary : Colors.transparent, width: unit * 0.3),
          ),
          child: upright
              ? LayoutBuilder(
                  builder: (context, inner) {
                    // Number, picture, text and value one above the other;
                    // the picture takes what is left, as a square.
                    final textHeight = text == null ? 0.0 : fontSize * 1.2 * 2 + unit * 0.6;
                    final valueHeight = value.isEmpty ? 0.0 : fontSize * 1.6 + unit * 0.6;
                    final side = (inner.maxHeight - fontSize * 1.9 - unit * 0.8 - textHeight - valueHeight)
                        .clamp(0.0, inner.maxWidth)
                        .toDouble();
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        badge,
                        SizedBox(height: unit * 0.8),
                        picture(side),
                        if (text != null)
                          SizedBox(
                            height: textHeight,
                            child: Padding(padding: EdgeInsets.only(top: unit * 0.6), child: Center(child: text)),
                          ),
                        if (value.isNotEmpty)
                          SizedBox(
                            height: valueHeight,
                            child: Padding(padding: EdgeInsets.only(top: unit * 0.6), child: Center(child: shownValue)),
                          ),
                      ],
                    );
                  },
                )
              : Row(
                  children: [
                    badge,
                    SizedBox(width: unit * 1.5),
                    Expanded(child: text ?? const SizedBox()),
                    SizedBox(width: unit),
                    shownValue,
                  ],
                ),
        );
      },
    );
  }
}
