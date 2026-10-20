import 'dart:async';

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

  /// Loops the bundled [asset] quietly while nothing else plays; null stops it.
  void setAmbience(String? asset);

  /// The open question's own sound. A new [path] starts from the beginning;
  /// the same path follows [playback] (pause keeps the position).
  void setMedia(String? path, MediaPlayback playback);

  /// Plays a file once, on top of everything else.
  void playFile(String path);

  /// Plays a bundled asset once.
  void playAsset(String asset);

  /// Fires when the question's sound has played to its end.
  Stream<void> get mediaCompleted;

  Future<void> dispose();
}

/// Turns the session's state and one-shot effects into sound on the
/// presenting device. Other devices stay silent.
class AudioDirector {
  AudioDirector({
    required this.host,
    required this.backend,
    required this.resolve,
    this.teamSound,
    this.buzzerAsset = 'buzzer.mp3',
  }) {
    _subs = [
      host.states.listen((_) => sync()),
      host.effects.listen(_onEffect),
      // Tell everyone the sound is over, so the play button comes back.
      backend.mediaCompleted.listen((_) => host.dispatch(const SetMedia(MediaPlayback.stopped))),
    ];
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
  double _volume = 1;
  MediaPlayback _playback = MediaPlayback.stopped;

  MusicConfig get _sounds =>
      host.game?.soundsFor(ref: host.state.current, groupId: host.state.groupId) ?? MusicConfig.empty;

  String? _path(String? name) {
    final game = host.game;
    return game == null || name == null ? null : resolve(game.id, name);
  }

  /// Brings the backend in line with the current state. Called on every new
  /// state, and by the owner when media files finish downloading.
  void sync() {
    final state = host.state;
    // The game's own music for the slot, or the one that comes with the app.
    final own = state.music == null ? null : _path(_sounds.slots[state.music]);
    final builtin = state.music == null || _sounds.slots.containsKey(state.music) ? null : builtinMusic[state.music];
    final music = own ?? (builtin == null ? null : 'asset:$builtin');
    if (music != _music) {
      _music = music;
      backend.setMusic(music);
    }

    final question = state.current == null ? null : host.game?.question(state.current!);
    final media = state.media == MediaPlayback.stopped ? null : _path(question?.musicAt(state.revealed));
    final playback = media == null ? MediaPlayback.stopped : state.media;
    if (media != _media || playback != _playback) {
      _media = media;
      _playback = playback;
      backend.setMedia(media, playback);
    }

    final volume = state.musicVolume / 100;
    if (volume != _volume) {
      _volume = volume;
      backend.setMusicVolume(volume);
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
      case SoundEffect(:final key):
        final chosen = _sounds.effects[key];
        if (chosen == silentSound) return;
        // A built-in sound picked in the editor for this moment.
        final picked = chosen != null && chosen.startsWith(builtinSoundPrefix) ? builtinSound(chosen) : null;
        if (picked != null) {
          backend.playAsset(picked.asset);
          return;
        }
        final path = _path(chosen);
        if (path != null) {
          backend.playFile(path);
          return;
        }
        // One that comes with the app: asked for by name, or the default for
        // a moment the game has no sound of its own for.
        final builtin = builtinSound(key) ?? builtinSound(defaultEffectSounds[key] ?? '');
        if (builtin != null && (key.startsWith(builtinSoundPrefix) || !_sounds.effects.containsKey(key))) {
          backend.playAsset(builtin.asset);
        }
      case BuzzerSound(:final teamId):
        final builtin = builtinBuzzer(host.state.team(teamId)?.sound);
        if (builtin != null) {
          backend.playAsset(builtin.asset);
          return;
        }
        final own = teamSound?.call(teamId);
        own == null ? backend.playAsset(buzzerAsset) : backend.playFile(own);
      case VisualEffect():
        break; // nothing to hear
    }
  }

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    await backend.dispose();
  }
}
