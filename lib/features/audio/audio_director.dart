import 'dart:async';

import 'package:quiz_show/game/game.dart';

/// What the presenter's speakers can do. Kept this small so the logic that
/// decides what should sound can be tested without any audio device.
abstract class AudioBackend {
  /// Loops the file at [path] as the only music, fading out whatever played
  /// before. Null fades to silence.
  void setMusic(String? path);

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
  final String buzzerAsset;

  late final List<StreamSubscription<dynamic>> _subs;
  String? _music;
  String? _media;
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
    final music = state.music == null ? null : _path(_sounds.slots[state.music]);
    if (music != _music) {
      _music = music;
      backend.setMusic(music);
    }

    final question = state.current == null ? null : host.game?.question(state.current!);
    final media = state.media == MediaPlayback.stopped ? null : _path(question?.music);
    final playback = media == null ? MediaPlayback.stopped : state.media;
    if (media != _media || playback != _playback) {
      _media = media;
      _playback = playback;
      backend.setMedia(media, playback);
    }
  }

  void _onEffect(Effect effect) {
    switch (effect) {
      case SoundEffect(:final key):
        final path = _path(_sounds.effects[key]);
        if (path != null) backend.playFile(path);
      case BuzzerSound():
        backend.playAsset(buzzerAsset);
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
