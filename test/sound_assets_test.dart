import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/game.dart';

/// Every sound shipped with the app must have a known source, and every
/// built-in sound the code names must be there.
void main() {
  final credits = File('assets/sounds/CREDITS.md').readAsStringSync();
  final files = Directory('assets/sounds')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => RegExp(r'\.(mp3|ogg|wav)$').hasMatch(f.path))
      .map((f) => f.path.replaceAll('\\', '/').replaceFirst('assets/sounds/', ''))
      .toList();

  test('each sound file is named in CREDITS.md', () {
    expect(files, isNotEmpty);
    for (final file in files) {
      final name = file.split('/').last;
      expect(credits.contains(name), isTrue, reason: '$file has no entry in assets/sounds/CREDITS.md');
    }
  });

  test('every built-in sound and buzzer points at a file that exists', () {
    for (final sound in [...builtinSounds, ...builtinBuzzers]) {
      expect(File('assets/${sound.asset}').existsSync(), isTrue, reason: '${sound.id}: assets/${sound.asset}');
    }
    for (final asset in ambienceAssets.values) {
      expect(File('assets/$asset').existsSync(), isTrue, reason: asset);
    }
    for (final id in defaultEffectSounds.values) {
      expect(builtinSound(id), isNotNull, reason: id);
    }
  });
}
