import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:collection/collection.dart';
import 'package:firebase_core/firebase_core.dart';

import '../proto/google/firestore/v1/document.pb.dart';
import '../proto/google/firestore/v1/firestore.pb.dart';
import '../proto/google/firestore/v1/write.pb.dart';
import 'client.dart';
import 'queries.dart';
import 'values.dart';
import 'watch.dart';
import 'writes.dart';

final _serverMetadata = InternalSnapshotMetadata(hasPendingWrites: false, isFromCache: false);

/// cloud_firestore for Linux, straight to Firestore's gRPC API. There is no
/// local cache: reads go to the server, listeners get the server's view
/// (a moment after a local write, not instantly), and writes fail while
/// offline instead of waiting in a queue.
class LinuxFirebaseFirestore extends FirebaseFirestorePlatform {
  LinuxFirebaseFirestore({super.appInstance, super.databaseChoice});

  static final Map<String, LinuxFirebaseFirestore> _instances = {};

  late final FirestoreConnection connection = FirestoreConnection(
    appName: app.name,
    projectId: app.options.projectId,
    databaseId: databaseId,
  );
  late final ValueCodec codec = ValueCodec(this, connection.databaseName);
  late final WriteBuilder writes = WriteBuilder(codec);
  late final Watch watch = Watch(connection);

  Settings _settings = const Settings();

  @override
  FirebaseFirestorePlatform delegateFor({required FirebaseApp app, required String databaseId}) =>
      _instances.putIfAbsent(
        '${app.name}/$databaseId',
        () => LinuxFirebaseFirestore(appInstance: app, databaseChoice: databaseId),
      );

  @override
  Settings get settings => _settings;

  @override
  set settings(Settings settings) {
    _settings = settings;
    final host = settings.host;
    if (host != null && settings.sslEnabled == false) {
      final parts = host.split(':');
      connection.useEmulator(parts.first, parts.length > 1 ? int.parse(parts.last) : 8080);
    }
  }

  @override
  void useEmulator(String host, int port) => connection.useEmulator(host, port);

  @override
  CollectionReferencePlatform collection(String collectionPath) => LinuxCollectionReference(this, collectionPath);

  @override
  QueryPlatform collectionGroup(String collectionPath) =>
      LinuxQuery(this, collectionPath, isCollectionGroupQuery: true);

  @override
  DocumentReferencePlatform doc(String documentPath) => LinuxDocumentReference(this, documentPath);

  @override
  WriteBatchPlatform batch() => LinuxWriteBatch(this);

  @override
  Future<T?> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final deadline = DateTime.now().add(timeout);
    for (var attempt = 1;; attempt++) {
      final begin = await connection.run(() => connection.stub.beginTransaction(
            BeginTransactionRequest(database: connection.databaseName),
          ));
      final transaction = LinuxTransaction(this, begin.transaction);
      try {
        final result = await transactionHandler(transaction);
        await connection.run(
          () => connection.stub.commit(CommitRequest(
            database: connection.databaseName,
            writes: transaction._writes,
            transaction: begin.transaction,
          )),
          idempotent: false,
        );
        return result;
      } on FirebaseException catch (e) {
        unawaited(connection.stub
            .rollback(RollbackRequest(database: connection.databaseName, transaction: begin.transaction))
            .then((_) {}, onError: (_) {}));
        final retry = const {'aborted', 'unavailable', 'failed-precondition'}.contains(e.code);
        if (!retry || attempt >= maxAttempts || DateTime.now().isAfter(deadline)) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 100 * pow(2, attempt).toInt()));
      }
    }
  }

  @override
  Future<void> clearPersistence() async {}

  @override
  Future<void> enableNetwork() async {}

  @override
  Future<void> disableNetwork() async {}

  @override
  Future<void> waitForPendingWrites() async {}

  @override
  Future<void> setLoggingEnabled(bool enabled) async {}

  @override
  Future<void> terminate() async {
    await watch.dispose();
    await connection.shutdown();
    _instances.removeWhere((_, instance) => identical(instance, this));
  }

  @override
  Stream<void> snapshotsInSync() => const Stream.empty();

  DocumentSnapshotPlatform snapshotOf(String path, Document? document) => DocumentSnapshotPlatform(
        this,
        path,
        document == null ? null : codec.decodeMap(document.fields),
        _serverMetadata,
      );
}

