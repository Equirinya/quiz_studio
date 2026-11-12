import 'dart:typed_data';

import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:fixnum/fixnum.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pbenum.dart' show NullValue;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart' as pb;

import '../proto/google/firestore/v1/document.pb.dart';
import '../proto/google/type/latlng.pb.dart';

/// Converts between Dart values as cloud_firestore hands them over and
/// Firestore's protobuf [Value]s.
class ValueCodec {
  ValueCodec(this.firestore, this.databaseName);

  final FirebaseFirestorePlatform firestore;

  /// `projects/<project>/databases/<database>`.
  final String databaseName;

  String get documentsRoot => '$databaseName/documents';

  /// The full resource name of the document at [path].
  String name(String path) => '$documentsRoot/${_trim(path)}';

  /// The document path within the database, from a full resource name.
  String path(String name) => name.startsWith('$documentsRoot/') ? name.substring(documentsRoot.length + 1) : name;

  static String _trim(String path) => path.replaceAll(RegExp(r'^/+|/+$'), '');

  Value encode(Object? value) {
    if (value == null) return Value(nullValue: NullValue.NULL_VALUE);
    if (value is bool) return Value(booleanValue: value);
    if (value is int) return Value(integerValue: Int64(value));
    if (value is double) return Value(doubleValue: value);
    if (value is String) return Value(stringValue: value);
    if (value is Timestamp) {
      return Value(timestampValue: pb.Timestamp(seconds: Int64(value.seconds), nanos: value.nanoseconds));
    }
    if (value is DateTime) return encode(Timestamp.fromDate(value));
    if (value is GeoPoint) return Value(geoPointValue: LatLng(latitude: value.latitude, longitude: value.longitude));
    if (value is Blob) return Value(bytesValue: value.bytes);
    if (value is Uint8List) return Value(bytesValue: value);
    if (value is DocumentReferencePlatform) return Value(referenceValue: name(value.path));
    if (value is VectorValue) {
      return Value(
        mapValue: MapValue(fields: {
          '__type__': Value(stringValue: '__vector__'),
          'value': Value(arrayValue: ArrayValue(values: [for (final v in value.toArray()) Value(doubleValue: v)])),
        }.entries),
      );
    }
    if (value is Iterable) return Value(arrayValue: ArrayValue(values: [for (final v in value) encode(v)]));
    if (value is Map) return Value(mapValue: MapValue(fields: encodeMap(value).entries));
    if (value is FieldValuePlatform) {
      throw ArgumentError('${FieldValuePlatform.getDelegate(value)} can only be used at the top level of set() and update() data, not inside arrays.');
    }
    throw ArgumentError.value(value, 'value', 'Unsupported type for Firestore: ${value.runtimeType}');
  }

  Map<String, Value> encodeMap(Map<dynamic, dynamic> map) => {
        for (final MapEntry(:key, :value) in map.entries) '$key': encode(value),
      };

  Object? decode(Value value) {
    switch (value.whichValueType()) {
      case Value_ValueType.nullValue:
      case Value_ValueType.notSet:
        return null;
      case Value_ValueType.booleanValue:
        return value.booleanValue;
      case Value_ValueType.integerValue:
        return value.integerValue.toInt();
      case Value_ValueType.doubleValue:
        return value.doubleValue;
      case Value_ValueType.stringValue:
        return value.stringValue;
      case Value_ValueType.timestampValue:
        return Timestamp(value.timestampValue.seconds.toInt(), value.timestampValue.nanos);
      case Value_ValueType.bytesValue:
        return Blob(Uint8List.fromList(value.bytesValue));
      case Value_ValueType.referenceValue:
        return firestore.doc(path(value.referenceValue));
      case Value_ValueType.geoPointValue:
        return GeoPoint(value.geoPointValue.latitude, value.geoPointValue.longitude);
      case Value_ValueType.arrayValue:
        return [for (final v in value.arrayValue.values) decode(v)];
      case Value_ValueType.mapValue:
        final fields = value.mapValue.fields;
        if (fields['__type__']?.stringValue == '__vector__') {
          return VectorValue([for (final v in fields['value']!.arrayValue.values) v.doubleValue]);
        }
        return decodeMap(fields);
      default:
        throw UnsupportedError('Unsupported Firestore value ${value.whichValueType()}');
    }
  }

  Map<String, dynamic> decodeMap(Map<String, Value> fields) => {
        for (final MapEntry(:key, :value) in fields.entries) key: decode(value),
      };
}

// ---- Field paths ---------------------------------------------------------------

final _simpleSegment = RegExp(r'^[a-zA-Z_][a-zA-Z_0-9]*$');

