import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage_platform_interface/firebase_storage_platform_interface.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';
import '../http.dart';

/// firebase_storage for Linux over the Firebase Storage REST API
/// (`firebasestorage.googleapis.com/v0`), the one the web SDK uses.
class LinuxFirebaseStorage extends FirebaseStoragePlatform {
  LinuxFirebaseStorage({super.appInstance, required super.bucket});

  static final Map<String, LinuxFirebaseStorage> _instances = {};

  int _maxOperationRetryTime = 120000;
  int _maxUploadRetryTime = 600000;
  int _maxDownloadRetryTime = 600000;

  @override
  FirebaseStoragePlatform delegateFor({required FirebaseApp app, required String bucket}) =>
      _instances.putIfAbsent('${app.name}|$bucket', () => LinuxFirebaseStorage(appInstance: app, bucket: bucket));

  @override
  int get maxOperationRetryTime => _maxOperationRetryTime;

  @override
  int get maxUploadRetryTime => _maxUploadRetryTime;

  @override
  int get maxDownloadRetryTime => _maxDownloadRetryTime;

  @override
  void setMaxOperationRetryTime(int time) => _maxOperationRetryTime = time;

  @override
  void setMaxUploadRetryTime(int time) => _maxUploadRetryTime = time;

  @override
  void setMaxDownloadRetryTime(int time) => _maxDownloadRetryTime = time;

  @override
  Future<void> useStorageEmulator(String host, int port) async {
    emulatorHost = host;
    emulatorPort = port;
  }

  @override
  ReferencePlatform ref(String path) => LinuxReference(this, path);

  String get _origin =>
      emulatorHost == null ? 'https://firebasestorage.googleapis.com' : 'http://$emulatorHost:$emulatorPort';

  String get _bucketName => bucket.replaceFirst(RegExp(r'^gs://'), '').replaceAll(RegExp(r'/+$'), '');

  Uri objectUri(String path, [Map<String, String>? query]) => Uri.parse(
        '$_origin/v0/b/${Uri.encodeComponent(_bucketName)}/o/${Uri.encodeComponent(path)}',
      ).replace(queryParameters: query);

  Uri bucketUri([Map<String, String>? query]) =>
      Uri.parse('$_origin/v0/b/${Uri.encodeComponent(_bucketName)}/o').replace(queryParameters: query);

  Future<Map<String, String>> headers([Map<String, String>? extra]) async {
    String? token;
    try {
      token = await AuthSession.of(app.name).idToken();
    } on Exception {
      // Unauthenticated then; the rules decide.
    }
    return {
      'x-firebase-storage-version': 'linux/dart',
      if (token != null) 'authorization': 'Firebase $token',
      ...?extra,
    };
  }

  /// Sends a request, retrying on network errors and 5xx/429 answers with
  /// backoff until [retryTime] (milliseconds) has passed.
  Future<http.StreamedResponse> send(
    Future<http.BaseRequest> Function() build, {
    required int retryTime,
    bool Function()? canceled,
  }) async {
    final deadline = DateTime.now().add(Duration(milliseconds: retryTime));
    for (var attempt = 0;; attempt++) {
      if (canceled?.call() ?? false) throw storageException('canceled', 'The operation was canceled.');
      http.StreamedResponse? response;
      Object? failure;
      try {
        response = await httpClient.send(await build()).timeout(const Duration(minutes: 2));
      } catch (error) {
        if (!(isNetworkError(error) || error is TimeoutException)) rethrow;
        failure = error;
      }
      final retry = failure != null || response!.statusCode >= 500 || response.statusCode == 429;
      if (!retry) {
        if (response.statusCode >= 200 && response.statusCode < 300) return response;
        throw await _error(response);
      }
      await response?.stream.drain<void>();
      final wait = Duration(milliseconds: min(30000, 500 * pow(2, attempt).toInt()));
      if (DateTime.now().add(wait).isAfter(deadline)) {
        if (failure != null) throw storageException('retry-limit-exceeded', 'No connection to Storage: $failure');
        throw await _error(response!);
      }
      await Future<void>.delayed(wait);
    }
  }

