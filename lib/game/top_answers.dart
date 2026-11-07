/// Top answers: "Name the five most popular films". Teams try to find the
/// answers on a list, by buzzing or on their own devices, and get the points
/// of every answer they found. Unlike the survey duel there are no strikes
/// and no steal. Plain Dart.
library;

/// How the teams answer.
enum TopAnswersMode {
  /// A team buzzes and names an answer; the gamemaster taps the one it named.
  buzzer("Teams buzz"),

  /// Every team types its answers into a list on its device.
  typed("Typed in on the teams' devices"),

  /// Every team writes its answers on a numbered whiteboard.
  whiteboard("Written on a whiteboard");

  const TopAnswersMode(this.uiString);

  final String uiString;

  static TopAnswersMode fromName(Object? name) => TopAnswersMode.values.where((m) => m.name == name).firstOrNull ?? TopAnswersMode.buzzer;
}

/// One answer on the list, with its own points; null points means it is worth
/// the question's points.
class TopAnswer {
  const TopAnswer({this.answer = '', this.points});

  final String answer;
  final int? points;

  static TopAnswer fromMap(Object? stored) {
    if (stored is! Map) return const TopAnswer();
    final points = stored['points'];
    return TopAnswer(answer: stored['answer'] is String ? stored['answer'] as String : '', points: points is num ? points.round() : null);
  }

  Map<String, dynamic> toMap() => {'answer': answer, if (points != null) 'points': points};
}

/// A top answers question's setup, stored on the question as `topAnswers`.
class TopAnswers {
  const TopAnswers({this.mode = TopAnswersMode.buzzer, this.items = const []});

  final TopAnswersMode mode;

  /// Most popular first.
  final List<TopAnswer> items;

  bool get onDevices => mode != TopAnswersMode.buzzer;

  static TopAnswers fromMap(Object? stored) {
    if (stored is! Map) return const TopAnswers();
    return TopAnswers(
      mode: TopAnswersMode.fromName(stored['mode']),
      items: [
        if (stored['items'] is List)
          for (final item in stored['items'] as List) TopAnswer.fromMap(item),
      ],
    );
  }

  Map<String, dynamic> toMap() => {
    'mode': mode.name,
    'items': [for (final item in items) item.toMap()],
  };

  /// What answer [index] is worth.
  int pointsOf(int index, int pointsPlus) => index >= 0 && index < items.length ? items[index].points ?? pointsPlus : 0;

  /// What a team that found [found] gets.
  int pointsFor(Iterable<int> found, int pointsPlus) => found.toSet().fold(0, (sum, index) => sum + pointsOf(index, pointsPlus));

  /// For each answer a team typed, the answer on the list it most likely
  /// means, or null. Every answer on the list is taken by one typed answer at
  /// most, so writing the same thing twice counts once.
  List<int?> suggest(List<String> typed) {
    final taken = <int>{};
    return [
      for (final text in typed)
        () {
          final match = _bestMatch(text, taken);
          if (match != null) taken.add(match);
          return match;
        }(),
    ];
  }

  int? _bestMatch(String typed, Set<int> taken) {
    final guess = normalizeAnswer(typed);
    if (guess.isEmpty) return null;
    int? best;
    var bestScore = 0.0;
    for (final (i, item) in items.indexed) {
      if (taken.contains(i)) continue;
      // An answer on the list may name alternatives: "Film / Movie".
      for (final option in item.answer.split(RegExp(r'[/|;]'))) {
        final target = normalizeAnswer(option);
        if (target.isEmpty) continue;
        final score = _similarity(guess, target);
        if (score > bestScore) {
          bestScore = score;
          best = i;
        }
      }
    }
    return bestScore >= 0.8 ? best : null;
  }
}

/// Lower case, without accents, punctuation, a leading article or spaces.
String normalizeAnswer(String text) {
  const accents = {
    'ä': 'a',
    'ö': 'o',
    'ü': 'u',
    'ß': 'ss',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'á': 'a',
    'à': 'a',
    'ó': 'o',
    'í': 'i',
    'ñ': 'n',
    'ç': 'c',
  };
  var out = text.toLowerCase().trim();
  out = out.split('').map((c) => accents[c] ?? c).join();
  out = out.replaceFirst(RegExp(r'^(the|a|an|der|die|das|ein|eine) '), '');
  return out.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// 1 for the same text, falling with the typing mistakes needed to get from
/// one to the other. Containing the whole other text counts as a match too:
/// "titanic1997" for "titanic".
double _similarity(String a, String b) {
  if (a == b) return 1;
  final shorter = a.length < b.length ? a : b;
  final longer = a.length < b.length ? b : a;
  if (shorter.length >= 4 && longer.contains(shorter)) return 0.9;
  final distance = _levenshtein(a, b);
  // One slip in a short word, about one in five in longer ones.
  final allowed = longer.length <= 5 ? 1 : (longer.length / 5).ceil();
  if (distance > allowed) return 0;
  return 1 - 0.2 * distance / allowed;
}

int _levenshtein(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = [previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}
