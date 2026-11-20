import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'package:quiz_show/features/audio/audio_director.dart';
import 'package:quiz_show/game/game.dart';

/// [AudioBackend] on top of the audioplayers plugin.
class AudioplayersBackend implements AudioBackend {
  AudioplayersBackend({this.stepLimit = const Duration(seconds: 5)}) {
    if (!_mixing) {
      _mixing = true;
      // By default every new player takes the audio focus on Android, and
      // the plugin pauses the one that loses it for good: the first effect
      // or buzzer would stop the music. The show's sounds mix; who waits for
      // whom is decided here.
      _guard(() => AudioPlayer.global.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build()));
    }
  }

  static bool _mixing = false;

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
  final StreamController<Duration> _durations = StreamController<Duration>.broadcast();
  final StreamController<String> _ended = StreamController<String>.broadcast();
  bool _disposed = false;

  /// How loud the question's sound plays.
  double _mediaVolume = 1;

  /// How loud effects play.
  double _effectsVolume = 1;

  /// The sounds played once that are still sounding: whether each is an
  /// effect, its id, and how to stop it early.
  final Map<AudioPlayer, ({bool effect, String? id, Completer<void> stop})> _sounding = {};

  @override
  Stream<void> get mediaCompleted => _completed.stream;

  @override
  Stream<Duration> get mediaDurations => _durations.stream;

  @override
  Stream<String> get soundEnded => _ended.stream;

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
    // It loops; should a platform still say it ended, it starts over.
    player.onPlayerComplete.listen((_) {
      if (!identical(_music, player) || _disposed || _musicPaused) return;
      _guard(() async {
        await player.resume();
        await player.seek(Duration.zero);
      });
    });
    _guard(() async {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0);
      await player.setSource(path.startsWith('asset:') ? AssetSource(path.substring(6)) : DeviceFileSource(path));
      // Held for now: it starts when whatever holds it is over.
      if (!identical(_music, player) || _musicPaused) return;
      await player.resume();
      await _fadeTo(player, () => identical(_music, player) && !_musicPaused ? _musicVolume : 0, crossfade);
    });
  }

  /// The show holds the music: the question's sound plays, a team answers.
  bool _showHolds = false;

  /// Whether the music is paused now, for the show or for an effect.
  bool _musicPaused = false;

  /// Each pause or return of the music; a fade that is no longer the latest stops.
  int _hold = 0;
  Timer? _musicBack;

  /// How long the music waits after the last effect, so a few in a row do
  /// not each bring it back for a moment.
  static const Duration musicReturnDelay = Duration(milliseconds: 600);

  bool get _held => _showHolds || _sounding.values.any((sound) => sound.effect);

  @override
  void holdMusic(bool hold) {
    _showHolds = hold;
    _followHold();
  }

  /// Pauses the music at once when something holds it; brings it back a
  /// moment after nothing does any more.
  void _followHold() {
    if (_disposed) return;
    _musicBack?.cancel();
    _musicBack = null;
    if (_held) {
      _setMusicPaused(true);
    } else if (_musicPaused) {
      _musicBack = Timer(_showHolds ? Duration.zero : musicReturnDelay, () {
        if (!_held) _setMusicPaused(false);
      });
    }
  }

  void _setMusicPaused(bool paused) {
    if (paused == _musicPaused) return;
    _musicPaused = paused;
    final hold = ++_hold;
    final player = _music;
    if (player == null) return;
    _guard(() async {
      const steps = 10;
      if (paused) {
        final from = player.volume;
        for (var i = 1; i <= steps; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
          if (hold != _hold || _disposed) return;
          await player.setVolume(from * (1 - i / steps));
        }
        if (hold == _hold && !_disposed) await player.pause();
      } else {
        await player.resume();
        for (var i = 1; i <= steps; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          if (hold != _hold || _disposed || !identical(_music, player)) return;
          await player.setVolume(_musicVolume * i / steps);
        }
      }
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
          await player.setVolume(_mediaVolume).timeout(stepLimit);
          // For the bar on the controller; not every file says.
          final duration = await player.getDuration().timeout(stepLimit, onTimeout: () => null);
          if (duration != null && duration > Duration.zero && identical(_media, player) && !_durations.isClosed) {
            _durations.add(duration);
          }
          if (playback == MediaPlayback.playing) await _play(player);
        } else if (_media case final player?) {
          playback == MediaPlayback.playing ? await _play(player) : await player.pause().timeout(stepLimit);
        }
      } catch (error) {
        if (kDebugMode) print('Audio: $error');
      }
    });
  }

  /// Starts [player], at its volume once it really plays: the system may
  /// otherwise give a new stream the volume of another of this app's sounds.
  Future<void> _play(AudioPlayer player) async {
    await player.resume().timeout(stepLimit);
    await player.setVolume(_mediaVolume).timeout(stepLimit);
  }

  @override
  void seekMedia(Duration position) {
    _mediaSteps = _mediaSteps.then((_) async {
      if (_disposed) return;
      try {
        await _media?.seek(position).timeout(stepLimit);
      } catch (error) {
        if (kDebugMode) print('Audio: $error');
      }
    });
  }

  @override
  void setMediaVolume(double volume) {
    _mediaVolume = volume;
    final player = _media;
    if (player != null) _guard(() => player.setVolume(volume));
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

  /// A sound played once on a player of its own, let go when the sound
  /// ends or is stopped, so a long show does not pile up players. However
  /// long the sound: only one that never says it ended is let go, a while
  /// after it should have.
  void _once(Source source, {String? id, required bool effect}) {
    if (_disposed) return;
    // The same effect again starts over.
    if (id != null) _stop((sound) => sound.id == id);
    final player = AudioPlayer();
    final stop = Completer<void>();
    _sounding[player] = (effect: effect, id: id, stop: stop);
    final volume = effect ? _effectsVolume : 1.0;
    // The music waits for the effect.
    if (effect) _followHold();
    _guard(() async {
      try {
        final done = player.onPlayerComplete.first;
        // Set every time: the system may otherwise start a new sound at the
        // volume of another of this app's sounds, such as the quiet noise.
        // Each step only so long: a player that does not answer one must
        // not hold up hearing when the sound ends, or its chip stays lit
        // and the next tap stops it instead of playing it. A step that
        // fails outright (a file it cannot open) ends it.
        Future<T?> step<T>(Future<T> Function() action) =>
            action().timeout(stepLimit).then<T?>((value) => value, onError: (Object error) => error is TimeoutException ? null : throw error);
        await step(() => player.play(source, volume: volume));
        await step(() => player.setVolume(_sounding[player]?.effect == true ? _effectsVolume : volume));
        final length = await step(player.getDuration).catchError((Object _) => null);
        await Future.any([done, stop.future]).timeout(
          length == null || length <= Duration.zero ? const Duration(hours: 1) : length + const Duration(seconds: 30),
        );
      } on TimeoutException {
        // Never told it ended, or a step did not answer.
      } catch (error) {
        // A file the player cannot open: nothing to hear, and over.
        if (kDebugMode) print('Audio: $error');
      } finally {
        _sounding.remove(player);
        if (effect) _followHold();
        // Another with the same id took over: that one is still sounding.
        if (id != null && !_sounding.values.any((sound) => sound.id == id) && !_ended.isClosed) _ended.add(id);
        await player.dispose();
      }
    });
  }

  /// Stops the sounds played once that [which] picks.
  void _stop(bool Function(({bool effect, String? id, Completer<void> stop}) sound) which) {
    for (final MapEntry(key: player, value: sound) in _sounding.entries.toList()) {
      if (!which(sound) || sound.stop.isCompleted) continue;
      _guard(player.stop);
      sound.stop.complete();
    }
  }

  @override
  void stopSound(String? id) => _stop((sound) => sound.id != null && (id == null || sound.id == id));

  @override
  void setEffectsVolume(double volume) {
    _effectsVolume = volume;
    for (final MapEntry(key: player, value: sound) in _sounding.entries) {
      if (sound.effect) _guard(() => player.setVolume(volume));
    }
  }

  @override
  void setMusicVolume(double volume) {
    _musicVolume = volume;
    final player = _music;
    if (player != null && !_musicPaused) _guard(() => player.setVolume(volume));
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
  void playFile(String path, {String? id, bool effect = true}) => _once(DeviceFileSource(path), id: id, effect: effect);

  @override
  void playAsset(String asset, {String? id, bool effect = true}) => _once(AssetSource(asset), id: id, effect: effect);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _musicBack?.cancel();
    await _mediaDone?.cancel();
    await _completed.close();
    await _durations.close();
    await _ended.close();
    for (final player in _sounding.keys.toList()) {
      await player.dispose();
    }
    _sounding.clear();
    await _music?.dispose();
    await _ambience?.dispose();
    await _media?.dispose();
  }
}
