import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:quiz_show/features/session/pages/video_card.dart';
import 'package:quiz_show/game/game.dart';

/// What a question or an item shows in its picture box on the big screen:
/// its clip while it has one, otherwise its pictures, several side by side.
/// The same for questions, Fragenhagel and last-team-standing items.
class MediaBox extends StatelessWidget {
  const MediaBox({
    super.key,
    required this.images,
    required this.unit,
    this.videoName,
    this.video,
    this.playback = MediaPlayback.stopped,
    this.onVideoEnd,
    this.shown,
    this.alignment = Alignment.center,
  });

  /// Where a single picture or the clip sits when the box has another
  /// shape: left when the question's text is beside it.
  final Alignment alignment;

  /// Pictures one after another: the index of the one on screen; null
  /// shows them all side by side.
  final int? shown;

  /// The pictures there are on this device, in order.
  final List<File> images;
  final double unit;

  /// The clip's name, and its local file once it is there.
  final String? videoName;
  final File? video;
  final MediaPlayback playback;

  /// Set only on the screen that plays clips; the others show a placeholder.
  final VoidCallback? onVideoEnd;

  static final Map<String, GlobalKey> _videoKeys = {};

  /// The same, with a single picture or the clip at [alignment].
  MediaBox aligned(Alignment alignment) => MediaBox(
    key: key,
    images: images,
    unit: unit,
    videoName: videoName,
    video: video,
    playback: playback,
    onVideoEnd: onVideoEnd,
    shown: shown,
    alignment: alignment,
  );

  bool get isEmpty => videoName == null && images.isEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(unit * 2);
    if (videoName != null) {
      return ClipRRect(
        borderRadius: radius,
        child: video != null && onVideoEnd != null
            ? QuestionVideo(
                // One key per clip: going fullscreen and back moves the
                // player along, without starting the clip over.
                key: _videoKeys.putIfAbsent(video!.path, GlobalKey.new),
                file: video!,
                playback: playback,
                onFinished: onVideoEnd!,
                alignment: alignment,
              )
            : ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Center(
                  child: Icon(
                    playback == MediaPlayback.playing ? Icons.play_circle_outline : Icons.movie_outlined,
                    size: unit * 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
      );
    }
    // Each picture as large as its room allows, small ones blown up too.
    Widget picture(File file, {Alignment alignment = Alignment.center}) => SizedBox.expand(
      child: FittedBox(
        alignment: alignment,
        child: ClipRRect(borderRadius: radius, child: Image.file(file, gaplessPlayback: true)),
      ),
    );
    if (images.length == 1) return picture(images.single, alignment: alignment);
    if (shown case final index?) {
      final at = index.clamp(0, images.length - 1);
      return Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(key: ValueKey(at), child: Center(child: picture(images[at]))),
            ),
          ),
          SizedBox(height: unit),
          // Where in the row of pictures this one is.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < images.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(horizontal: unit * 0.4),
                  width: i == at ? unit * 2.4 : unit,
                  height: unit,
                  decoration: BoxDecoration(
                    color: i == at ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(unit),
                  ),
                ),
            ],
          ),
        ],
      );
    }
    // Up to three in a row, more in a grid about as wide as it is tall.
    final columns = images.length <= 3 ? images.length : math.sqrt(images.length).ceil();
    final rows = (images.length / columns).ceil();
    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = row * columns; i < math.min(images.length, (row + 1) * columns); i++)
                  Expanded(child: Padding(padding: EdgeInsets.all(unit * 0.5), child: picture(images[i]))),
              ],
            ),
          ),
      ],
    );
  }
}
