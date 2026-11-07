import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Plays one video file once, full size and without controls, and reports
/// when it has reached its end.
class VideoCard extends StatefulWidget {
  const VideoCard({super.key, required this.file, required this.onFinished});

  final File file;
  final VoidCallback onFinished;

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  StreamSubscription<bool>? _completed;

  @override
  void initState() {
    super.initState();
    _completed = _player.stream.completed.listen((done) {
      if (done && mounted) widget.onFinished();
    });
    _player.open(Media(widget.file.uri.toString()));
  }

  @override
  void dispose() {
    _completed?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Video(controller: _controller, controls: NoVideoControls);
}
