import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/audio/audio_director.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

class FakeBackend implements AudioBackend {
  final List<String> log = [];
  final StreamController<void> completed = StreamController<void>.broadcast(sync: true);

  @override
  void setMusic(String? path) => log.add('music $path');
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

  test('a slot without a file is silence', () {
    host.dispatch(const SetMusic(musicCalm));
    expect(backend.log, isEmpty);
  });

  test('the question sound plays, pauses on a buzz, resumes after a wrong answer, stops on close', () {
    host
      ..dispatch(const OpenQuestion(song))
      ..dispatch(const SetMedia(MediaPlayback.playing));
    expect(backend.log.last, 'media /game/song.mp3 playing');
    backend.log.clear();
    host.dispatch(const Buzz('red'));
    expect(backend.log, ['media /game/song.mp3 paused', 'asset buzzer.mp3']);
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

  test('effects play their file; an effect nobody set is skipped', () {
    host
      ..dispatch(const OpenQuestion(free))
      ..dispatch(const Buzz('red'))
      ..dispatch(const Judge(correct: false));
    expect(backend.log, ['asset buzzer.mp3', 'file /game/wrong.mp3']);
    backend.log.clear();
    // No "right answer" sound is configured in the fixture game.
    host
      ..dispatch(const Buzz('red'))
      ..dispatch(const Judge(correct: true));
    expect(backend.log, ['asset buzzer.mp3']);
    host.dispatch(const PlayEffect('airhorn'));
    expect(backend.log.last, 'file /game/horn.mp3');
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
