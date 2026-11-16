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

/// A file larger than storage accepts for its kind; see
/// [MediaService.maxUploadBytes].
class UploadTooLarge implements Exception {
  const UploadTooLarge(this.maxBytes);

  final int maxBytes;

  int get maxMegabytes => maxBytes ~/ (1024 * 1024);

  @override
  String toString() => 'The file is too large: at most $maxMegabytes MB for its kind (pictures and sounds 50 MB, videos 1 GB).';
}

/// One upload under way, for progress bars anywhere in the app.
class MediaUpload {
  MediaUpload({required this.label, required this.totalBytes});

  /// The file's own name on this device, to tell the user which one it is.
  final String label;
  final int totalBytes;

  /// 0..1 of the bytes sent.
  final ValueNotifier<double> progress = ValueNotifier(0);

  /// Big enough that the upload takes a while and gets its own notice that
  /// stays on screen, whatever page is open.
  bool get large => totalBytes >= MediaService.largeUploadBytes;
}

/// Game media: files live in storage under `game_{gameId}/` and are mirrored
/// into the app's support directory, where every widget reads them from.
class MediaService {
  MediaService._();

  static final MediaService instance = MediaService._();

  Directory? _root;
  final Map<String, Future<void>> _downloads = {};

  /// The largest file storage takes for [contentType], as storage.rules
  /// say: the rules only check at the end of an upload, so the app checks
  /// first.
  static int maxUploadBytes(String contentType) =>
      contentType.startsWith('video/') ? 1024 * 1024 * 1024 : 50 * 1024 * 1024;

  /// From this size on an upload is shown in a notice of its own.
  static const int largeUploadBytes = 20 * 1024 * 1024;

  /// The uploads under way, oldest first.
  final ValueNotifier<List<MediaUpload>> uploads = ValueNotifier(const []);

  /// Whether [localFile] can be used yet.
  bool get ready => _root != null;

  /// Points the cache at [directory]. Only for rendering screens in tests.
  set debugRoot(Directory directory) => _root = directory;

  /// Call once before using [localFile]; cheap to call again.
  Future<void> init() async => _root ??= await getApplicationSupportDirectory();

  Reference _remote(String gameId, String name) => FirebaseStorage.instance.ref('game_$gameId/$name');

  /// Where [name] is, or will be, cached. Requires [init].
  File localFile(String gameId, String name) => File('${_root!.path}/$gameId/$name');

  /// Uploads the file at [sourcePath] and returns the name to store in the
  /// document. Throws when the file type is not supported.
  ///
  /// [onProgress] gets 0..1 of the bytes sent as they go.
  Future<String> upload(String gameId, String sourcePath, {ValueChanged<double>? onProgress}) async {
    await init();
    final contentType = contentTypeForPath(sourcePath);
    // Windows, where the show runs, cannot play Ogg or Opus.
    if (RegExp(r'\.(ogg|oga|opus)$', caseSensitive: false).hasMatch(sourcePath)) {
      throw UnsupportedError('Ogg sounds do not play on Windows. Please use MP3, WAV or M4A.');
    }
    if (contentType == null) throw UnsupportedError('This file type is not supported.');
    final size = await File(sourcePath).length();
    // Storage rejects the file only once all of it is sent.
    if (size >= maxUploadBytes(contentType)) throw UploadTooLarge(maxUploadBytes(contentType));
    final name = newMediaName(sourcePath);
    final upload = MediaUpload(label: sourcePath.split(RegExp(r'[/\\]')).last, totalBytes: size);
    uploads.value = [...uploads.value, upload];
    try {
      final task = _remote(gameId, name).putFile(File(sourcePath), SettableMetadata(contentType: contentType));
      final events = task.snapshotEvents.listen(
        (snapshot) {
          if (snapshot.totalBytes <= 0) return;
          upload.progress.value = (snapshot.bytesTransferred / snapshot.totalBytes).clamp(0.0, 1.0);
          onProgress?.call(upload.progress.value);
        },
        // The task itself reports the error.
        onError: (Object _) {},
      );
      try {
        await task;
      } finally {
        await events.cancel();
      }
    } finally {
      uploads.value = [...uploads.value]..remove(upload);
    }
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
