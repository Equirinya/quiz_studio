import 'dart:async';
import 'dart:math';

import 'package:grpc/grpc.dart';

import '../auth/auth_session.dart';
import '../proto/google/firestore/v1/document.pb.dart';
import '../proto/google/firestore/v1/firestore.pb.dart';
import 'client.dart';

/// What a watched target looks like at a consistent point in time.
typedef WatchSnapshot = Map<String, Document>;

/// One listener on the shared Listen stream: a query or a single document.
class WatchTarget {
  WatchTarget._(this._watch, this.id, this._spec, this.onSnapshot, this.onError);

  final Watch _watch;
  final int id;
  final Target _spec;
  final void Function(WatchSnapshot docs, Set<String> changed) onSnapshot;
  final void Function(Object error) onError;

  /// The documents as last delivered.
  WatchSnapshot _docs = {};

  /// Changes since then: a document, or null when it left the target.
  final Map<String, Document?> _pending = {};
  bool _reset = false;
  bool _current = false;
  bool _delivered = false;
  List<int> _resumeToken = const [];
  bool _removed = false;

  Target _request({bool fresh = false}) {
    final target = _spec.deepCopy()..targetId = id;
    if (!fresh && _resumeToken.isNotEmpty) target.resumeToken = _resumeToken;
    return target;
  }

  void _applyReset() {
    _reset = true;
    _pending.clear();
    _current = false;
  }

  /// The documents with the pending changes applied.
  WatchSnapshot _next() {
    final next = _reset ? <String, Document>{} : Map.of(_docs);
    for (final MapEntry(:key, :value) in _pending.entries) {
      if (value == null) {
        next.remove(key);
      } else {
        next[key] = value;
      }
    }
    return next;
  }

  void _deliver() {
    if (!_current || _removed) return;
    if (_delivered && _pending.isEmpty && !_reset) return;
    final next = _next();
    final changed = <String>{
      for (final name in {..._docs.keys, ...next.keys})
        if (_docs[name]?.updateTime != next[name]?.updateTime || (_docs[name] == null) != (next[name] == null)) name,
    };
    _docs = next;
    _pending.clear();
    _reset = false;
    if (_delivered && changed.isEmpty) return;
    _delivered = true;
    onSnapshot(next, changed);
  }

  /// Stops listening.
  void remove() => _watch._remove(this);
}

/// Firestore's Listen stream, shared by all listeners of one database, the
/// way the native SDKs share theirs. Reconnects with backoff and resumes each
/// target where it left off; starts over when someone else signs in.
class Watch {
  Watch(this._connection) {
    _authSub = AuthSession.of(_connection.appName).authChanges.listen((_) => _userChanged());
  }

  final FirestoreConnection _connection;
  late final StreamSubscription<Object?> _authSub;

  final Map<int, WatchTarget> _targets = {};
  int _nextId = 2;

  StreamController<ListenRequest>? _requests;
  StreamSubscription<ListenResponse>? _responses;
  Timer? _reconnect;
  Timer? _idle;
  int _failures = 0;

  WatchTarget add(Target spec, void Function(WatchSnapshot, Set<String>) onSnapshot, void Function(Object) onError) {
    final target = WatchTarget._(this, _nextId, spec, onSnapshot, onError);
    _nextId += 2;
    _targets[target.id] = target;
    _idle?.cancel();
    if (_requests == null) {
      _open();
    } else {
      _send(ListenRequest(addTarget: target._request()));
    }
    return target;
  }

  void _remove(WatchTarget target) {
    if (target._removed) return;
    target._removed = true;
    if (_targets.remove(target.id) == null) return;
    if (_requests != null) _send(ListenRequest(removeTarget: target.id));
    if (_targets.isEmpty) {
      // Keep the stream a little while: listeners often come straight back.
      _idle?.cancel();
      _idle = Timer(const Duration(seconds: 60), () {
        if (_targets.isEmpty) _close();
      });
    }
  }

  void _send(ListenRequest request) => _requests?.add(request..database = _connection.databaseName);

  void _open() {
    _reconnect?.cancel();
    _reconnect = null;
    final requests = _requests = StreamController<ListenRequest>();
    for (final target in _targets.values) {
      // The server confirms each target again before it is consistent.
      target._current = false;
      _send(ListenRequest(addTarget: target._request()));
    }
    final responses = _connection.stub.listen(requests.stream);
    _responses = responses.listen(
      (response) {
        _failures = 0;
        _handle(response);
      },
      onError: (Object error) => _failed(requests, error),
      onDone: () => _failed(requests, null),
      cancelOnError: true,
    );
  }

