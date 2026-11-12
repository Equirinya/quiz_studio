import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:fixnum/fixnum.dart';

import '../proto/google/firestore/v1/common.pb.dart';
import '../proto/google/firestore/v1/document.pb.dart';
import '../proto/google/firestore/v1/write.pb.dart';
import 'values.dart';

enum FieldValueKind { delete, serverTimestamp, arrayUnion, arrayRemove, increment }

/// The delegate inside a [FieldValuePlatform] on Linux.
class LinuxFieldValue {
  const LinuxFieldValue(this.kind, [this.argument]);

  final FieldValueKind kind;
  final Object? argument;

  @override
  String toString() => 'FieldValue.${kind.name}()';
}

/// cloud_firestore wraps what this returns in its FieldValue, which is the
/// FieldValuePlatform that set() and update() then hand back to us.
class LinuxFieldValueFactory extends FieldValueFactoryPlatform {
  @override
  LinuxFieldValue arrayRemove(List<dynamic> elements) => LinuxFieldValue(FieldValueKind.arrayRemove, elements);

  @override
  LinuxFieldValue arrayUnion(List<dynamic> elements) => LinuxFieldValue(FieldValueKind.arrayUnion, elements);

  @override
  LinuxFieldValue delete() => const LinuxFieldValue(FieldValueKind.delete);

  @override
  LinuxFieldValue increment(num value) => LinuxFieldValue(FieldValueKind.increment, value);

  @override
  LinuxFieldValue serverTimestamp() => const LinuxFieldValue(FieldValueKind.serverTimestamp);
}

LinuxFieldValue? _sentinel(Object? value) {
  if (value is! FieldValuePlatform) return null;
  final delegate = FieldValuePlatform.getDelegate(value);
  if (delegate is LinuxFieldValue) return delegate;
  throw ArgumentError('FieldValue from another platform: $delegate');
}

/// Turns set()/update() data into a [Write]: the plain fields, the field
/// mask, and the transforms for server timestamps, array unions and so on.
class WriteBuilder {
  WriteBuilder(this.codec);

  final ValueCodec codec;

  Write delete(String path) => Write(delete: codec.name(path));

  Write set(String path, Map<String, dynamic> data, [SetOptions? options]) {
    final fields = <String, Value>{};
    final transforms = <DocumentTransform_FieldTransform>[];
    final leaves = <List<String>>[];
    _collect(data, const [], fields, transforms, leaves, allowDelete: options != null);

    final write = Write(update: Document(name: codec.name(path), fields: fields.entries), updateTransforms: transforms);
    if (options?.merge == true) {
      write.updateMask = DocumentMask(fieldPaths: leaves.map(encodeFieldPath));
    } else if (options?.mergeFields != null) {
      final mask = options!.mergeFields!.map((f) => f.components).toList();
      bool covered(List<String> path) => mask.any((m) => _startsWith(path, m));
      // Only the named fields are written; anything else in data is ignored.
      write
        ..update = Document(name: codec.name(path), fields: _filter(fields, mask).entries)
        ..updateMask = DocumentMask(fieldPaths: mask.map(encodeFieldPath))
        ..updateTransforms.retainWhere((t) => covered(decodeFieldPath(t.fieldPath)));
    }
    return write;
  }

  Write update(String path, Map<FieldPath, dynamic> data) {
    final fields = <String, Value>{};
    final transforms = <DocumentTransform_FieldTransform>[];
    final mask = <List<String>>[];
    for (final MapEntry(:key, :value) in data.entries) {
      final segments = key.components;
      final sentinel = _sentinel(value);
      if (sentinel != null) {
        if (sentinel.kind == FieldValueKind.delete) {
          mask.add(segments);
        } else {
          transforms.add(_transform(segments, sentinel));
        }
        continue;
      }
      mask.add(segments);
      if (value is Map) {
        // Nested sentinels are transforms; the rest replaces the whole map.
        final nested = <String, Value>{};
        _collect(value, segments, nested, transforms, null, allowDelete: false);
        _put(fields, segments, Value(mapValue: MapValue(fields: nested.entries)));
      } else {
        _put(fields, segments, codec.encode(value));
      }
    }
    return Write(
      update: Document(name: codec.name(path), fields: fields.entries),
      updateMask: DocumentMask(fieldPaths: mask.map(encodeFieldPath)),
      updateTransforms: transforms,
      currentDocument: Precondition(exists: true),
    );
  }

