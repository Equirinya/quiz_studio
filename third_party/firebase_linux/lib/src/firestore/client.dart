import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:grpc/grpc.dart';

import '../auth/auth_session.dart';
import '../proto/google/firestore/v1/document.pb.dart';
import '../proto/google/firestore/v1/firestore.pbgrpc.dart';
import '../proto/google/firestore/v1/write.pb.dart';

/// Firestore's gRPC API for one database, with the signed-in user's
/// credentials on every call.
class FirestoreConnection {
  FirestoreConnection({required this.appName, required this.projectId, required this.databaseId});

  final String appName;
  final String projectId;
  final String databaseId;

  String get databaseName => 'projects/$projectId/databases/$databaseId';

  String? _emulatorHost;
  int? _emulatorPort;
  ClientChannel? _channel;
  FirestoreClient? _stub;

  void useEmulator(String host, int port) {
    if (_channel != null) {
      throw StateError('useEmulator() must be called before Firestore is used.');
    }
    _emulatorHost = host;
    _emulatorPort = port;
  }

  bool get isEmulator => _emulatorHost != null;

  FirestoreClient get stub {
    if (_stub != null) return _stub!;
    final channel = _channel = isEmulator
        ? ClientChannel(
            _emulatorHost!,
            port: _emulatorPort!,
            options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
          )
        : ClientChannel(
            FirestoreClient.defaultHost,
            options: ChannelOptions(
              credentials: const ChannelCredentials.secure(),
              proxy: _proxyFromEnvironment(),
              idleTimeout: const Duration(minutes: 5),
              keepAlive: const ClientKeepAliveOptions(pingInterval: Duration(seconds: 30), timeout: Duration(seconds: 20)),
            ),
          );
    return _stub = FirestoreClient(channel, options: CallOptions(providers: [_metadata]));
  }

  AuthSession get _auth => AuthSession.of(appName);

  Future<void> _metadata(Map<String, String> metadata, String uri) async {
    metadata['google-cloud-resource-prefix'] = databaseName;
    // As the official SDKs send it. The emulator ignores this header, but the
    // real service rejects any other form ("Mismatch between database name in
    // the request and http header").
    metadata['x-goog-request-params'] = 'database=${Uri.encodeComponent(databaseName)}';
    metadata['x-goog-api-client'] = 'gl-dart/${Platform.version.split(' ').first} fire/linux grpc/dart';
    String? token;
    try {
      token = await _auth.idToken();
    } on Exception {
      // Signed out meanwhile, or no network for the refresh: the call goes
      // out unauthenticated, and the rules decide.
    }
    if (token != null) {
      metadata['authorization'] = 'Bearer $token';
    } else if (isEmulator) {
      metadata['authorization'] = 'Bearer owner';
    }
  }

  /// Runs [call], once more with a fresh token if the first was refused as
  /// unauthenticated, and again on brief outages for [idempotent] calls.
  Future<T> run<T>(Future<T> Function() call, {bool idempotent = true}) async {
    var refreshed = false;
    for (var attempt = 0;; attempt++) {
      try {
        return await call();
      } on GrpcError catch (e) {
        if (e.code == StatusCode.unauthenticated && !refreshed && _auth.user != null) {
          refreshed = true;
          try {
            await _auth.idToken(forceRefresh: true);
          } on Exception {
            throw firestoreException(e);
          }
          continue;
        }
        if (idempotent && e.code == StatusCode.unavailable && attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 300 * pow(2, attempt).toInt()));
          continue;
        }
        throw firestoreException(e);
      }
    }
  }

  Future<CommitResponse> commit(List<Write> writes) =>
      run(() => stub.commit(CommitRequest(database: databaseName, writes: writes)));

  Future<void> shutdown() async {
    final channel = _channel;
    _channel = null;
    _stub = null;
    await channel?.shutdown();
  }
}

Proxy? _proxyFromEnvironment() {
  final env = Platform.environment;
  final value = env['https_proxy'] ?? env['HTTPS_PROXY'] ?? env['all_proxy'] ?? env['ALL_PROXY'];
  if (value == null || value.isEmpty) return null;
  final noProxy = (env['no_proxy'] ?? env['NO_PROXY'] ?? '').split(',').map((s) => s.trim());
  if (noProxy.any((h) => h == '*' || (h.isNotEmpty && FirestoreClient.defaultHost.endsWith(h.replaceFirst(RegExp(r'^\*?\.?'), ''))))) {
    return null;
  }
  final uri = Uri.tryParse(value.contains('://') ? value : 'http://$value');
  if (uri == null || uri.host.isEmpty) return null;
  final user = uri.userInfo.split(':');
  return Proxy(
    host: uri.host,
    port: uri.hasPort ? uri.port : 80,
    username: uri.userInfo.isEmpty ? null : Uri.decodeComponent(user.first),
    password: user.length > 1 ? Uri.decodeComponent(user.sublist(1).join(':')) : null,
  );
}

/// A gRPC status as the FirebaseException cloud_firestore throws elsewhere.
FirebaseException firestoreException(Object error) {
  if (error is FirebaseException) return error;
  if (error is GrpcError) {
    final code = switch (error.code) {
      StatusCode.cancelled => 'cancelled',
      StatusCode.invalidArgument => 'invalid-argument',
      StatusCode.deadlineExceeded => 'deadline-exceeded',
      StatusCode.notFound => 'not-found',
      StatusCode.alreadyExists => 'already-exists',
      StatusCode.permissionDenied => 'permission-denied',
      StatusCode.resourceExhausted => 'resource-exhausted',
      StatusCode.failedPrecondition => 'failed-precondition',
      StatusCode.aborted => 'aborted',
      StatusCode.outOfRange => 'out-of-range',
      StatusCode.unimplemented => 'unimplemented',
      StatusCode.internal => 'internal',
      StatusCode.unavailable => 'unavailable',
      StatusCode.dataLoss => 'data-loss',
      StatusCode.unauthenticated => 'unauthenticated',
      _ => 'unknown',
    };
    return FirebaseException(plugin: 'cloud_firestore', code: code, message: error.message);
  }
  return FirebaseException(plugin: 'cloud_firestore', code: 'unknown', message: '$error');
}

/// The documents [names] as they are now on the server; null for missing.
Future<Map<String, Document?>> batchGet(FirestoreConnection connection, List<String> names) => connection.run(() async {
      final result = <String, Document?>{};
      final responses = connection.stub.batchGetDocuments(
        BatchGetDocumentsRequest(database: connection.databaseName, documents: names),
      );
      await for (final response in responses) {
        if (response.hasFound()) {
          result[response.found.name] = response.found;
        } else if (response.hasMissing()) {
          result[response.missing] = null;
        }
      }
      return result;
    });
