import 'dart:io';
import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Content type by file extension. The storage rules only accept image, audio
/// and video uploads, so every upload names its type explicitly.
const Map<String, String> _contentTypes = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'bmp': 'image/bmp',
  'mp3': 'audio/mpeg',
  'wav': 'audio/wav',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'ogg': 'audio/ogg',
  'flac': 'audio/flac',
  'mp4': 'video/mp4',
  'm4v': 'video/mp4',
  'mov': 'video/quicktime',
  'webm': 'video/webm',
  'mkv': 'video/x-matroska',
};

String? contentTypeForPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return null;
  return _contentTypes[path.substring(dot + 1).toLowerCase()];
}

/// A new media file name: random, so it cannot be guessed, keeping the
/// extension of [sourcePath].
String newMediaName(String sourcePath, {Random? random}) {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = random ?? Random.secure();
  final id = String.fromCharCodes([for (var i = 0; i < 20; i++) alphabet.codeUnitAt(rng.nextInt(alphabet.length))]);
  final name = sourcePath.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  return dot < 0 ? id : '$id.${name.substring(dot + 1).toLowerCase()}';
}

/// Game media: files live in storage under `game_{gameId}/` and are mirrored
/// into the app's support directory, where every widget reads them from.
class MediaService {
  MediaService._();

  static final MediaService instance = MediaService._();

  Directory? _root;
  final Map<String, Future<void>> _downloads = {};

  /// Call once before using [localFile]; cheap to call again.
  Future<void> init() async => _root ??= await getApplicationSupportDirectory();

  Reference _remote(String gameId, String name) => FirebaseStorage.instance.ref('game_$gameId/$name');

  /// Where [name] is, or will be, cached. Requires [init].
  File localFile(String gameId, String name) => File('${_root!.path}/$gameId/$name');

  /// Uploads the file at [sourcePath] and returns the name to store in the
  /// document. Throws when the file type is not supported.
  Future<String> upload(String gameId, String sourcePath) async {
    await init();
    final contentType = contentTypeForPath(sourcePath);
    if (contentType == null) throw UnsupportedError('This file type is not supported.');
    final name = newMediaName(sourcePath);
    await _remote(gameId, name).putFile(File(sourcePath), SettableMetadata(contentType: contentType));
    final local = localFile(gameId, name);
    await local.parent.create(recursive: true);
    await File(sourcePath).copy(local.path);
    return name;
  }

  /// Removes a file that no document refers to any more. Best effort.
  Future<void> delete(String gameId, String name) async {
    await init();
    try {
      await _remote(gameId, name).delete();
    } catch (error) {
      if (kDebugMode) print('Media: could not delete $name: $error');
    }
    final local = localFile(gameId, name);
    if (await local.exists()) await local.delete();
  }

  /// Downloads [name] unless it is cached already.
  Future<void> ensureCached(String gameId, String name) {
    return _downloads.putIfAbsent('$gameId/$name', () async {
      try {
        await init();
        final local = localFile(gameId, name);
        if (await local.exists()) return;
        await local.parent.create(recursive: true);
        // Download next to the target and rename, so a half-written file is
        // never mistaken for a cached one.
        final partial = File('${local.path}.part');
        await _remote(gameId, name).writeToFile(partial);
        await partial.rename(local.path);
      } finally {
        _downloads.remove('$gameId/$name');
      }
    });
  }

  /// Caches every file of a game ahead of the show. Returns the names that
  /// could not be downloaded.
  Future<List<String>> ensureAllCached(String gameId, Iterable<String> names) async {
    final failed = <String>[];
    for (final name in names) {
      try {
        await ensureCached(gameId, name);
      } catch (error) {
        if (kDebugMode) print('Media: could not download $name: $error');
        failed.add(name);
      }
    }
    return failed;
  }
}
