import 'dart:async';
import 'dart:math';

import 'package:quiz_show/game/game.dart';

/// What the presenter's speakers can do. Kept this small so the logic that
/// decides what should sound can be tested without any audio device.
abstract class AudioBackend {
  /// Loops the file at [path] as the only music, fading out whatever played
  /// before. A path starting with `asset:` is a bundled asset. Null fades to
  /// silence.
  void setMusic(String? path);

  /// 0 to 1, for the music only.
  void setMusicVolume(double volume);

  /// Pauses the music while [hold] is true, keeping its place, and brings
  /// it back after. The backend also holds it while an effect sounds.
  void holdMusic(bool hold);

  /// Loops the bundled [asset] quietly while nothing else plays; null stops it.
  void setAmbience(String? asset);

  /// 0 to 1, for that noise only.
  void setAmbienceVolume(double volume);

  /// The open question's own sound. A new [path] starts from the beginning;
  /// the same path follows [playback] (pause keeps the position).
  void setMedia(String? path, MediaPlayback playback);

  /// Moves the question's sound to [position].
  void seekMedia(Duration position);

  /// 0 to 1, for the question's sound only.
  void setMediaVolume(double volume);

  /// Plays a file once, on top of everything else, to its end however long
  /// it is. One with an [id] can be stopped by it, a new one with the same
  /// [id] takes over from it, and [soundEnded] tells when it is over. An
  /// [effect] plays at the effects' volume, anything else at full volume.
  void playFile(String path, {String? id, bool effect = true});

  /// Plays a bundled asset once; see [playFile].
  void playAsset(String asset, {String? id, bool effect = true});

  /// Stops the sound played with [id]; null stops every one with an id.
  void stopSound(String? id);

  /// 0 to 1, for the effects, also those already sounding.
  void setEffectsVolume(double volume);

  /// The id of a sound played with one, when it is over: played to its
  /// end, stopped, or failed to play.
  Stream<String> get soundEnded;

  /// Fires when the question's sound has played to its end.
  Stream<void> get mediaCompleted;

  /// How long the question's sound is, once it is loaded.
  Stream<Duration> get mediaDurations;

  Future<void> dispose();
}

/// How loud a volume slider at [percent] plays, 0 to 1. Ears hear loudness
/// in decibels, so the slider runs along those: each step down takes off the
/// same share, 100 % is full and 1 % is 40 dB quieter, about a hundredth.
/// A straight line would still be loud at 5 %.
double sliderGain(int percent) {
  if (percent <= 0) return 0;
  if (percent >= 100) return 1;
  return pow(10, (percent / 100 - 1) * _sliderRangeDb / 20).toDouble();
}

const double _sliderRangeDb = 40;

/// Turns the session's state and one-shot effects into sound on the
/// presenting device. Other devices stay silent.
class AudioDirector {
  AudioDirector({
    required this.host,
    required this.backend,
    required this.resolve,
    this.teamSound,
    this.buzzerAsset = 'sounds/buzzers/buzzer.wav',
  }) {
    _subs = [
      host.states.listen((_) => sync()),
      host.effects.listen(_onEffect),
      // Tell everyone the sound is over, so the play button comes back.
      backend.mediaCompleted.listen((_) => host.dispatch(const SetMedia(MediaPlayback.stopped))),
      backend.mediaDurations.listen((duration) => host.dispatch(MediaLoaded(duration.inMilliseconds))),
      // The chip lights up while its effect sounds.
      backend.soundEnded.listen((key) => host.dispatch(EffectEnded(key))),
    ];
    // Effects still listed from before this device took over play nowhere.
    if (host.state.effectsPlaying.isNotEmpty) scheduleMicrotask(() => host.dispatch(const EffectEnded()));
    sync();
  }

  final SessionHost host;
  final AudioBackend backend;

  /// The local path of a media file of the current game, or null when it is
  /// not available on this device.
  final String? Function(String gameId, String name) resolve;

  /// A team's own buzzer sound as a local file path; null for the default.
  final String? Function(String teamId)? teamSound;
  final String buzzerAsset;

  late final List<StreamSubscription<dynamic>> _subs;
  String? _music;
  String? _media;
  String? _ambience;
  double? _ambienceVolume;
  double _volume = 1;
  bool _musicHeld = false;
  double _effectsVolume = 1;
  double _mediaVolume = 1;
  late int _seek = host.state.mediaSeek;
  MediaPlayback _playback = MediaPlayback.stopped;

  MusicConfig get _sounds =>
      host.game?.soundsFor(ref: host.state.current, groupId: host.state.groupId, focus: host.state.boardFocus) ?? MusicConfig.empty;

  String? _path(String? name) {
    final game = host.game;
    return game == null || name == null ? null : resolve(game.id, name);
  }

