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
  void playFile(String path, {String? id, bool effect = true}) {
    log.add('file $path');
    if (id != null) held.add(id);
    if (!effect) unscaled.add(path);
  }

  @override
  void playAsset(String asset, {String? id, bool effect = true}) {
    log.add('asset $asset');
    if (id != null) held.add(id);
    if (!effect) unscaled.add(asset);
  }

  /// Ids the sounds were played with; sounds played at full volume.
  final List<String> held = [];
  final List<String> unscaled = [];
  final List<String?> stopped = [];
  final List<String> extra = [];

  @override
  void stopSound(String? id) => stopped.add(id);
  final List<bool> holds = [];
  @override
  void holdMusic(bool hold) => holds.add(hold);
  @override
  void setEffectsVolume(double volume) => extra.add('effects $volume');
  @override
  void setMediaVolume(double volume) => extra.add('media volume $volume');
  @override
  void seekMedia(Duration position) => extra.add('seek ${position.inMilliseconds}');

  final StreamController<String> ended = StreamController<String>.broadcast(sync: true);
  final StreamController<Duration> durations = StreamController<Duration>.broadcast(sync: true);
  @override
  Stream<String> get soundEnded => ended.stream;
  @override
  Stream<Duration> get mediaDurations => durations.stream;
  @override
  Stream<void> get mediaCompleted => completed.stream;
  @override
  Future<void> dispose() async {
    await completed.close();
    await ended.close();
    await durations.close();
  }
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

  test('the music volume follows the session, on a curve that gets quiet fast', () {
    host.dispatch(const SetMusicVolume(40));
    expect(backend.log, ['volume ${sliderGain(40)}']);
    expect(host.state.musicVolume, 40);
  });

  test('the sliders run in decibels: full at the top, a hundredth at the bottom, silent at zero', () {
    expect(sliderGain(100), 1);
    expect(sliderGain(0), 0);
    expect(sliderGain(50), closeTo(0.1, 1e-9));
    expect(sliderGain(5), lessThan(0.02));
    expect(sliderGain(1), closeTo(0.01, 0.001));
    for (var i = 1; i <= 100; i++) {
      expect(sliderGain(i), greaterThan(sliderGain(i - 1)));
    }
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

  test('a clip is started like the music but played by the big screen, so no sound plays for it', () async {
    final clipHost = SessionHost(
      initial: fixtureState(),
      game: GameContent.assemble(
        id: 'game',
        game: {'name': 'Clips'},
        groups: {'g1': {'name': 'Round 1', 'categoryGroupType': 'category_wheel', 'categoryGroupIndex': 0}},
        categories: {'c1': {'name': 'Films', 'categoryGroup': 'g1', 'categoryIndex': 0, 'active': true}},
        questions: {
          'c1': {
            'clip': {'type': 'free', 'question': 'Which film?', 'video': 'clip.mp4', 'music': 'song.mp3', 'pointsPlus': 100},
          },
        },
      ),
    );
    final clipBackend = FakeBackend();
    final clipDirector = AudioDirector(host: clipHost, backend: clipBackend, resolve: (gameId, name) => '/$gameId/$name');
    const clip = QuestionRef('c1', 'clip');
    expect(clipHost.game!.question(clip)!.mediaPaths, contains('clip.mp4'));
    clipHost.dispatch(const OpenQuestion(clip));
    expect(clipHost.dispatch(const SetMedia(MediaPlayback.playing)), isTrue);
    expect(clipHost.state.media, MediaPlayback.playing);
    expect(clipBackend.log.where((line) => line.startsWith('media /')), isEmpty);
    expect(clipHost.dispatch(const SetMedia(MediaPlayback.paused)), isTrue);
    await clipDirector.dispose();
    await clipHost.dispose();
  });

  test('an effect started by hand is listed while it sounds, and the same chip stops it', () {
    host.dispatch(const PlayEffect('airhorn'));
    expect(host.state.effectsPlaying, ['airhorn']);
    expect(backend.held, ['airhorn']);
    expect(host.dispatch(const StopEffect('airhorn')), isTrue);
    expect(backend.stopped, ['airhorn']);
    expect(host.state.effectsPlaying, isEmpty);

    // Played to its end: the chip goes out by itself.
    host.dispatch(const PlayEffect('airhorn'));
    backend.ended.add('airhorn');
    expect(host.state.effectsPlaying, isEmpty);
  });

  test('effects the show plays by itself are not listed; buzzers play at full volume', () {
    host
      ..dispatch(const OpenQuestion(free))
      ..dispatch(const Buzz('red'));
    expect(backend.held, isEmpty);
    expect(host.state.effectsPlaying, isEmpty);
    expect(backend.unscaled, ['sounds/buzzers/buzzer.wav']);
  });

  test('an effect with nothing to play goes out again at once', () async {
    host.dispatch(const PlayEffect('no such sound'));
    await pumpEventQueue();
    expect(host.state.effectsPlaying, isEmpty);
  });

  test('effects listed from before this device took over are cleared', () async {
    final stale = SessionHost(initial: fixtureState().copyWith(effectsPlaying: ['airhorn']), game: fixtureGame());
    final staleDirector = AudioDirector(host: stale, backend: FakeBackend(), resolve: (gameId, name) => '/$gameId/$name');
    await pumpEventQueue();
    expect(stale.state.effectsPlaying, isEmpty);
    await staleDirector.dispose();
    await stale.dispose();
  });

  test('the effects have a volume of their own', () {
    host.dispatch(const SetEffectsVolume(50));
    expect(backend.extra, ['effects ${sliderGain(50)}']);
    expect(Command.fromJson(const SetEffectsVolume(50).toJson()), isA<SetEffectsVolume>());
  });

  test("the question's sound: its place on the host's clock, moved and turned down from the controller", () async {
    await director.dispose();
    var now = 1000;
    host = SessionHost(initial: fixtureState(), game: fixtureGame(), clock: () => now);
    backend = FakeBackend();
    director = AudioDirector(host: host, backend: backend, resolve: (gameId, name) => '/$gameId/$name');
    host
      ..dispatch(const OpenQuestion(song))
      ..dispatch(const SetMedia(MediaPlayback.playing));
    expect(host.state.mediaClock, const MediaClock(sinceMillis: 1000));
    backend.durations.add(const Duration(seconds: 10));
    expect(host.state.mediaClock!.durationMs, 10000);

    now = 4000;
    host.dispatch(const SetMedia(MediaPlayback.paused));
    expect(host.state.mediaClock, const MediaClock(positionMs: 3000, durationMs: 10000));

    expect(host.dispatch(const SeekMedia(7000)), isTrue);
    expect(backend.extra, ['seek 7000']);
    now = 5000;
    host.dispatch(const SetMedia(MediaPlayback.playing));
    expect(host.state.mediaClock!.positionAt(6000), 8000);
    expect(host.state.mediaClock!.positionAt(99000), 10000, reason: 'no further than its end');
    expect(host.dispatch(const SeekMedia(60000)), isTrue);
    expect(host.state.mediaClock!.positionMs, 10000);

    host.dispatch(const SetMediaVolume(40));
    expect(backend.extra.last, 'media volume ${sliderGain(40)}');

    host.dispatch(const CloseQuestion());
    expect(host.state.mediaClock, isNull);
    expect(host.dispatch(const SeekMedia(1000)), isFalse, reason: 'nothing to move');
    final json = SessionState.fromJson(
      fixtureState().copyWith(mediaClock: const MediaClock(positionMs: 5, sinceMillis: 6, durationMs: 7)).toJson(),
    );
    expect(json.mediaClock, const MediaClock(positionMs: 5, sinceMillis: 6, durationMs: 7));
  });

  test('the music waits for the question sound, a video card and a team answering, and comes back after', () {
    host
      ..dispatch(const SetMusic(musicBackground))
      ..dispatch(const OpenQuestion(song))
      ..dispatch(const SetMedia(MediaPlayback.playing));
    expect(backend.holds, [true]);
    expect(host.state.music, musicBackground, reason: 'still chosen');
    host.dispatch(const SetMedia(MediaPlayback.stopped));
    expect(backend.holds, [true, false]);
    // A buzz: held while the team answers, back once it is judged.
    host.dispatch(const Buzz('red'));
    expect(backend.holds.last, isTrue);
    host.dispatch(const Judge(correct: false));
    expect(backend.holds.last, isTrue, reason: "the question's sound goes on after a wrong answer");
    host.dispatch(const SetMedia(MediaPlayback.stopped));
    expect(backend.holds.last, isFalse);
    host.dispatch(const ShowCard(OverlayCard(video: 'intro.mp4')));
    expect(backend.holds.last, isTrue);
    host.dispatch(const HideCard());
    expect(backend.holds.last, isFalse);
    expect(backend.log.where((line) => line.startsWith('music')), ['music /game/bg.mp3'], reason: 'never stopped or started over');
  });

  test('a question without a sound of its own leaves the music playing', () {
    host
      ..dispatch(const SetMusic(musicBackground))
      ..dispatch(const OpenQuestion(free))
      ..dispatch(const Reveal(1));
    expect(backend.holds, isEmpty);
    expect(host.state.music, musicBackground);
  });
}
