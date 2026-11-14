import 'dart:async';

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/audio/audioplayers_backend.dart';
import 'package:quiz_show/game/game.dart';

/// Stands in for the audio of the device: notes every call by player, and
/// gets a source ready at once unless its path is in [hanging].
class _FakeAudio implements AudioplayersPlatformInterface, GlobalAudioplayersPlatformInterface {
  final calls = <(String player, String call, Object? arg)>[];
  final events = <String, StreamController<AudioEvent>>{};
  final hanging = <String>{};

  List<String> callsOf(String player) => [for (final c in calls) if (c.$1 == player) c.$3 == null ? c.$2 : '${c.$2} ${c.$3}'];

  /// The player a source was set on, in the order they were.
  List<String> get playersWithSources => [for (final c in calls) if (c.$2 == 'setSourceUrl') c.$1];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString().replaceAll('Symbol("', '').replaceAll('")', '');
    final args = invocation.positionalArguments;
    final player = args.isNotEmpty && args.first is String ? args.first as String : '';
    final arg = args.length > 1 ? args[1] : null;
    switch (name) {
      case 'getEventStream':
        return (events[player] ??= StreamController<AudioEvent>.broadcast()).stream;
      case 'getGlobalEventStream':
        return const Stream<GlobalAudioEvent>.empty();
      case 'getDuration' || 'getCurrentPosition':
        return Future<int?>.value(null);
      case 'setSourceUrl':
        calls.add((player, name, (arg as String).split('/').last));
        if (!hanging.contains(arg.split('/').last)) {
          scheduleMicrotask(() => events[player]?.add(const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true)));
        }
        return Future<void>.value();
    }
    calls.add((player, name, arg is double ? arg : null));
    return Future<void>.value();
  }

  void complete(String player) => events[player]!.add(const AudioEvent(eventType: AudioEventType.complete));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeAudio audio;
  late AudioplayersBackend backend;

  setUp(() {
    audio = _FakeAudio();
    AudioplayersPlatformInterface.instance = audio;
    GlobalAudioplayersPlatformInterface.instance = audio;
    backend = AudioplayersBackend(stepLimit: const Duration(milliseconds: 200));
  });
  tearDown(() => backend.dispose());

  test('every song gets a player of its own, set up in order and at full volume once it plays', () async {
    backend
      ..setMedia('/songs/a.mp3', MediaPlayback.playing)
      // "Next" pressed before the first song is even loaded.
      ..setMedia('/songs/b.mp3', MediaPlayback.playing);
    await backend.mediaSettled;
    await pumpEventQueue();
    final [first, second] = audio.playersWithSources;
    expect(first, isNot(second));
    expect(audio.callsOf(first), containsAllInOrder(['setSourceUrl a.mp3', 'resume', 'stop', 'release']));
    expect(audio.callsOf(second), containsAllInOrder(['setSourceUrl b.mp3', 'setVolume 1.0', 'resume', 'setVolume 1.0']));
    expect(audio.callsOf(second), isNot(contains('stop')));
  });

  test('only the song still asked for reports that it is over', () async {
    final done = <void>[];
    backend.mediaCompleted.listen(done.add);
    backend
      ..setMedia('/songs/a.mp3', MediaPlayback.playing)
      ..setMedia('/songs/b.mp3', MediaPlayback.playing);
    await backend.mediaSettled;
    final [first, second] = audio.playersWithSources;
    audio.complete(first);
    await pumpEventQueue();
    expect(done, isEmpty, reason: 'the old song ending must not stop the new one');
    audio.complete(second);
    await pumpEventQueue();
    expect(done, hasLength(1));
  });

  test('a song that never loads does not hold up the next one', () async {
    audio.hanging.add('broken.mp3');
    backend
      ..setMedia('/songs/broken.mp3', MediaPlayback.playing)
      ..setMedia('/songs/b.mp3', MediaPlayback.playing);
    await backend.mediaSettled;
    final second = audio.playersWithSources.last;
    expect(audio.callsOf(second), containsAllInOrder(['setSourceUrl b.mp3', 'resume']));
  });

  test('pause and play again stay on the same player; stopping lets it go', () async {
    backend
      ..setMedia('/songs/a.mp3', MediaPlayback.playing)
      ..setMedia('/songs/a.mp3', MediaPlayback.paused)
      ..setMedia('/songs/a.mp3', MediaPlayback.playing)
      ..setMedia(null, MediaPlayback.stopped);
    await backend.mediaSettled;
    // Let go in the background, never waited for.
    await pumpEventQueue();
    expect(audio.playersWithSources, hasLength(1));
    expect(audio.callsOf(audio.playersWithSources.single), containsAllInOrder(['resume', 'pause', 'resume', 'stop', 'release']));
  });
}