  static Future<FirebaseException> _error(http.StreamedResponse response) async {
    final body = await response.stream.bytesToString().catchError((_) => '');
    String? message;
    try {
      final json = jsonDecode(body);
      if (json is Map && json['error'] is Map) message = '${json['error']['message']}';
    } on FormatException {
      message = body.isEmpty ? null : body;
    }
    final code = switch (response.statusCode) {
      400 => 'invalid-argument',
      401 => 'unauthenticated',
      402 || 429 => 'quota-exceeded',
      403 => 'unauthorized',
      404 => 'object-not-found',
      409 => 'invalid-argument',
      412 => 'invalid-argument',
      _ => 'unknown',
    };
    return storageException(code, message ?? 'HTTP ${response.statusCode}');
  }
}

FirebaseException storageException(String code, String message) =>
    FirebaseException(plugin: 'firebase_storage', code: code, message: message);

class LinuxReference extends ReferencePlatform {
  LinuxReference(LinuxFirebaseStorage super.storage, super.path);

  LinuxFirebaseStorage get _storage => storage as LinuxFirebaseStorage;

  Future<Map<String, dynamic>> _json(Future<http.BaseRequest> Function() build) async {
    final response = await _storage.send(build, retryTime: _storage.maxOperationRetryTime);
    final body = await response.stream.bytesToString();
    return body.isEmpty ? const {} : Map<String, dynamic>.from(jsonDecode(body) as Map);
  }

  Future<http.Request> _request(String method, Uri uri, [Map<String, String>? extra]) async =>
      http.Request(method, uri)..headers.addAll(await _storage.headers(extra));

  @override
  Future<void> delete() async {
    final response = await _storage.send(
      () => _request('DELETE', _storage.objectUri(fullPath)),
      retryTime: _storage.maxOperationRetryTime,
    );
    await response.stream.drain<void>();
  }

  @override
  Future<FullMetadata> getMetadata() async =>
      fullMetadata(await _json(() => _request('GET', _storage.objectUri(fullPath))));

  @override
  Future<FullMetadata> updateMetadata(SettableMetadata metadata) async {
    final json = await _json(() async {
      return (await _request('PATCH', _storage.objectUri(fullPath), {'content-type': 'application/json; charset=utf-8'}))
        ..body = jsonEncode(_metadataJson(metadata, includeNulls: true));
    });
    return fullMetadata(json);
  }

  @override
  Future<String> getDownloadURL() async {
    final json = await _json(() => _request('GET', _storage.objectUri(fullPath)));
    final tokens = '${json['downloadTokens'] ?? ''}'.split(',').where((t) => t.isNotEmpty);
    if (tokens.isEmpty) {
      throw storageException('no-download-url', 'The object has no download URL.');
    }
    return _storage.objectUri(fullPath, {'alt': 'media', 'token': tokens.first}).toString();
  }

  @override
  Future<ListResultPlatform> list([ListOptions? options]) async {
    final prefix = fullPath.isEmpty || fullPath == '/' ? '' : '$fullPath/';
    final json = await _json(() => _request(
          'GET',
          _storage.bucketUri({
            'prefix': prefix,
            'delimiter': '/',
            if (options?.maxResults != null) 'maxResults': '${options!.maxResults}',
            if (options?.pageToken != null) 'pageToken': options!.pageToken!,
          }),
        ));
    return LinuxListResult(
      _storage,
      json['nextPageToken'] as String?,
      items: [for (final item in (json['items'] as List? ?? const [])) _storage.ref('${(item as Map)['name']}')],
      prefixes: [
        for (final p in (json['prefixes'] as List? ?? const [])) _storage.ref('$p'.replaceAll(RegExp(r'/$'), '')),
      ],
    );
  }

  @override
  Future<ListResultPlatform> listAll() async {
    final items = <ReferencePlatform>[];
    final prefixes = <ReferencePlatform>[];
    String? token;
    do {
      final page = await list(ListOptions(pageToken: token));
      items.addAll(page.items);
      prefixes.addAll(page.prefixes);
      token = page.nextPageToken;
    } while (token != null);
    return LinuxListResult(_storage, null, items: items, prefixes: prefixes);
  }

