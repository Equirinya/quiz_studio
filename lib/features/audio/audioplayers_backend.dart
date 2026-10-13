import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'package:quiz_show/features/audio/audio_director.dart';
import 'package:quiz_show/game/game.dart';

/// [AudioBackend] on top of the audioplayers plugin.
class AudioplayersBackend implements AudioBackend {
  AudioplayersBackend() {
    _mediaDone = _media.onPlayerComplete.listen((_) => _completed.add(null));
  }

  AudioPlayer? _music;
  final AudioPlayer _media = AudioPlayer();
  String? _mediaPath;
  late final StreamSubscription<void> _mediaDone;
  final StreamController<void> _completed = StreamController<void>.broadcast();
  bool _disposed = false;

  @override
  Stream<void> get mediaCompleted => _completed.stream;

  void _guard(Future<void> Function() action) {
    action().catchError((Object error) {
      if (kDebugMode) print('Audio: $error');
    });
  }

  @override
  void setMusic(String? path) {
    final old = _music;
    _music = null;
    if (old != null) _guard(() => _fadeOut(old));
    if (path == null) return;
    final player = AudioPlayer();
    _music = player;
    _guard(() async {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(DeviceFileSource(path));
    });
  }

  Future<void> _fadeOut(AudioPlayer player, {Duration duration = const Duration(milliseconds: 500)}) async {
    const steps = 10;
    final volume = player.volume;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(duration ~/ steps);
      if (_disposed) break;
      await player.setVolume(volume * (1 - i / steps));
    }
    await player.dispose();
  }

  @override
  void setMedia(String? path, MediaPlayback playback) {
    _guard(() async {
      if (path == null || playback == MediaPlayback.stopped) {
        _mediaPath = null;
        await _media.stop();
      } else if (path != _mediaPath) {
        _mediaPath = path;
        await _media.setSource(DeviceFileSource(path));
        if (playback == MediaPlayback.playing) await _media.resume();
      } else if (playback == MediaPlayback.playing) {
        await _media.resume();
      } else {
        await _media.pause();
      }
    });
  }

  void _once(Source source) {
    final player = AudioPlayer();
    _guard(() async {
      await player.play(source);
      await player.onPlayerComplete.first.timeout(const Duration(minutes: 2), onTimeout: () {});
      await player.dispose();
    });
  }

  @override
  void playFile(String path) => _once(DeviceFileSource(path));

  @override
  void playAsset(String asset) => _once(AssetSource(asset));

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _mediaDone.cancel();
    await _completed.close();
    await _music?.dispose();
    await _media.dispose();
  }
}
