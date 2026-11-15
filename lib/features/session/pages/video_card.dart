import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:quiz_show/game/game.dart';

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

/// A question's clip in its picture box, played, paused and stopped as
/// [playback] says, the way the question's sound is. Starts on its first
/// frame, and goes back there when stopped. [onFinished] when it ran out.
class QuestionVideo extends StatefulWidget {
  const QuestionVideo({super.key, required this.file, required this.playback, required this.onFinished});

  final File file;
  final MediaPlayback playback;
  final VoidCallback onFinished;

  @override
  State<QuestionVideo> createState() => _QuestionVideoState();
}

class _QuestionVideoState extends State<QuestionVideo> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  StreamSubscription<bool>? _completed;

  @override
  void initState() {
    super.initState();
    _completed = _player.stream.completed.listen((done) {
      if (done && mounted && widget.playback == MediaPlayback.playing) widget.onFinished();
    });
    _player.open(Media(widget.file.uri.toString()), play: widget.playback == MediaPlayback.playing);
  }

  @override
  void didUpdateWidget(QuestionVideo old) {
    super.didUpdateWidget(old);
    if (old.playback == widget.playback) return;
    switch (widget.playback) {
      case MediaPlayback.playing:
        _player.play();
      case MediaPlayback.paused:
        _player.pause();
      case MediaPlayback.stopped:
        _player.pause();
        _player.seek(Duration.zero);
    }
  }

  @override
  void dispose() {
    _completed?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Video(controller: _controller, controls: NoVideoControls, fill: Colors.transparent);
}
