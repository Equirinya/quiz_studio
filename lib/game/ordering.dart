/// Put in order ("Sortieren"): entries the teams sort on their devices, e.g.
/// inventions by the year they were made. The big screen shows them mixed
/// up and then puts them in place one by one, each with what it is sorted
/// by ("1969"). Plain Dart.
library;

import 'dart:math';

import 'companion.dart';

/// How the points of a put-in-order question are shared out.
enum OrderScoring {
  /// All points for the exact order, none otherwise.
  exact,

  /// A share for every entry in its right place.
  places,

  /// A share for every two entries that are the right way round: one entry
  /// in the wrong spot costs only a little.
  pairs;

  static OrderScoring fromName(Object? name) => OrderScoring.values.where((s) => s.name == name).firstOrNull ?? OrderScoring.places;
}

/// One entry: a text, a picture or both, and optionally what it is sorted by,
/// shown as it is put in place.
class OrderItem {
  const OrderItem({this.text = '', this.image, this.value = ''});

  final String text;

  /// A media file of the game; the devices get it shrunk.
  final String? image;

  /// What it is sorted by, e.g. "1969"; revealed with the solution.
  final String value;

  bool get isEmpty => text.trim().isEmpty && image == null;

  static OrderItem fromMap(Object? stored) {
    if (stored is String) return OrderItem(text: stored);
    if (stored is! Map) return const OrderItem();
    final image = stored['image'];
    return OrderItem(
      text: stored['text'] is String ? stored['text'] as String : '',
      image: image is String && image.isNotEmpty ? image : null,
      value: stored['value'] is String ? stored['value'] as String : '',
    );
  }

  Map<String, dynamic> toMap() => {'text': text, if (image != null) 'image': image, if (value.trim().isNotEmpty) 'value': value};
}

/// The entries of a put-in-order question, stored on it as `ordering`, in
/// the RIGHT order.
///
///   items:   [{text, image?, value?}], first to last
///
/// How it is scored is stored beside it on the question, as `orderScoring`
/// (see [OrderScoring]; absent = places), so the editor's two sections
/// never write over each other.
class Ordering {
  const Ordering({this.items = const [], this.scoring = OrderScoring.places});

  final List<OrderItem> items;
  final OrderScoring scoring;

  /// [stored] as saved; a question that was a free question with "put in
  /// order" on the devices brings its entries along ([companion]).
  static Ordering fromMap(Object? stored, {Object? companion, Object? scoring}) {
    final by = OrderScoring.fromName(scoring ?? (stored is Map ? stored['scoring'] : null));
    if (stored is Map) {
      return Ordering(
        items: [if (stored['items'] is List) for (final item in stored['items'] as List) OrderItem.fromMap(item)],
        scoring: by,
      );
    }
    final old = CompanionSpec.fromMap(companion);
    if (old?.kind == CompanionKind.order) return Ordering(items: [for (final text in old!.options) OrderItem(text: text)], scoring: by);
    return Ordering(scoring: by);
  }

  /// With the scoring, as the tools show it; the question stores only the
  /// items here.
  Map<String, dynamic> toMap() => {
        'items': [for (final item in items) item.toMap()],
        if (scoring != OrderScoring.places) 'scoring': scoring.name,
      };

  /// What a team's device shows for entry [index]: its text, or for a
  /// picture alone a name for it ("Picture 3"). The numbers are mixed up
  /// once per question so a name never gives the place away; the devices
  /// leave the name out where they show the picture.
  String label(int index, String questionId) {
    final text = items[index].text.trim();
    if (text.isNotEmpty) return text;
    final numbers = List<int>.generate(items.length, (i) => i + 1)..shuffle(Random(stableHash('ordering|$questionId')));
    return "Picture ${numbers[index]}";
  }

  Iterable<String> get mediaPaths => [for (final item in items) ?item.image];
}

/// How well [order] (original indices in the team's order) matches the
/// right order of [length] entries under [scoring].
({int right, int of}) orderScore(List<int> order, int length, OrderScoring scoring) {
  switch (scoring) {
    case OrderScoring.exact:
      final perfect = order.length == length && Iterable<int>.generate(length).every((i) => order[i] == i);
      return (right: perfect ? 1 : 0, of: 1);
    case OrderScoring.places:
      var right = 0;
      for (var i = 0; i < length && i < order.length; i++) {
        if (order[i] == i) right++;
      }
      return (right: right, of: length);
    case OrderScoring.pairs:
      // Where the team put each entry; entries it left out count as wrong.
      final at = {for (final (position, index) in order.indexed) index: position};
      var right = 0;
      for (var a = 0; a < length; a++) {
        for (var b = a + 1; b < length; b++) {
          if (at[a] != null && at[b] != null && at[a]! < at[b]!) right++;
        }
      }
      return (right: right, of: length * (length - 1) ~/ 2);
  }
}
