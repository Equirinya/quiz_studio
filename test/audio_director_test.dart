import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/audio/audio_director.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

class FakeBackend implements AudioBackend {
  final List<String> log = [];

  /// Kept apart: the noise is on in every session and would crowd [log].
  final List<String> ambience = [];
  final StreamController<void> completed = StreamController<void>.broadcast(sync: true);

  @override
  void setMusic(String? path) => log.add('music $path');
  @override
  void setMusicVolume(double volume) => log.add('volume $volume');
  @override
  void setAmbience(String? asset) => ambience.add('$asset');
  @override
  void setAmbienceVolume(double volume) => ambienceVolume = volume;
  double? ambienceVolume;
  @override
  void setMedia(String? path, MediaPlayback playback) => log.add('media $path ${playback.name}');
  @override
  void playFile(String path) => log.add('file $path');
  @override
  void playAsset(String asset) => log.add('asset $asset');
  @override
  Stream<void> get mediaCompleted => completed.stream;
  @override
  Future<void> dispose() => completed.close();
}

void main() {
  late SessionHost host;
  late FakeBackend backend;
  late AudioDirector director;
  // Everything is "downloaded" except one file.
  final missing = <String>{};

  setUp(() {
    missing.clear();
    host = SessionHost(initial: fixtureState(), game: fixtureGame());
    backend = FakeBackend();
    director = AudioDirector(
      host: host,
      backend: backend,
      resolve: (gameId, name) => missing.contains(name) ? null : '/$gameId/$name',
    );
  });
  tearDown(() async {
    await director.dispose();
    await host.dispose();
  });

  test('music follows the slot and is resolved from the most specific level', () {
    host.dispatch(const SetMusic(musicBackground));
    expect(backend.log, ['music /game/bg.mp3']);
    // The finale group brings its own background music.
    host.dispatch(const SelectGroup('g2'));
    expect(backend.log.last, 'music /game/finale.mp3');
    host.dispatch(const SetMusic(null));
    expect(backend.log.last, 'music null');
  });

  test('nothing is sent again while nothing changes', () {
    host.dispatch(const SetMusic(musicBackground));
    host.dispatch(const AdjustPoints('red', 100));
    host.dispatch(const AddTeam('green', 'Green'));
    expect(backend.log, ['music /game/bg.mp3']);
  });

  test('the noise that keeps the speakers awake is on, and fills every silence, in any game', () {
    expect(backend.ambience, ['sounds/ambience/soft_noise.wav']);
    // Music takes over, and the noise comes back when it stops.
    host.dispatch(const SetMusic(musicBackground));
    expect(backend.ambience.last, 'null');
    host.dispatch(const SetMusic(null));
    expect(backend.ambience.last, 'sounds/ambience/soft_noise.wav');
    // So does a question's own sound.
    host
      ..dispatch(const OpenQuestion(song))
      ..dispatch(const SetMedia(MediaPlayback.playing));
    expect(backend.ambience.last, 'null');
    // Switched off, it stays off.
    host
      ..dispatch(const SetMedia(MediaPlayback.stopped))
      ..dispatch(const SetAmbience(null));
    expect(backend.ambience.last, 'null');
  });

  test('sounds that come with the app play by name, and fill in for a reveal the game has no sound for', () {
    host.dispatch(const PlayEffect('builtin:drumroll/snare'));
    expect(backend.log, ['asset sounds/effects/drumroll/snare.mp3']);
    host
      ..dispatch(const OpenQuestion(feud))
      ..dispatch(const Buzz('red'))
      ..dispatch(const FeudToggle(0));
    expect(backend.log.last, 'asset sounds/effects/reveal/pluck.mp3');
  });

  test('a team can have one of the buzzers that come with the app', () {
    host
      ..dispatch(const SetTeamSound('blue', 'builtin:buzzer/buzzer'))
      ..dispatch(const OpenQuestion(free))
      ..dispatch(const Buzz('blue'));
    expect(backend.log, ['asset sounds/effects/question_open/brass_stab.wav', 'asset sounds/buzzers/buzzer.wav']);
  });

  test('a moment can be set to a built-in sound, or to silence', () {
    final base = fixtureGame();
    host.setGame(GameContent(id: base.id, name: base.name, groups: base.groups, data: base.data, sounds: MusicConfig.fromMap({
      'musicEffects': {
        effectQuestionOpen: silentSound,
        effectAnswerCorrect: 'builtin:right_answer/voice_correct_male',
      },
    })));
    host
      ..dispatch(const OpenQuestion(free))
      ..dispatch(const Buzz('red'))
      ..dispatch(const Judge(correct: true));
    expect(backend.log, ['asset sounds/buzzers/buzzer.wav', 'asset sounds/effects/right_answer/voice_correct_male.mp3']);
  });

  test('the music volume follows the session', () {
    host.dispatch(const SetMusicVolume(40));
    expect(backend.log, ['volume 0.4']);
    expect(host.state.musicVolume, 40);
  });

  test('a slot the game has no music for plays the music that comes with the app', () {
    host.dispatch(const SetMusic(musicCalm));
    expect(backend.log, ['music asset:sounds/music/chill.mp3']);
  });

  test('the question sound plays, pauses on a buzz, resumes after a wrong answer, stops on close', () {
    host
      ..dispatch(const OpenQuestion(song))
      ..dispatch(const SetMedia(MediaPlayback.playing));
    expect(backend.log.last, 'media /game/song.mp3 playing');
    backend.log.clear();
    host.dispatch(const Buzz('red'));
    expect(backend.log, ['media /game/song.mp3 paused', 'asset sounds/buzzers/buzzer.wav']);
    backend.log.clear();
    host.dispatch(const Judge(correct: false));
    expect(backend.log, ['media /game/song.mp3 playing', 'file /game/wrong.mp3']);
    host.dispatch(const CloseQuestion());
    expect(backend.log.last, 'media null stopped');
  });

  test('when the sound ends the state says so', () {
    host
      ..dispatch(const OpenQuestion(song))
      ..dispatch(const SetMedia(MediaPlayback.playing));
    backend.completed.add(null);
    expect(host.state.media, MediaPlayback.stopped);
    expect(backend.log.last, 'media null stopped');
  });

  test('effects play their file; a moment the game has none for gets the built-in one', () {
    host
      ..dispatch(const OpenQuestion(free))
      ..dispatch(const Buzz('red'))
      ..dispatch(const Judge(correct: false));
    // Opening plays the built-in question sound, as the game has none.
    expect(backend.log, ['asset sounds/effects/question_open/brass_stab.wav', 'asset sounds/buzzers/buzzer.wav', 'file /game/wrong.mp3']);
    backend.log.clear();
    // No "right answer" sound is configured in the fixture game.
    host
      ..dispatch(const Buzz('red'))
      ..dispatch(const Judge(correct: true));
    expect(backend.log, ['asset sounds/buzzers/buzzer.wav', 'asset sounds/effects/right_answer/right_answer.mp3']);
    host.dispatch(const PlayEffect('airhorn'));
    expect(backend.log.last, 'file /game/horn.mp3');
  });

  test('a team with a sound of its own buzzes with it', () async {
    await director.dispose();
    backend = FakeBackend();
    director = AudioDirector(
      host: host,
      backend: backend,
      resolve: (gameId, name) => '/$gameId/$name',
      teamSound: (teamId) => teamId == 'red' ? '/sounds/red.mp3' : null,
    );
    host
      ..dispatch(const SetQueueBuzzers(true))
      ..dispatch(const OpenQuestion(free))
      ..dispatch(const Buzz('red'))
      ..dispatch(const Buzz('blue'));
    expect(backend.log, ['asset sounds/effects/question_open/brass_stab.wav', 'file /sounds/red.mp3', 'asset sounds/buzzers/buzzer.wav']);
  });

  test('a question can override an effect', () {
    host
      ..dispatch(const OpenQuestion(reveal))
      ..dispatch(const PlayEffect(effectAnswerWrong));
    expect(backend.log.last, 'file /game/question-wrong.mp3');
  });

  test('a file that is not downloaded yet starts once sync is called again', () {
    missing.add('bg.mp3');
    host.dispatch(const SetMusic(musicBackground));
    expect(backend.log, isEmpty);
    missing.clear();
    director.sync();
    expect(backend.log, ['music /game/bg.mp3']);
  });
}
