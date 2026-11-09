import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:protobuf/well_known_types/google/protobuf/wrappers.pb.dart';

import '../proto/google/firestore/v1/document.pb.dart';
import '../proto/google/firestore/v1/query.pb.dart';
import 'values.dart';

/// A query as Firestore's API takes it, built from the `parameters` map that
/// cloud_firestore's [QueryPlatform] collects (the same map the method
/// channel implementation sends to the native SDKs).
class QuerySpec {
  QuerySpec._(this.parent, this.query, this.orders, this.limitToLast);

  /// Full resource name of the parent document (or the documents root).
  final String parent;
  final StructuredQuery query;

  /// The effective ordering, including the implicit orders Firestore adds:
  /// inequality fields, then the document name. Used to sort live results.
  final List<(List<String> path, bool descending)> orders;

  /// The server runs a limitToLast query reversed; results are flipped back.
  final bool limitToLast;

  static QuerySpec build(ValueCodec codec, String collectionPath, bool isCollectionGroup, Map<String, dynamic> params) {
    final segments = collectionPath.split('/').where((s) => s.isNotEmpty).toList();
    final collectionId = segments.last;
    final parent = isCollectionGroup || segments.length == 1
        ? codec.documentsRoot
        : codec.name(segments.sublist(0, segments.length - 1).join('/'));

    Value refValue(Object? value) {
      if (value is String) {
        if (value.contains('/') && !isCollectionGroup) {
          throw ArgumentError('A document ID filter on a collection takes a plain ID, not a path: $value');
        }
        return Value(referenceValue: isCollectionGroup ? codec.name(value) : '$parent/$collectionId/$value');
      }
      return codec.encode(value);
    }

    final filters = <StructuredQuery_Filter>[];
    final inequalities = <List<String>>[];

    StructuredQuery_Filter fieldFilter(Object field, String op, Object? value) {
      final path = fieldPathOf(field);
      final isId = field == FieldPathType.documentId;
      Value encode(Object? v) => isId ? refValue(v) : codec.encode(v);
      if (op == '==' || op == '!=') {
        final isNull = value == null;
        final isNaN = value is double && value.isNaN;
        if (isNull || isNaN) {
          return StructuredQuery_Filter(
            unaryFilter: StructuredQuery_UnaryFilter(
              field_2: StructuredQuery_FieldReference(fieldPath: path),
              op: switch ((op, isNull)) {
                ('==', true) => StructuredQuery_UnaryFilter_Operator.IS_NULL,
                ('==', false) => StructuredQuery_UnaryFilter_Operator.IS_NAN,
                (_, true) => StructuredQuery_UnaryFilter_Operator.IS_NOT_NULL,
                (_, false) => StructuredQuery_UnaryFilter_Operator.IS_NOT_NAN,
              },
            ),
          );
        }
      }
      final operator = switch (op) {
        '==' => StructuredQuery_FieldFilter_Operator.EQUAL,
        '!=' => StructuredQuery_FieldFilter_Operator.NOT_EQUAL,
        '<' => StructuredQuery_FieldFilter_Operator.LESS_THAN,
        '<=' => StructuredQuery_FieldFilter_Operator.LESS_THAN_OR_EQUAL,
        '>' => StructuredQuery_FieldFilter_Operator.GREATER_THAN,
        '>=' => StructuredQuery_FieldFilter_Operator.GREATER_THAN_OR_EQUAL,
        'array-contains' => StructuredQuery_FieldFilter_Operator.ARRAY_CONTAINS,
        'array-contains-any' => StructuredQuery_FieldFilter_Operator.ARRAY_CONTAINS_ANY,
        'in' => StructuredQuery_FieldFilter_Operator.IN,
        'not-in' => StructuredQuery_FieldFilter_Operator.NOT_IN,
        _ => throw ArgumentError('Unknown query operator $op'),
      };
      if (const {'!=', '<', '<=', '>', '>=', 'not-in'}.contains(op)) {
        final segments = field == FieldPathType.documentId ? ['__name__'] : _segments(field);
        if (!inequalities.any((p) => _equal(p, segments))) inequalities.add(segments);
      }
      final encoded = (op == 'in' || op == 'not-in' || op == 'array-contains-any') && isId
          ? Value(arrayValue: ArrayValue(values: (value! as Iterable).map(refValue)))
          : encode(value);
      return StructuredQuery_Filter(
        fieldFilter: StructuredQuery_FieldFilter(
          field_1: StructuredQuery_FieldReference(fieldPath: path),
          op: operator,
          value: encoded,
        ),
      );
    }

    StructuredQuery_Filter fromJson(Map<dynamic, dynamic> json) {
      final queries = json['queries'];
      if (queries is List) {
        final op = '${json['op']}'.toUpperCase();
        return StructuredQuery_Filter(
          compositeFilter: StructuredQuery_CompositeFilter(
            op: op == 'OR' ? StructuredQuery_CompositeFilter_Operator.OR : StructuredQuery_CompositeFilter_Operator.AND,
            filters: [for (final q in queries) fromJson(q as Map)],
          ),
        );
      }
      return fieldFilter(json['fieldPath'] as Object, json['op'] as String, json['value']);
    }

    for (final condition in (params['where'] as Iterable? ?? const [])) {
      final c = condition as List;
      filters.add(fieldFilter(c[0] as Object, c[1] as String, c[2]));
    }
    final filterJson = params['filters'];
    if (filterJson is Map) filters.add(fromJson(filterJson));

    final query = StructuredQuery(
      from: [StructuredQuery_CollectionSelector(collectionId: collectionId, allDescendants: isCollectionGroup)],
    );
    if (filters.length == 1) {
      query.where = filters.single;
    } else if (filters.length > 1) {
      query.where = StructuredQuery_Filter(
        compositeFilter: StructuredQuery_CompositeFilter(op: StructuredQuery_CompositeFilter_Operator.AND, filters: filters),
      );
    }

    final explicit = <(List<String>, bool)>[
      for (final order in (params['orderBy'] as Iterable? ?? const []))
        (
          (order as List)[0] == FieldPathType.documentId ? const ['__name__'] : _segments(order[0] as Object),
          order[1] == true,
        ),
    ];

    final limitToLast = params['limitToLast'] as int?;
    final limit = params['limit'] as int?;

    // Effective ordering: explicit orders, then inequality fields (sorted),
    // then the document name in the direction of the last order.
    final orders = [...explicit];
    if (explicit.isEmpty) {
      final sorted = [...inequalities]..sort((a, b) => encodeFieldPath(a).compareTo(encodeFieldPath(b)));
      for (final path in sorted) {
        if (!_equal(path, const ['__name__'])) orders.add((path, false));
      }
    } else {
      for (final path in inequalities) {
        if (!orders.any((o) => _equal(o.$1, path))) orders.add((path, orders.last.$2));
      }
    }
    if (!orders.any((o) => _equal(o.$1, const ['__name__']))) {
      orders.add((const ['__name__'], orders.isEmpty ? false : orders.last.$2));
    }

    Cursor? cursor(String key, bool before) {
      final values = params[key];
      if (values == null) return null;
      final list = (values as Iterable).toList();
      return Cursor(
        before: before,
        values: [
          for (var i = 0; i < list.length; i++)
            i < orders.length && _equal(orders[i].$1, const ['__name__']) ? refValue(list[i]) : codec.encode(list[i]),
        ],
      );
    }

    final reverse = limitToLast != null;
    final queryOrders = reverse ? [for (final (p, d) in orders) (p, !d)] : orders;
    // Only the explicit orders are sent (the server adds the rest), but a
    // reversed query must state them all.
    final sent = reverse ? queryOrders : explicit;
    query.orderBy.addAll([
      for (final (path, descending) in sent)
        StructuredQuery_Order(
          field_1: StructuredQuery_FieldReference(fieldPath: encodeFieldPath(path)),
          direction: descending ? StructuredQuery_Direction.DESCENDING : StructuredQuery_Direction.ASCENDING,
        ),
    ]);

    final startAt = cursor('startAt', true) ?? cursor('startAfter', false);
    final endAt = cursor('endAt', false) ?? cursor('endBefore', true);
    if (reverse) {
      // Reversed, the end cursor becomes the start and vice versa.
      if (endAt != null) query.startAt = Cursor(values: endAt.values, before: !endAt.before);
      if (startAt != null) query.endAt = Cursor(values: startAt.values, before: !startAt.before);
    } else {
      if (startAt != null) query.startAt = startAt;
      if (endAt != null) query.endAt = endAt;
    }
    final n = limitToLast ?? limit;
    if (n != null) query.limit = Int32Value(value: n);

    return QuerySpec._(parent, query, orders, reverse);
  }

  /// Compares two documents in this query's order.
  int compare(Document a, Document b) {
    for (final (path, descending) in orders) {
      final int c;
      if (path.length == 1 && path.first == '__name__') {
        c = compareReferences(a.name, b.name);
      } else {
        final x = valueAt(a.fields, path), y = valueAt(b.fields, path);
        c = compareValues(x ?? Value(), y ?? Value());
      }
      if (c != 0) return descending ? -c : c;
    }
    return 0;
  }

  static List<String> _segments(Object field) {
    if (field is FieldPath) return field.components;
    if (field is String) return field.split('.');
    throw ArgumentError.value(field, 'field');
  }

  static bool _equal(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