/// A collection is also its own unfiltered query, as in the method channel
/// implementation.
class LinuxCollectionReference extends LinuxQuery implements CollectionReferencePlatform {
  LinuxCollectionReference(LinuxFirebaseFirestore firestore, String path)
      : super(firestore, path.replaceAll(RegExp(r'^/+|/+$'), ''));

  static final _random = Random.secure();
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  /// A 20-character ID, as the native SDKs make them.
  static String autoId() => String.fromCharCodes(
        List.generate(20, (_) => _alphabet.codeUnitAt(_random.nextInt(_alphabet.length))),
      );

  @override
  String get id => path.split('/').last;

  @override
  DocumentReferencePlatform? get parent {
    final segments = path.split('/');
    return segments.length < 2 ? null : _firestore.doc(segments.sublist(0, segments.length - 1).join('/'));
  }

  @override
  DocumentReferencePlatform doc([String? path]) =>
      LinuxDocumentReference(_firestore, '${this.path}/${path ?? autoId()}');

  @override
  bool operator ==(Object other) => other is LinuxCollectionReference && other._firestore == _firestore && other.path == path;

  @override
  int get hashCode => Object.hash(_firestore, path);
}

class LinuxDocumentReference extends DocumentReferencePlatform {
  LinuxDocumentReference(this._firestore, String path) : super(_firestore, path);

  final LinuxFirebaseFirestore _firestore;

  FirestoreConnection get _connection => _firestore.connection;

  @override
  Future<void> delete() => _connection.commit([_firestore.writes.delete(path)]);

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) =>
      _connection.commit([_firestore.writes.set(path, data, options)]);

  @override
  Future<void> update(Map<FieldPath, dynamic> data) => _connection.commit([_firestore.writes.update(path, data)]);

  @override
  Future<DocumentSnapshotPlatform> get([GetOptions options = const GetOptions()]) async {
    final name = _firestore.codec.name(path);
    final docs = await batchGet(_connection, [name]);
    return _firestore.snapshotOf(path, docs[name]);
  }

  @override
  Stream<DocumentSnapshotPlatform> snapshots({bool includeMetadataChanges = false, required ListenSource listenSource}) {
    final name = _firestore.codec.name(path);
    WatchTarget? target;
    late StreamController<DocumentSnapshotPlatform> controller;
    controller = StreamController<DocumentSnapshotPlatform>.broadcast(
      onListen: () {
        target = _firestore.watch.add(
          Target(documents: Target_DocumentsTarget(documents: [name])),
          (docs, _) => controller.add(_firestore.snapshotOf(path, docs[name])),
          (error) {
            controller.addError(error);
            unawaited(controller.close());
          },
        );
      },
      onCancel: () => target?.remove(),
    );
    return controller.stream;
  }
}

class LinuxQuery extends QueryPlatform {
  LinuxQuery(this._firestore, this.path, {Map<String, dynamic>? parameters, this.isCollectionGroupQuery = false})
      : super(_firestore, parameters);

  final LinuxFirebaseFirestore _firestore;
  final String path;

  @override
  final bool isCollectionGroupQuery;

  QuerySpec get _spec => QuerySpec.build(_firestore.codec, path, isCollectionGroupQuery, parameters);

