import 'session_state.dart';

/// The podium: a board every game has as its last, not one made in the
/// editor. It shows the top three on steps and the other teams below.
const String podiumBoardId = '_podium';

/// The teams by points, most first, each with its place from 1: teams level
/// on points share it, and the next is as many places further down (1st,
/// 1st, 3rd). Level teams keep their own order.
List<(int, Team)> podiumPlaces(List<Team> teams) {
  final sorted = [...teams.indexed]..sort((a, b) => b.$2.points != a.$2.points ? b.$2.points - a.$2.points : a.$1 - b.$1);
  final places = <(int, Team)>[];
  for (final (i, (_, team)) in sorted.indexed) {
    final place = i > 0 && places[i - 1].$2.points == team.points ? places[i - 1].$1 : i + 1;
    places.add((place, team));
  }
  return places;
}