/// A field path in the syntax of update masks and queries: segments joined
/// by dots, quoted with backticks when they are not plain identifiers.
String encodeFieldPath(List<String> segments) => segments
    .map((s) => _simpleSegment.hasMatch(s) ? s : '`${s.replaceAll(r'\', r'\\').replaceAll('`', r'\`')}`')
    .join('.');

String fieldPathOf(Object field) {
  if (field == FieldPathType.documentId) return '__name__';
  if (field is FieldPath) return encodeFieldPath(field.components);
  if (field is String) return encodeFieldPath(field.split('.'));
  throw ArgumentError.value(field, 'field', 'Expected a String or FieldPath');
}

// ---- Ordering --------------------------------------------------------------------

int _typeOrder(Value v) => switch (v.whichValueType()) {
      Value_ValueType.nullValue || Value_ValueType.notSet => 0,
      Value_ValueType.booleanValue => 1,
      Value_ValueType.integerValue || Value_ValueType.doubleValue => 2,
      Value_ValueType.timestampValue => 3,
      Value_ValueType.stringValue => 4,
      Value_ValueType.bytesValue => 5,
      Value_ValueType.referenceValue => 6,
      Value_ValueType.geoPointValue => 7,
      Value_ValueType.arrayValue => 9,
      Value_ValueType.mapValue => v.mapValue.fields['__type__']?.stringValue == '__vector__' ? 8 : 10,
      _ => 11,
    };

int _compareNum(Value a, Value b) {
  double asDouble(Value v) => v.hasIntegerValue() ? v.integerValue.toDouble() : v.doubleValue;
  if (a.hasIntegerValue() && b.hasIntegerValue()) return a.integerValue.compareTo(b.integerValue);
  final x = asDouble(a), y = asDouble(b);
  if (x.isNaN) return y.isNaN ? 0 : -1;
  if (y.isNaN) return 1;
  return x.compareTo(y);
}

int _compareBytes(List<int> a, List<int> b) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return a.length.compareTo(b.length);
}

int _compareStrings(String a, String b) {
  // Firestore orders strings by their UTF-8 bytes, which is code point order.
  final x = a.runes.iterator, y = b.runes.iterator;
  while (true) {
    final hasX = x.moveNext(), hasY = y.moveNext();
    if (!hasX || !hasY) return hasX == hasY ? 0 : (hasX ? 1 : -1);
    if (x.current != y.current) return x.current.compareTo(y.current);
  }
}

int compareReferences(String a, String b) {
  final x = a.split('/'), y = b.split('/');
  for (var i = 0; i < x.length && i < y.length; i++) {
    final c = _compareStrings(x[i], y[i]);
    if (c != 0) return c;
  }
  return x.length.compareTo(y.length);
}

/// Firestore's ordering of values, for sorting live query results the way
/// the server does.
int compareValues(Value a, Value b) {
  final ta = _typeOrder(a), tb = _typeOrder(b);
  if (ta != tb) return ta.compareTo(tb);
  switch (ta) {
    case 0:
      return 0;
    case 1:
      return a.booleanValue == b.booleanValue ? 0 : (a.booleanValue ? 1 : -1);
    case 2:
      return _compareNum(a, b);
    case 3:
      final c = a.timestampValue.seconds.compareTo(b.timestampValue.seconds);
      return c != 0 ? c : a.timestampValue.nanos.compareTo(b.timestampValue.nanos);
    case 4:
      return _compareStrings(a.stringValue, b.stringValue);
    case 5:
      return _compareBytes(a.bytesValue, b.bytesValue);
    case 6:
      return compareReferences(a.referenceValue, b.referenceValue);
    case 7:
      final c = a.geoPointValue.latitude.compareTo(b.geoPointValue.latitude);
      return c != 0 ? c : a.geoPointValue.longitude.compareTo(b.geoPointValue.longitude);
    case 9:
      final x = a.arrayValue.values, y = b.arrayValue.values;
      for (var i = 0; i < x.length && i < y.length; i++) {
        final c = compareValues(x[i], y[i]);
        if (c != 0) return c;
      }
      return x.length.compareTo(y.length);
    case 8:
    case 10:
      final x = a.mapValue.fields, y = b.mapValue.fields;
      final kx = x.keys.toList()..sort(_compareStrings), ky = y.keys.toList()..sort(_compareStrings);
      for (var i = 0; i < kx.length && i < ky.length; i++) {
        var c = _compareStrings(kx[i], ky[i]);
        if (c != 0) return c;
        c = compareValues(x[kx[i]]!, y[ky[i]]!);
        if (c != 0) return c;
      }
      return kx.length.compareTo(ky.length);
    default:
      return 0;
  }
}

/// The value at [segments] in [fields], or null when it is missing.
Value? valueAt(Map<String, Value> fields, List<String> segments) {
  Value? current;
  var map = fields;
  for (var i = 0; i < segments.length; i++) {
    current = map[segments[i]];
    if (current == null) return null;
    if (i < segments.length - 1) {
      if (!current.hasMapValue()) return null;
      map = current.mapValue.fields;
    }
  }
  return current;
}

/// Splits an encoded field path back into its segments.
List<String> decodeFieldPath(String path) {
  final segments = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var i = 0; i < path.length; i++) {
    final c = path[i];
    if (quoted) {
      if (c == r'\' && i + 1 < path.length) {
        buffer.write(path[++i]);
      } else if (c == '`') {
        quoted = false;
      } else {
        buffer.write(c);
      }
    } else if (c == '`') {
      quoted = true;
    } else if (c == '.') {
      segments.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(c);
    }
  }
  segments.add(buffer.toString());
  return segments;
}
