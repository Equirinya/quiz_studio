/// How the teams did on the open question, and every change to the scores.
/// Plain Dart, JSON-serialisable.
///
/// Scoring works the same way for every kind of question: the gamemaster
/// (or "rate automatically") rates each team, which says what the team is
/// due ([pointsDue] in scoring.dart); "Give points" then puts the difference
/// to what it was already given on the scoreboard. A rating can be changed
/// and the points given again without anything counting twice.
library;

/// The ratings of the open question, by team id. Emptied with the question.
class Results {
  const Results({this.verdicts = const {}, this.points = const {}, this.given = const {}, this.order = const []});

  /// Right or wrong, where the team was rated.
  final Map<String, bool> verdicts;

  /// Points a team gets regardless of the scoring rule: set by hand or worked
  /// out from its answer (part of the items right, an estimate, top answers
  /// found, groups solved).
  final Map<String, int> points;

  /// What each team already got for this question on the scoreboard.
  final Map<String, int> given;

  /// "By order" scoring: the teams in the order the gamemaster put them,
  /// e.g. as they finished. Teams rated right but not put in order follow.
  final List<String> order;

  bool get isEmpty => verdicts.isEmpty && points.isEmpty && given.isEmpty && order.isEmpty;

  Results copyWith({Map<String, bool>? verdicts, Map<String, int>? points, Map<String, int>? given, List<String>? order}) =>
      Results(verdicts: verdicts ?? this.verdicts, points: points ?? this.points, given: given ?? this.given, order: order ?? this.order);

  /// [teamId] rated [verdict] (null: not rated), with [points] that override
  /// the rule (null: the rule decides).
  Results rated(String teamId, bool? verdict, {int? points}) => copyWith(
    verdicts: verdict == null ? ({...verdicts}..remove(teamId)) : {...verdicts, teamId: verdict},
    points: points == null ? ({...this.points}..remove(teamId)) : {...this.points, teamId: points},
  );

  /// Without anything about [teamId], e.g. when the team leaves.
  Results without(String teamId) => Results(
    verdicts: {...verdicts}..remove(teamId),
    points: {...points}..remove(teamId),
    given: {...given}..remove(teamId),
    order: [...order]..remove(teamId),
  );

  Map<String, dynamic> toJson() => {
    if (verdicts.isNotEmpty) 'verdicts': verdicts,
    if (points.isNotEmpty) 'points': points,
    if (given.isNotEmpty) 'given': given,
    if (order.isNotEmpty) 'order': order,
  };

  factory Results.fromJson(Object? json) {
    if (json is! Map) return const Results();
    return Results(
      verdicts: {
        for (final entry in (json['verdicts'] as Map? ?? const {}).entries)
          if (entry.value is bool) '${entry.key}': entry.value as bool,
      },
      points: _ints(json['points']),
      given: _ints(json['given']),
      order: [for (final id in json['order'] as List? ?? const []) '$id'],
    );
  }

  static Map<String, int> _ints(Object? map) => {
    for (final entry in (map is Map ? map : const {}).entries)
      if (entry.value is num) '${entry.key}': (entry.value as num).toInt(),
  };
}

/// One change to a team's score, whatever caused it. The big screen and the
/// devices show new ones as "+100" for a moment.
class ScoreChange {
  const ScoreChange({required this.id, required this.teamId, required this.delta});

  /// Counts up over the session, so a screen can tell which changes it has
  /// shown already.
  final int id;
  final String teamId;
  final int delta;

  Map<String, dynamic> toJson() => {'id': id, 'team': teamId, 'delta': delta};

  static ScoreChange? fromJson(Object? json) {
    if (json is! Map || json['id'] is! num || json['team'] is! String || json['delta'] is! num) return null;
    return ScoreChange(id: (json['id'] as num).toInt(), teamId: json['team'] as String, delta: (json['delta'] as num).toInt());
  }
}

/// How many recent score changes the state keeps.
const int kScoreLogLength = 24;