  LinuxQuery _copyWith(Map<String, dynamic> changes) => LinuxQuery(
        _firestore,
        path,
        isCollectionGroupQuery: isCollectionGroupQuery,
        parameters: Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(parameters)..addAll(changes)),
      );

  @override
  QueryPlatform where(List<List<dynamic>> conditions) => _copyWith({'where': conditions});

  @override
  QueryPlatform whereFilter(FilterPlatformInterface filter) => _copyWith({'filters': filter.toJson()});

  @override
  QueryPlatform orderBy(Iterable<List<dynamic>> orders) => _copyWith({'orderBy': orders});

  @override
  QueryPlatform limit(int limit) => _copyWith({'limit': limit, 'limitToLast': null});

  @override
  QueryPlatform limitToLast(int limit) => _copyWith({'limit': null, 'limitToLast': limit});

  @override
  QueryPlatform startAt(Iterable<dynamic> fields) => _copyWith({'startAt': fields, 'startAfter': null});

  @override
  QueryPlatform startAfter(Iterable<dynamic> fields) => _copyWith({'startAt': null, 'startAfter': fields});

  @override
  QueryPlatform endAt(Iterable<dynamic> fields) => _copyWith({'endAt': fields, 'endBefore': null});

  @override
  QueryPlatform endBefore(Iterable<dynamic> fields) => _copyWith({'endAt': null, 'endBefore': fields});

  @override
  QueryPlatform startAtDocument(Iterable<dynamic> orders, Iterable<dynamic> values) =>
      _copyWith({'orderBy': orders, 'startAt': values, 'startAfter': null});

  @override
  QueryPlatform startAfterDocument(List<dynamic> orders, List<dynamic> values) =>
      _copyWith({'orderBy': orders, 'startAt': null, 'startAfter': values});

  @override
  QueryPlatform endAtDocument(List<dynamic> orders, List<dynamic> values) =>
      _copyWith({'orderBy': orders, 'endAt': values, 'endBefore': null});

  @override
  QueryPlatform endBeforeDocument(Iterable<dynamic> orders, Iterable<dynamic> values) =>
      _copyWith({'orderBy': orders, 'endAt': null, 'endBefore': values});

  @override
  Future<QuerySnapshotPlatform> get([GetOptions options = const GetOptions()]) async {
    final spec = _spec;
    final connection = _firestore.connection;
    final docs = await connection.run(() async {
      final result = <Document>[];
      final responses = connection.stub.runQuery(RunQueryRequest(parent: spec.parent, structuredQuery: spec.query));
      await for (final response in responses) {
        if (response.hasDocument()) result.add(response.document);
      }
      return result;
    });
    final ordered = spec.limitToLast ? docs.reversed.toList() : docs;
    final snapshots = [for (final doc in ordered) _snapshot(doc)];
    return QuerySnapshotPlatform(
      snapshots,
      [for (final (i, s) in snapshots.indexed) DocumentChangePlatform(DocumentChangeType.added, -1, i, s)],
      SnapshotMetadataPlatform(false, false),
    );
  }

  DocumentSnapshotPlatform _snapshot(Document doc) => _firestore.snapshotOf(_firestore.codec.path(doc.name), doc);

  @override
  Stream<QuerySnapshotPlatform> snapshots({bool includeMetadataChanges = false, required ListenSource listenSource}) {
    final QuerySpec spec;
    try {
      spec = _spec;
    } catch (error) {
      return Stream.error(error);
    }
    WatchTarget? target;
    var previous = <Document>[];
    late StreamController<QuerySnapshotPlatform> controller;
    controller = StreamController<QuerySnapshotPlatform>.broadcast(
      onListen: () {
        target = _firestore.watch.add(
          Target(query: Target_QueryTarget(parent: spec.parent, structuredQuery: spec.query)),
          (docs, changed) {
            final ordered = docs.values.sorted(spec.compare);
            controller.add(_querySnapshot(previous, ordered, changed));
            previous = ordered;
          },
          (error) {
            controller.addError(error);
            unawaited(controller.close());
          },
        );
      },
      onCancel: () => target?.remove(),
    );
    return controller.stream;
  }

  /// The snapshot for [next], with document changes against [previous] in
  /// the order the native SDKs report them: removals, then additions and
  /// modifications in result order.
  QuerySnapshotPlatform _querySnapshot(List<Document> previous, List<Document> next, Set<String> changed) {
    final snapshots = [for (final doc in next) _snapshot(doc)];
    final nextIndex = {for (final (i, doc) in next.indexed) doc.name: i};
    final working = [for (final doc in previous) doc.name];
    final changes = <DocumentChangePlatform>[];
    for (final doc in previous) {
      if (nextIndex.containsKey(doc.name)) continue;
      final oldIndex = working.indexOf(doc.name);
      working.removeAt(oldIndex);
      changes.add(DocumentChangePlatform(DocumentChangeType.removed, oldIndex, -1, _snapshot(doc)));
    }
    for (final (i, doc) in next.indexed) {
      final oldIndex = working.indexOf(doc.name);
      if (oldIndex == -1) {
        changes.add(DocumentChangePlatform(DocumentChangeType.added, -1, i, snapshots[i]));
      } else if (changed.contains(doc.name)) {
        changes.add(DocumentChangePlatform(DocumentChangeType.modified, oldIndex, i, snapshots[i]));
      }
    }
    return QuerySnapshotPlatform(snapshots, changes, SnapshotMetadataPlatform(false, false));
  }

  @override
  bool operator ==(Object other) =>
      other is LinuxQuery &&
      other._firestore == _firestore &&
      other.path == path &&
      other.isCollectionGroupQuery == isCollectionGroupQuery &&
      const DeepCollectionEquality().equals(other.parameters, parameters);

  @override
  int get hashCode =>
      Object.hash(_firestore, path, isCollectionGroupQuery, const DeepCollectionEquality().hash(parameters));
}

