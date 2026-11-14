import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'package:quiz_show/features/audio/audio_director.dart';
import 'package:quiz_show/game/game.dart';

/// [AudioBackend] on top of the audioplayers plugin.
class AudioplayersBackend implements AudioBackend {
  AudioplayersBackend({this.stepLimit = const Duration(seconds: 5)});

  AudioPlayer? _music;
  AudioPlayer? _ambience;
  double _musicVolume = 1;

  /// The question's sound: a player of its own for every new sound, so one
  /// that is still loading or ending cannot get in the way of the next.
  AudioPlayer? _media;
  String? _mediaPath;
  StreamSubscription<void>? _mediaDone;

  /// What is asked of the question's sound runs in order, one step after
  /// the other; a step that hangs is given up after [stepLimit].
  Future<void> _mediaSteps = Future.value();
  final Duration stepLimit;

  final StreamController<void> _completed = StreamController<void>.broadcast();
  bool _disposed = false;

  @override
  Stream<void> get mediaCompleted => _completed.stream;

  /// Done once everything asked of the question's sound so far is through.
  @visibleForTesting
  Future<void> get mediaSettled => _mediaSteps;

  void _guard(Future<void> Function() action) {
    action().catchError((Object error) {
      if (kDebugMode) print('Audio: $error');
    });
  }

  /// How long one piece of music takes to give way to the next: the old one
  /// fades out while the new one fades in.
  static const Duration crossfade = Duration(milliseconds: 1500);

  /// The noise is only there to keep the speakers awake, so it starts low.
  double _ambienceVolume = 0.15;

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
    final stop = path == null || playback == MediaPlayback.stopped;
    final fresh = !stop && path != _mediaPath;
    // Decided right away, so whatever comes next is compared with this.
    _mediaPath = stop ? null : path;
    _mediaSteps = _mediaSteps.then((_) async {
      if (_disposed) return;
      try {
        if (stop || fresh) await _releaseMedia();
        if (stop) return;
        if (fresh) {
          final player = AudioPlayer();
          _media = player;
          // Only the sound still asked for tells that it is over.
          _mediaDone = player.onPlayerComplete.listen((_) {
            if (identical(_media, player) && !_completed.isClosed) _completed.add(null);
          });
          await player.setReleaseMode(ReleaseMode.stop).timeout(stepLimit);
          await player.setSource(DeviceFileSource(path)).timeout(stepLimit);
          await player.setVolume(1).timeout(stepLimit);
          if (playback == MediaPlayback.playing) await _play(player);
        } else if (_media case final player?) {
          playback == MediaPlayback.playing ? await _play(player) : await player.pause().timeout(stepLimit);
        }
      } catch (error) {
        if (kDebugMode) print('Audio: $error');
      }
    });
  }

  /// Starts [player], at full volume once it really plays: the system may
  /// otherwise give a new stream the volume of another of this app's sounds.
  Future<void> _play(AudioPlayer player) async {
    await player.resume().timeout(stepLimit);
    await player.setVolume(1).timeout(stepLimit);
  }

  /// Stops the question's sound and lets go of its player.
  Future<void> _releaseMedia() async {
    final player = _media;
    _media = null;
    await _mediaDone?.cancel();
    _mediaDone = null;
    if (player == null) return;
    try {
      await player.stop().timeout(stepLimit);
    } catch (error) {
      // Gone either way: the next sound gets a player of its own.
      if (kDebugMode) print('Audio: $error');
    } finally {
      // Never waited for: a player that hangs is not to hold up the next sound.
      unawaited(player.dispose().catchError((Object _) {}));
    }
  }

  /// A sound played once, at full volume, on a player of its own that is
  /// let go when the sound ends (or after two minutes at the latest), so a
  /// long show does not pile up players.
  void _once(Source source) {
    final player = AudioPlayer();
    _guard(() async {
      try {
        // Set every time: the system may otherwise start a new sound at the
        // volume of another of this app's sounds, such as the quiet noise.
        await player.play(source, volume: 1);
        await player.setVolume(1);
        await player.onPlayerComplete.first.timeout(const Duration(minutes: 2));
      } on TimeoutException {
        // Played long enough.
      } finally {
        await player.dispose();
      }
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
    await _mediaDone?.cancel();
    await _completed.close();
    await _music?.dispose();
    await _ambience?.dispose();
    await _media?.dispose();
  }
}