  @override
  Future<Uint8List?> getData(int maxSize) async {
    final response = await _storage.send(
      () => _request('GET', _storage.objectUri(fullPath, {'alt': 'media'})),
      retryTime: _storage.maxDownloadRetryTime,
    );
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      builder.add(chunk);
      if (builder.length > maxSize) {
        throw storageException('download-size-exceeded', 'The object is larger than $maxSize bytes.');
      }
    }
    return builder.takeBytes();
  }

  @override
  TaskPlatform putData(Uint8List data, [SettableMetadata? metadata]) =>
      LinuxTask.upload(this, () async => data, metadata);

  @override
  TaskPlatform putBlob(dynamic data, [SettableMetadata? metadata]) =>
      throw UnsupportedError('putBlob() is only available on the web.');

  @override
  TaskPlatform putFile(File file, [SettableMetadata? metadata]) {
    metadata ??= SettableMetadata(contentType: _guessType(file.path));
    return LinuxTask.upload(this, file.readAsBytes, metadata);
  }

  @override
  TaskPlatform putString(String data, PutStringFormat format, [SettableMetadata? metadata]) {
    final bytes = switch (format) {
      PutStringFormat.raw => utf8.encode(data),
      PutStringFormat.base64 => base64.decode(data),
      PutStringFormat.base64Url => base64Url.decode(base64Url.normalize(data)),
      PutStringFormat.dataUrl => UriData.parse(data).contentAsBytes(),
    };
    if (format == PutStringFormat.dataUrl && metadata?.contentType == null) {
      final type = UriData.parse(data).mimeType;
      metadata = SettableMetadata(
        contentType: type,
        cacheControl: metadata?.cacheControl,
        contentDisposition: metadata?.contentDisposition,
        contentEncoding: metadata?.contentEncoding,
        contentLanguage: metadata?.contentLanguage,
        customMetadata: metadata?.customMetadata,
      );
    }
    return putData(Uint8List.fromList(bytes), metadata);
  }

  @override
  TaskPlatform writeToFile(File file) => LinuxTask.download(this, file);

  static String? _guessType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return const {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'm4a': 'audio/mp4',
      'mp4': 'video/mp4',
      'json': 'application/json',
      'txt': 'text/plain',
    }[ext];
  }
}

Map<String, Object?> _metadataJson(SettableMetadata? metadata, {bool includeNulls = false}) {
  final json = <String, Object?>{
    'cacheControl': metadata?.cacheControl,
    'contentDisposition': metadata?.contentDisposition,
    'contentEncoding': metadata?.contentEncoding,
    'contentLanguage': metadata?.contentLanguage,
    'contentType': metadata?.contentType,
    'metadata': metadata?.customMetadata,
  };
  if (!includeNulls) json.removeWhere((_, v) => v == null);
  return json;
}

/// The REST API's object resource as FullMetadata.
FullMetadata fullMetadata(Map<String, dynamic> json) => FullMetadata(metadataMap(json));

/// The REST API's object resource in the map form FullMetadata reads.
Map<String, dynamic> metadataMap(Map<String, dynamic> json) {
  int? millis(Object? time) => time == null ? null : DateTime.tryParse('$time')?.millisecondsSinceEpoch;
  final name = json['name'] as String?;
  return {
    'bucket': json['bucket'],
    'fullPath': name,
    'name': name?.split('/').last,
    'generation': json['generation'],
    'metadataGeneration': json['metageneration'],
    'metageneration': json['metageneration'],
    'md5Hash': json['md5Hash'],
    'size': int.tryParse('${json['size']}'),
    'creationTimeMillis': millis(json['timeCreated']),
    'updatedTimeMillis': millis(json['updated']),
    'contentType': json['contentType'],
    'cacheControl': json['cacheControl'],
    'contentDisposition': json['contentDisposition'],
    'contentEncoding': json['contentEncoding'],
    'contentLanguage': json['contentLanguage'],
    'customMetadata': json['metadata'] == null ? null : Map<String, String>.from(json['metadata'] as Map),
  };
}

class LinuxListResult extends ListResultPlatform {
  LinuxListResult(super.storage, super.nextPageToken, {required this.items, required this.prefixes});

  @override
  final List<ReferencePlatform> items;

  @override
  final List<ReferencePlatform> prefixes;
}

class LinuxTaskSnapshot extends TaskSnapshotPlatform {
  LinuxTaskSnapshot(this._ref, TaskState state, Map<String, dynamic> data) : super(state, data);

  final ReferencePlatform _ref;

  @override
  ReferencePlatform get ref => _ref;
}

/// An upload or download. It starts at once; pausing is not supported, and
/// cancel takes effect between retries and chunks.
class LinuxTask extends TaskPlatform {
  LinuxTask._(this._ref) {
    _snapshot = LinuxTaskSnapshot(_ref, TaskState.running, {'bytesTransferred': 0, 'totalBytes': 0});
  }