  /// Brings the backend in line with the current state. Called on every new
  /// state, and by the owner when media files finish downloading.
  void sync() {
    final state = host.state;
    // The game's own music for the slot, or the one that comes with the app.
    final stored = state.music == null ? null : _sounds.slots[state.music];
    final slot = state.music == null ? null : musicAssetFor(state.music!, stored);
    // A built-in track, the app's own for an unset slot, or the game's file.
    final music = slot == null || slot.silent
        ? null
        : slot.asset != null
            ? 'asset:${slot.asset}'
            : _path(stored);
    if (music != _music) {
      _music = music;
      backend.setMusic(music);
    }

    final question = state.current == null ? null : host.game?.question(state.current!);
    // A clip brings its own sound and is played by the big screen.
    final media = state.media == MediaPlayback.stopped || question?.videoAt(state.revealed, state.standing) != null
        ? null
        : _path(question?.musicAt(state.revealed, state.standing));
    final playback = media == null ? MediaPlayback.stopped : state.media;
    final mediaVolume = sliderGain(state.mediaVolume);
    if (mediaVolume != _mediaVolume) {
      _mediaVolume = mediaVolume;
      backend.setMediaVolume(mediaVolume);
    }
    final fresh = media != _media;
    if (fresh || playback != _playback) {
      _media = media;
      _playback = playback;
      backend.setMedia(media, playback);
    }
    // Moved by the gamemaster: a sound just started begins where it should anyway.
    if (state.mediaSeek != _seek) {
      _seek = state.mediaSeek;
      final clock = state.mediaClock;
      if (media != null && !fresh && clock != null) backend.seekMedia(Duration(milliseconds: clock.positionMs));
    }

    // The music waits, and comes back after: while the question's sound or
    // clip plays, a video card is up, or a team answers.
    final hold = state.media == MediaPlayback.playing || (state.overlay?.video ?? '').isNotEmpty || state.phase == Phase.buzzered;
    if (hold != _musicHeld) {
      _musicHeld = hold;
      backend.holdMusic(hold);
    }

    final effectsVolume = sliderGain(state.effectsVolume);
    if (effectsVolume != _effectsVolume) {
      _effectsVolume = effectsVolume;
      backend.setEffectsVolume(effectsVolume);
    }

    final volume = sliderGain(state.musicVolume);
    if (volume != _volume) {
      _volume = volume;
      backend.setMusicVolume(volume);
    }

    // At most half as loud as the device plays: it only keeps speakers awake.
    final ambienceVolume = sliderGain(state.ambienceVolume) / 2;
    if (ambienceVolume != _ambienceVolume) {
      _ambienceVolume = ambienceVolume;
      backend.setAmbienceVolume(ambienceVolume);
    }

    // The noise only fills silence: music or the question's sound take over.
    final quiet = music == null && playback != MediaPlayback.playing;
    final ambience = quiet ? ambienceAssets[state.ambience] : null;
    if (ambience != _ambience) {
      _ambience = ambience;
      backend.setAmbience(ambience);
    }
  }

  void _onEffect(Effect effect) {
    switch (effect) {
      case SoundEffect(:final key, :final held):
        if (!_playEffect(key, id: held ? key : null) && held) {
          // Nothing to hear: the chip goes out again.
          scheduleMicrotask(() => host.dispatch(EffectEnded(key)));
        }
      case StopSound(:final key):
        backend.stopSound(key);
      case BuzzerSound(:final teamId):
        final builtin = builtinBuzzer(host.state.team(teamId)?.sound);
        if (builtin != null) {
          backend.playAsset(builtin.asset, effect: false);
          return;
        }
        final own = teamSound?.call(teamId);
        own == null ? backend.playAsset(buzzerAsset, effect: false) : backend.playFile(own, effect: false);
      case VisualEffect():
        break; // nothing to hear
    }
  }

  /// Plays the effect [key] stands for; false when there is nothing to play.
  bool _playEffect(String key, {String? id}) {
    final chosen = _sounds.effects[key];
    if (chosen == silentSound) return false;
    // A built-in sound picked in the editor for this moment.
    final picked = chosen != null && chosen.startsWith(builtinSoundPrefix) ? builtinSound(chosen) : null;
    if (picked != null) {
      backend.playAsset(picked.asset, id: id);
      return true;
    }
    final path = _path(chosen);
    if (path != null) {
      backend.playFile(path, id: id);
      return true;
    }
    // One that comes with the app: asked for by name, or the default for
    // a moment the game has no sound of its own for.
    final builtin = builtinSound(key) ?? builtinSound(defaultEffectSounds[key] ?? '');
    if (builtin != null && (key.startsWith(builtinSoundPrefix) || !_sounds.effects.containsKey(key))) {
      backend.playAsset(builtin.asset, id: id);
      return true;
    }
    return false;
  }

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    await backend.dispose();
  }
}