  void _close() {
    _reconnect?.cancel();
    _reconnect = null;
    final requests = _requests;
    _requests = null;
    unawaited(_responses?.cancel());
    _responses = null;
    unawaited(requests?.close());
  }

  void _failed(StreamController<ListenRequest> requests, Object? error) {
    if (_requests != requests) return;
    _close();
    if (_targets.isEmpty) return;
    if (error is GrpcError && error.code == StatusCode.unauthenticated) {
      // The ID token ran out; the next connection fetches a fresh one.
      unawaited(AuthSession.of(_connection.appName).idToken(forceRefresh: true).then((_) {}, onError: (_) {}));
    }
    if (error is GrpcError && _isPermanent(error.code)) {
      // Not something waiting fixes: tell every listener.
      for (final target in _targets.values.toList()) {
        target.onError(firestoreException(error));
        _remove(target);
      }
      return;
    }
    // Brief backoff first, then up to half a minute between tries.
    final delay = Duration(milliseconds: min(30000, 250 * pow(2, _failures++).toInt()));
    _reconnect = Timer(delay, () {
      if (_requests == null && _targets.isNotEmpty) _open();
    });
  }

  static bool _isPermanent(int code) => const {
        StatusCode.invalidArgument,
        StatusCode.notFound,
        StatusCode.failedPrecondition,
        StatusCode.unimplemented,
      }.contains(code);

  void _userChanged() {
    // Another user may see other documents: every target starts over.
    for (final target in _targets.values) {
      target
        .._resumeToken = const []
        .._applyReset();
    }
    if (_requests != null) {
      _close();
      _open();
    }
  }

  Iterable<WatchTarget> _byIds(List<int> ids) =>
      ids.isEmpty ? _targets.values : ids.map((id) => _targets[id]).whereType<WatchTarget>();

  void _handle(ListenResponse response) {
    switch (response.whichResponseType()) {
      case ListenResponse_ResponseType.targetChange:
        final change = response.targetChange;
        final targets = _byIds(change.targetIds).toList();
        switch (change.targetChangeType) {
          case TargetChange_TargetChangeType.REMOVE:
            for (final target in targets) {
              if (change.hasCause() && change.cause.code != 0) {
                target.onError(firestoreException(GrpcError.custom(change.cause.code, change.cause.message)));
                _remove(target);
              }
            }
            return;
          case TargetChange_TargetChangeType.CURRENT:
            for (final target in targets) {
              target._current = true;
            }
          case TargetChange_TargetChangeType.RESET:
            for (final target in targets) {
              target._applyReset();
            }
          case TargetChange_TargetChangeType.ADD:
          case TargetChange_TargetChangeType.NO_CHANGE:
            break;
        }
        if (change.resumeToken.isNotEmpty) {
          for (final target in targets) {
            target._resumeToken = change.resumeToken;
          }
        }
        // A global no-change with a read time marks a consistent snapshot.
        if (change.targetChangeType == TargetChange_TargetChangeType.NO_CHANGE &&
            change.targetIds.isEmpty &&
            change.hasReadTime()) {
          for (final target in _targets.values.toList()) {
            target._deliver();
          }
        }
      case ListenResponse_ResponseType.documentChange:
        final change = response.documentChange;
        for (final target in _byIds(change.targetIds.isEmpty ? const [-1] : change.targetIds)) {
          target._pending[change.document.name] = change.document;
        }
        for (final target in _byIds(change.removedTargetIds.isEmpty ? const [-1] : change.removedTargetIds)) {
          target._pending[change.document.name] = null;
        }
      case ListenResponse_ResponseType.documentDelete:
        final delete = response.documentDelete;
        for (final target in _byIds(delete.removedTargetIds.isEmpty ? const [-1] : delete.removedTargetIds)) {
          target._pending[delete.document] = null;
        }
      case ListenResponse_ResponseType.documentRemove:
        final remove = response.documentRemove;
        for (final target in _byIds(remove.removedTargetIds.isEmpty ? const [-1] : remove.removedTargetIds)) {
          target._pending[remove.document] = null;
        }
      case ListenResponse_ResponseType.filter:
        final filter = response.filter;
        final target = _targets[filter.targetId];
        if (target != null && target._next().length != filter.count) {
          // Our view and the server's disagree (something left the target
          // while we were away): listen again from scratch.
          target
            .._resumeToken = const []
            .._applyReset();
          _send(ListenRequest(removeTarget: target.id));
          _send(ListenRequest(addTarget: target._request(fresh: true)));
        }
      case ListenResponse_ResponseType.notSet:
        break;
    }
  }

  Future<void> dispose() async {
    await _authSub.cancel();
    _idle?.cancel();
    _close();
    _targets.clear();
  }
}