  /// Walks [data] at [prefix]: plain values go into [fields] (relative to
  /// [prefix]), sentinels into [transforms], and every leaf path, for merge
  /// masks, into [leaves].
  void _collect(
    Map<dynamic, dynamic> data,
    List<String> prefix,
    Map<String, Value> fields,
    List<DocumentTransform_FieldTransform> transforms,
    List<List<String>>? leaves, {
    required bool allowDelete,
  }) {
    for (final MapEntry(:key, :value) in data.entries) {
      final path = [...prefix, '$key'];
      final sentinel = _sentinel(value);
      if (sentinel != null) {
        if (sentinel.kind == FieldValueKind.delete) {
          if (!allowDelete) {
            throw ArgumentError('FieldValue.delete() can only be used with update() or set() with merge.');
          }
          leaves?.add(path);
        } else {
          transforms.add(_transform(path, sentinel));
        }
        continue;
      }
      if (value is Map && value.isNotEmpty) {
        final nested = <String, Value>{};
        _collect(value, path, nested, transforms, leaves, allowDelete: allowDelete);
        // A map holding only sentinels is not written as an empty map.
        if (nested.isNotEmpty || !_onlySentinels(value)) {
          fields['$key'] = Value(mapValue: MapValue(fields: nested.entries));
        }
      } else {
        fields['$key'] = codec.encode(value);
        leaves?.add(path);
      }
    }
  }

  static bool _onlySentinels(Map<dynamic, dynamic> map) =>
      map.values.every((v) => v is FieldValuePlatform || (v is Map && v.isNotEmpty && _onlySentinels(v)));

  DocumentTransform_FieldTransform _transform(List<String> path, LinuxFieldValue sentinel) {
    final transform = DocumentTransform_FieldTransform(fieldPath: encodeFieldPath(path));
    switch (sentinel.kind) {
      case FieldValueKind.serverTimestamp:
        transform.setToServerValue = DocumentTransform_FieldTransform_ServerValue.REQUEST_TIME;
      case FieldValueKind.arrayUnion:
        transform.appendMissingElements = ArrayValue(values: (sentinel.argument! as List).map(codec.encode));
      case FieldValueKind.arrayRemove:
        transform.removeAllFromArray = ArrayValue(values: (sentinel.argument! as List).map(codec.encode));
      case FieldValueKind.increment:
        final n = sentinel.argument! as num;
        transform.increment = n is int ? Value(integerValue: Int64(n)) : Value(doubleValue: n.toDouble());
      case FieldValueKind.delete:
        throw StateError('delete is not a transform');
    }
    return transform;
  }

  static void _put(Map<String, Value> fields, List<String> path, Value value) {
    var map = fields;
    for (var i = 0; i < path.length - 1; i++) {
      final existing = map[path[i]];
      final next = existing != null && existing.hasMapValue() ? existing : Value(mapValue: MapValue());
      map[path[i]] = next;
      map = next.mapValue.fields;
    }
    map[path.last] = value;
  }

  static Map<String, Value> _filter(Map<String, Value> fields, List<List<String>> mask) {
    final result = <String, Value>{};
    for (final path in mask) {
      final value = valueAt(fields, path);
      if (value != null) _put(result, path, value);
    }
    return result;
  }

  static bool _startsWith(List<String> path, List<String> prefix) {
    if (path.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (path[i] != prefix[i]) return false;
    }
    return true;
  }
}
