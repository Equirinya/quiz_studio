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
  AudioPlayer? _ambience;
  double _musicVolume = 1;
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

  /// How long one piece of music takes to give way to the next: the old one
  /// fades out while the new one fades in.
  static const Duration crossfade = Duration(milliseconds: 1500);

  /// The noise is only there to keep the speakers awake, so it starts low.
  double _ambienceVolume = 0.2;

  @override
  void setMusic(String? path) {
    final old = _music;
    _music = null;
    if (old != null) _guard(() => _fadeOut(old, duration: crossfade));
    if (path == null) return;
    final player = AudioPlayer();
    _music = player;
    _guard(() async {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0);
      await player.play(path.startsWith('asset:') ? AssetSource(path.substring(6)) : DeviceFileSource(path));
      await _fadeTo(player, () => identical(_music, player) ? _musicVolume : player.volume, crossfade);
    });
  }

  /// Raises [player] to [target] over [duration]; [target] is read on every
  /// step, so a volume change in the middle of a fade is followed.
  Future<void> _fadeTo(AudioPlayer player, double Function() target, Duration duration) async {
    const steps = 20;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(duration ~/ steps);
      if (_disposed || (!identical(_music, player) && !identical(_ambience, player))) return;
      await player.setVolume(target() * i / steps);
    }
  }

  Future<void> _fadeOut(AudioPlayer player, {Duration duration = const Duration(milliseconds: 500)}) async {
    const steps = 20;
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
  void setMusicVolume(double volume) {
    _musicVolume = volume;
    final player = _music;
    if (player != null) _guard(() => player.setVolume(volume));
  }

  @override
  void setAmbience(String? asset) {
    final old = _ambience;
    _ambience = null;
    if (old != null) _guard(() => _fadeOut(old, duration: crossfade));
    if (asset == null) return;
    final player = AudioPlayer();
    _ambience = player;
    _guard(() async {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0);
      await player.play(AssetSource(asset));
      await _fadeTo(player, () => _ambienceVolume, crossfade);
    });
  }

  @override
  void setAmbienceVolume(double volume) {
    _ambienceVolume = volume;
    final player = _ambience;
    if (player != null) _guard(() => player.setVolume(volume));
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
    await _ambience?.dispose();
    await _media.dispose();
  }
}
