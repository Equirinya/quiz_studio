import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:quiz_show/features/games/media_service.dart';

/// A buzzer sound of its own for a team. The file lives with the session in
/// storage under `session_{sessionId}/`, so whichever device presents can
/// fetch it; the team carries its name (see `Team.sound`). The presenting
/// device plays its local copy, and the built-in buzzer for as long as it
/// has none.
class TeamSounds {
  TeamSounds._();

  static final TeamSounds instance = TeamSounds._();

  /// Storage refuses anything bigger; a buzzer sound is a few seconds.
  static const int maxBytes = 5 * 1024 * 1024;

  Directory? _root;
  final Map<String, Future<void>> _downloads = {};

  /// Call once before using [pathFor]; cheap to call again.
  Future<void> init() async => _root ??= await getApplicationSupportDirectory();

  Reference _remote(String sessionId, String name) => FirebaseStorage.instance.ref('session_$sessionId/$name');

  File _local(String sessionId, String name) => File('${_root!.path}/session_$sessionId/$name');

  /// The local copy of a team's sound, or null while this device has none:
  /// not chosen, still downloading, or out of reach.
  String? pathFor(String sessionId, String? name) {
    if (name == null || name.isEmpty || _root == null) return null;
    final file = _local(sessionId, name);
    return file.existsSync() ? file.path : null;
  }

  /// Uploads the sound at [sourcePath] and returns the name to give the
  /// team. Throws [UnsupportedError] for files that are no sound or too big.
  Future<String> upload(String sessionId, String sourcePath) async {
    await init();
    final contentType = contentTypeForPath(sourcePath);
    if (contentType == null || !contentType.startsWith('audio/')) {
      throw UnsupportedError('This is not a sound file the app can play.');
    }
    final source = File(sourcePath);
    if (await source.length() >= maxBytes) throw UnsupportedError('This file is too big; a buzzer sound can be up to 5 MB.');
    final name = newMediaName(sourcePath);
    await _remote(sessionId, name).putFile(source, SettableMetadata(contentType: contentType));
    final local = _local(sessionId, name);
    await local.parent.create(recursive: true);
    await source.copy(local.path);
    return name;
  }

  /// Fetches [name] unless this device has it already.
  Future<void> ensureCached(String sessionId, String name) {
    return _downloads.putIfAbsent('$sessionId/$name', () async {
      try {
        await init();
        final local = _local(sessionId, name);
        if (await local.exists()) return;
        await local.parent.create(recursive: true);
        final partial = File('${local.path}.part');
        await _remote(sessionId, name).writeToFile(partial);
        await partial.rename(local.path);
      } catch (error) {
        // The team keeps the default sound; the next change tries again.
        if (kDebugMode) print('Team sound $name: $error');
      } finally {
        _downloads.remove('$sessionId/$name');
      }
    });
  }

  /// Removes a sound no team uses any more. Best effort.
  Future<void> delete(String sessionId, String name) async {
    await init();
    try {
      await _remote(sessionId, name).delete();
    } catch (error) {
      if (kDebugMode) print('Team sound $name: $error');
    }
    final local = _local(sessionId, name);
    if (await local.exists()) await local.delete();
  }
}
