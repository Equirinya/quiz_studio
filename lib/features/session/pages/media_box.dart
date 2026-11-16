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
  });

  /// The pictures there are on this device, in order.
  final List<File> images;
  final double unit;

  /// The clip's name, and its local file once it is there.
  final String? videoName;
  final File? video;
  final MediaPlayback playback;

  /// Set only on the screen that plays clips; the others show a placeholder.
  final VoidCallback? onVideoEnd;

  bool get isEmpty => videoName == null && images.isEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(unit * 2);
    if (videoName != null) {
      return ClipRRect(
        borderRadius: radius,
        child: video != null && onVideoEnd != null
            ? QuestionVideo(key: ValueKey(video!.path), file: video!, playback: playback, onFinished: onVideoEnd!)
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
    Widget picture(File file) => FittedBox(child: ClipRRect(borderRadius: radius, child: Image.file(file, gaplessPlayback: true)));
    if (images.length == 1) return picture(images.single);
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
