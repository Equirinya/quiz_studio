/// Last team standing: one player per team, e.g. on stage. The teams take
/// turns in a fixed order; a wrong answer puts a team out, and the last team
/// left wins the points. Plain Dart.
library;

import 'rapid_fire.dart';
import 'session_state.dart';

/// Who starts and how the turns go round.
enum TurnOrder {
  teams("As the teams are listed"),
  mostPoints("Most points first"),
  fewestPoints("Fewest points first");

  const TurnOrder(this.uiString);

  final String uiString;

  static TurnOrder fromName(Object? name) => TurnOrder.values.where((o) => o.name == name).firstOrNull ?? TurnOrder.teams;
}

/// How the gamemaster rates a turn.
enum StandingResult {
  right("Right"),

  /// Wrong: the team is out.
  out("Wrong, out"),

  /// Wrong, but the team stays in, e.g. a free miss for a team that is behind.
  miss("Wrong, stays in");

  const StandingResult(this.uiString);

  final String uiString;

  static StandingResult? fromName(Object? name) => StandingResult.values.where((r) => r.name == name).firstOrNull;
}

/// A last-team-standing question's setup, stored on it as `lastStanding`.
///
///   order: see [TurnOrder]
///   items: optional prompts, one per turn ("Does this star have a biopic?":
///          one star each), each with its answer for the gamemaster. Without
///          items every turn is the question itself ("Name a Disney film").
class LastStanding {
  const LastStanding({this.order = TurnOrder.teams, this.items = const []});

  final TurnOrder order;
  final List<RapidItem> items;

  static LastStanding fromMap(Object? stored) {
    if (stored is! Map) return const LastStanding();
    return LastStanding(
      order: TurnOrder.fromName(stored['order']),
      items: [
        if (stored['items'] is List)
          for (final item in stored['items'] as List) RapidItem.fromMap(item),
      ],
    );
  }

  Map<String, dynamic> toMap() => {
    'order': order.name,
    'items': [for (final item in items) item.toMap()],
  };

  RapidItem? itemAt(int index) => index >= 0 && index < items.length ? items[index] : null;

  Iterable<String> get mediaPaths => [
    for (final item in items) ...[?item.image, ?item.music],
  ];
}

/// The teams in turn order for [order]. Ties keep the order of the list.
List<String> turnOrder(List<Team> teams, TurnOrder order) {
  final indexed = teams.indexed.toList();
  if (order != TurnOrder.teams) {
    indexed.sort((a, b) {
      final byPoints = order == TurnOrder.mostPoints ? b.$2.points.compareTo(a.$2.points) : a.$2.points.compareTo(b.$2.points);
      return byPoints != 0 ? byPoints : a.$1.compareTo(b.$1);
    });
  }
  return [for (final (_, team) in indexed) team.id];
}

/// A last-team-standing question as it is played: the turn order fixed when
/// it opened, and every turn so far. Everything else follows from those, so
/// taking a turn back is just dropping it.
class StandingPlay {
  const StandingPlay({required this.order, this.turns = const []});

  /// Team ids in turn order.
  final List<String> order;

  /// Each turn's team and how it went, in order.
  final List<(String, StandingResult)> turns;

  /// Teams out, in the order they went out.
  List<String> get out => [
    for (final (team, result) in turns)
      if (result == StandingResult.out) team,
  ];

  /// Teams still in, in turn order.
  List<String> get inPlay {
    final gone = out.toSet();
    return [
      for (final team in order)
        if (!gone.contains(team)) team,
    ];
  }

  /// The one team left, once all the others are out.
  String? get winner => order.length > 1 && inPlay.length == 1 ? inPlay.single : null;

  bool get finished => winner != null || inPlay.isEmpty;

  /// The team whose turn it is; null once it is decided.
  String? get current {
    if (finished || order.isEmpty) return null;
    final gone = <String>{};
    var at = 0;
    for (final (_, result) in turns) {
      if (result == StandingResult.out) gone.add(order[at]);
      // On to the next team still in, round and round.
      for (var step = 1; step <= order.length; step++) {
        final next = (at + step) % order.length;
        if (!gone.contains(order[next])) {
          at = next;
          break;
        }
      }
    }
    return order[at];
  }

  /// The prompt the current turn is about (one per turn).
  int get item => turns.length;

  StandingPlay withTurn(StandingResult result) => StandingPlay(order: order, turns: [...turns, (current!, result)]);

  StandingPlay withoutLastTurn() => StandingPlay(order: order, turns: turns.sublist(0, turns.length - 1));

  /// Without [teamId], e.g. when the team leaves the session.
  StandingPlay without(String teamId) => StandingPlay(
    order: [...order]..remove(teamId),
    turns: [
      for (final turn in turns)
        if (turn.$1 != teamId) turn,
    ],
  );

  Map<String, dynamic> toJson() => {
    'order': order,
    'turns': [
      for (final (team, result) in turns) {'team': team, 'result': result.name},
    ],
  };

  static StandingPlay? fromJson(Object? json) {
    if (json is! Map) return null;
    return StandingPlay(
      order: [for (final id in json['order'] as List? ?? const []) '$id'],
      turns: [
        for (final turn in json['turns'] as List? ?? const [])
          if (turn is Map && turn['team'] is String && StandingResult.fromName(turn['result']) != null)
            (turn['team'] as String, StandingResult.fromName(turn['result'])!),
      ],
    );
  }
}