class LinuxWriteBatch extends WriteBatchPlatform {
  LinuxWriteBatch(this._firestore);

  final LinuxFirebaseFirestore _firestore;
  final List<Write> _writes = [];
  bool _committed = false;

  void _check() {
    if (_committed) throw StateError('This batch has already been committed.');
  }

  @override
  Future<void> commit() async {
    _check();
    _committed = true;
    if (_writes.isEmpty) return;
    await _firestore.connection.commit(_writes);
  }

  @override
  void delete(String documentPath) {
    _check();
    _writes.add(_firestore.writes.delete(documentPath));
  }

  @override
  void set(String documentPath, Map<String, dynamic> data, [SetOptions? options]) {
    _check();
    _writes.add(_firestore.writes.set(documentPath, data, options));
  }

  @override
  void update(String documentPath, Map<FieldPath, dynamic> data) {
    _check();
    _writes.add(_firestore.writes.update(documentPath, data));
  }
}

class LinuxTransaction extends TransactionPlatform {
  LinuxTransaction(this._firestore, this._id);

  final LinuxFirebaseFirestore _firestore;
  final List<int> _id;
  final List<Write> _writes = [];

  @override
  Future<DocumentSnapshotPlatform> get(String documentPath) async {
    if (_writes.isNotEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Transactions require all reads to be executed before all writes.',
      );
    }
    final connection = _firestore.connection;
    final name = _firestore.codec.name(documentPath);
    final document = await connection.run(() async {
      Document? found;
      await for (final response in connection.stub.batchGetDocuments(
        BatchGetDocumentsRequest(database: connection.databaseName, documents: [name], transaction: _id),
      )) {
        if (response.hasFound()) found = response.found;
      }
      return found;
    });
    return _firestore.snapshotOf(documentPath, document);
  }

  @override
  TransactionPlatform delete(String documentPath) {
    _writes.add(_firestore.writes.delete(documentPath));
    return this;
  }

  @override
  TransactionPlatform set(String documentPath, Map<String, dynamic> data, [SetOptions? options]) {
    _writes.add(_firestore.writes.set(documentPath, data, options));
    return this;
  }

  @override
  TransactionPlatform update(String documentPath, Map<FieldPath, dynamic> data) {
    _writes.add(_firestore.writes.update(documentPath, data));
    return this;
  }
}