  factory LinuxTask.upload(LinuxReference ref, Future<Uint8List> Function() read, SettableMetadata? metadata) =>
      LinuxTask._(ref).._run((task) => _upload(task, ref, read, metadata));

  factory LinuxTask.download(LinuxReference ref, File file) => LinuxTask._(ref).._run((task) => _download(task, ref, file));

  final LinuxReference _ref;
  late LinuxTaskSnapshot _snapshot;
  final _events = StreamController<TaskSnapshotPlatform>.broadcast();
  final _done = Completer<TaskSnapshotPlatform>();
  bool _canceled = false;

  void _update(TaskState state, int transferred, int total, [Map<String, dynamic>? metadata]) {
    _snapshot = LinuxTaskSnapshot(_ref, state, {
      'bytesTransferred': transferred,
      'totalBytes': total,
      'metadata': ?metadata,
    });
    _events.add(_snapshot);
  }

  void _run(Future<void> Function(LinuxTask task) work) {
    // Let callers subscribe to the events before the first one.
    scheduleMicrotask(() async {
      try {
        await work(this);
        _done.complete(_snapshot);
      } catch (error, stack) {
        final canceled = _canceled;
        _update(canceled ? TaskState.canceled : TaskState.error, _snapshot.bytesTransferred, _snapshot.totalBytes);
        final exception = error is FirebaseException
            ? error
            : storageException(canceled ? 'canceled' : 'unknown', '$error');
        _events.addError(exception, stack);
        _done.completeError(exception, stack);
      } finally {
        await _events.close();
      }
    });
    // An error nobody awaits must not end up as an unhandled one.
    _done.future.ignore();
  }

  static Future<void> _upload(
    LinuxTask task,
    LinuxReference ref,
    Future<Uint8List> Function() read,
    SettableMetadata? metadata,
  ) async {
    final bytes = await read();
    task._update(TaskState.running, 0, bytes.length);
    final storage = ref._storage;
    final boundary = 'linux${Random.secure().nextInt(1 << 32)}${DateTime.now().microsecondsSinceEpoch}';
    final head = utf8.encode(
      '--$boundary\r\ncontent-type: application/json; charset=utf-8\r\n\r\n'
      '${jsonEncode({'name': ref.fullPath, ..._metadataJson(metadata)})}\r\n'
      '--$boundary\r\ncontent-type: ${metadata?.contentType ?? 'application/octet-stream'}\r\n\r\n',
    );
    final tail = utf8.encode('\r\n--$boundary--');
    final body = Uint8List(head.length + bytes.length + tail.length)
      ..setAll(0, head)
      ..setAll(head.length, bytes)
      ..setAll(head.length + bytes.length, tail);
    final response = await storage.send(
      () async => http.Request('POST', storage.bucketUri({'name': ref.fullPath}))
        ..headers.addAll(await storage.headers({
          'content-type': 'multipart/related; boundary=$boundary',
          'x-goog-upload-protocol': 'multipart',
        }))
        ..bodyBytes = body,
      retryTime: storage.maxUploadRetryTime,
      canceled: () => task._canceled,
    );
    final json = jsonDecode(await response.stream.bytesToString());
    task._update(TaskState.success, bytes.length, bytes.length, metadataMap(Map<String, dynamic>.from(json as Map)));
  }

  static Future<void> _download(LinuxTask task, LinuxReference ref, File file) async {
    final storage = ref._storage;
    final response = await storage.send(
      () => ref._request('GET', storage.objectUri(ref.fullPath, {'alt': 'media'})),
      retryTime: storage.maxDownloadRetryTime,
      canceled: () => task._canceled,
    );
    final total = response.contentLength ?? 0;
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        if (task._canceled) throw storageException('canceled', 'The download was canceled.');
        sink.add(chunk);
        received += chunk.length;
        task._update(TaskState.running, received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    task._update(TaskState.success, received, total == 0 ? received : total);
  }

  @override
  Stream<TaskSnapshotPlatform> get snapshotEvents => _events.stream;

  @override
  TaskSnapshotPlatform get snapshot => _snapshot;

  @override
  Future<TaskSnapshotPlatform> get onComplete => _done.future;

  @override
  Future<bool> pause() async => false;

  @override
  Future<bool> resume() async => false;

  @override
  Future<bool> cancel() async {
    if (_done.isCompleted) return false;
    _canceled = true;
    return true;
  }
}
