/// Matching ("Zuordnen"): pairs of texts and/or pictures that the teams put
/// back together on their devices, e.g. films and the years they came out.
/// Plain Dart.
library;

import 'dart:math';

import 'companion.dart';

/// One side of a pair: a text, a picture, or both.
class MatchSide {
  const MatchSide({this.text = '', this.image});

  final String text;

  /// A media file of the game. Only the big screen shows it: the teams'
  /// devices get the picture's label instead.
  final String? image;

  bool get isEmpty => text.trim().isEmpty && image == null;

  static MatchSide fromMap(Object? stored) {
    if (stored is! Map) return const MatchSide();
    final image = stored['image'];
    return MatchSide(
      text: stored['text'] is String ? stored['text'] as String : '',
      image: image is String && image.isNotEmpty ? image : null,
    );
  }

  Map<String, dynamic> toMap() => {'text': text, 'image': image};
}

class MatchPair {
  const MatchPair({this.left = const MatchSide(), this.right = const MatchSide()});

  final MatchSide left;
  final MatchSide right;

  static MatchPair fromMap(Object? stored) => stored is Map
      ? MatchPair(left: MatchSide.fromMap(stored['left']), right: MatchSide.fromMap(stored['right']))
      : const MatchPair();

  Map<String, dynamic> toMap() => {'left': left.toMap(), 'right': right.toMap()};
}

/// The pairs of a matching question, stored on it as `matching`, in the
/// right pairing. Left items are named A, B, C…; right items get numbers that
/// are shuffled once per question, so a number never gives its partner away.
class Matching {
  const Matching({this.pairs = const []});

  final List<MatchPair> pairs;

  static Matching fromMap(Object? stored) => Matching(
        pairs: [
          if (stored is Map && stored['pairs'] is List)
            for (final pair in stored['pairs'] as List) MatchPair.fromMap(pair),
        ],
      );

  Map<String, dynamic> toMap() => {
        'pairs': [for (final pair in pairs) pair.toMap()],
      };

  static String letter(int index) => String.fromCharCode(0x41 + index % 26) + (index >= 26 ? '${index ~/ 26}' : '');

  /// For each pair, the number (from 1) its right item is shown with.
  List<int> rightNumbers(String questionId) {
    final numbers = List<int>.generate(pairs.length, (i) => i + 1);
    if (numbers.length < 2) return numbers;
    final random = Random(stableHash('matching|$questionId'));
    // The same order as the pairs would give every answer away.
    for (var attempt = 0; attempt < 8; attempt++) {
      numbers.shuffle(random);
      if (Iterable<int>.generate(numbers.length).any((i) => numbers[i] != i + 1)) break;
    }
    return numbers;
  }

  /// What a team's device shows for a left item.
  String leftLabel(int index) {
    final text = pairs[index].left.text.trim();
    return text.isEmpty ? "Picture ${letter(index)}" : "${letter(index)} · $text";
  }

  /// What a team's device shows for a right item.
  String rightLabel(int index, List<int> numbers) {
    final text = pairs[index].right.text.trim();
    return text.isEmpty ? "Picture ${numbers[index]}" : "${numbers[index]} · $text";
  }

  Iterable<String> get mediaPaths => [
        for (final pair in pairs) ...[?pair.left.image, ?pair.right.image],
      ];
}
