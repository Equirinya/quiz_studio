/// What each team gets for the open question, worked out the same way for
/// every kind of question from its [Results] and the question's rule. Plain
/// Dart.
///
/// The rules:
///   * fixed: right wins [Question.pointsPlus], wrong loses [Question.pointsMinus]
///   * bets of points: right wins the bet, wrong loses it
///   * bets on an amount: reached wins the points for each one bet, missed
///     loses the minus points for each one bet
///   * by order: the first right team gets the points, each after it
///     [Question.rankStep] less; wrong loses the minus points
///   * by closeness: the same by places, the team whose number is nearest
///     the solution first, once the answering is closed
/// Points worked out from the answer itself (part of the items right, an
/// estimate, top answers found) or set by hand win over the rule.
library;

import 'content.dart';
import 'session_state.dart';

/// What a right answer by [teamId] wins: its bet on a question played with
/// bets of points, the question's points for each one it bet on an amount,
/// otherwise the question's points.
int pointsIfRight(SessionState state, Question question, String teamId) {
  final betting = state.betting;
  if (betting == null) return question.pointsPlus;
  if (question.amountBet != null) return question.pointsPlus * betting.betOf(teamId);
  return question.betting ? betting.betOf(teamId) : question.pointsPlus;
}

/// What a wrong answer by [teamId] loses, as a positive number: its bet on a
/// question played with bets of points, the question's minus points for each
/// one it bet on an amount, otherwise the question's minus points.
int pointsIfWrong(SessionState state, Question question, String teamId) {
  final betting = state.betting;
  if (betting == null) return question.pointsMinus;
  if (question.amountBet != null) return question.pointsMinus * betting.betOf(teamId);
  return question.betting ? betting.betOf(teamId) : question.pointsMinus;
}

/// "By order": the points for place [place] (0 = first): as listed for the
/// question, or the question's points less [Question.rankStep] a place.
int placePoints(Question question, int place) {
  final list = question.placeList;
  if (list.isNotEmpty) return place < list.length ? list[place] : 0;
  final points = question.pointsPlus - place * (question.rankStep ?? 0);
  return points < 0 ? 0 : points;
}

/// Shorter than this counts as this, so a lightning-fast first team does
/// not leave everyone else with next to nothing.
const double _minSeconds = 1;

/// [Question.byTime]: what [teamId] gets by how long it took against the
/// fastest right team; null without its time.
int? timePoints(SessionState state, Question question, String teamId, List<String> right) {
  final round = state.answerRound;
  if (round == null) return null;
  double? seconds(String id) {
    final taken = round.answers[id]?.secondsTaken(round);
    return taken == null ? null : (taken < _minSeconds ? _minSeconds : taken);
  }

  final own = seconds(teamId);
  final times = [for (final id in right) ?seconds(id)];
  if (own == null || times.isEmpty) return null;
  final fastest = times.reduce((a, b) => a < b ? a : b);
  return (placePoints(question, 0) * fastest / own).round();
}

/// Last team standing by places, once it is decided: each team's place, the
/// winner 0, then the teams in the reverse order they went out.
Map<String, int> standingPlaces(SessionState state) {
  final play = state.standing;
  if (play == null || !play.finished) return const {};
  return {
    for (final (place, teamId) in [?play.winner, ...play.out.reversed].indexed) teamId: place,
  };
}

/// "By order": the teams rated right, in their order: first the ones the
/// gamemaster put in order, then the others by when they locked in, then by
/// when they were rated.
List<String> rightInOrder(SessionState state) {
  final results = state.results;
  final right = [
    for (final MapEntry(key: teamId, value: verdict) in results.verdicts.entries)
      if (verdict && !results.order.contains(teamId) && state.team(teamId) != null) teamId,
  ];
  final answers = state.answerRound?.answers ?? const {};
  int? lockedAt(String teamId) => answers[teamId]?.lockedAtMillis;
  // A stable sort: teams that did not lock in keep the order they were rated in.
  final indexed = right.indexed.toList()
    ..sort((a, b) {
      final (ai, at) = a;
      final (bi, bt) = b;
      final la = lockedAt(at);
      final lb = lockedAt(bt);
      if (la != null && lb != null && la != lb) return la.compareTo(lb);
      if ((la == null) != (lb == null)) return la == null ? 1 : -1;
      return ai.compareTo(bi);
    });
  return [
    for (final teamId in results.order)
      if (state.team(teamId) != null && results.verdicts[teamId] != false) teamId,
    for (final (_, teamId) in indexed) teamId,
  ];
}

/// "By closeness": each team's place (0 = first) by how near its number is
/// to the solution. Teams equally near share a place, and the next team is
/// as many places further down as shared it (1st, 1st, 3rd). Empty while
/// the teams may still answer, or without a solution.
Map<String, int> closenessPlaces(SessionState state) {
  final round = state.answerRound;
  final solution = round?.spec.solution;
  if (round == null || round.open || solution == null) return const {};
  final distances = <String, double>{
    for (final team in state.teams)
      if (round.answers[team.id]?.number case final number?) team.id: (number - solution).abs(),
  };
  return {
    for (final MapEntry(key: teamId, value: distance) in distances.entries)
      teamId: distances.values.where((other) => other < distance - 1e-9).length,
  };
}

/// What [teamId] is due for the open question as rated so far; null while it
/// is not rated.
int? pointsDue(SessionState state, Question question, String teamId) {
  final results = state.results;
  final set = results.points[teamId];
  if (set != null) return set;
  final verdict = results.verdicts[teamId];
  if (verdict == false) return -pointsIfWrong(state, question, teamId);
  if (question.byCloseness) {
    final place = closenessPlaces(state)[teamId];
    if (place != null) return placePoints(question, place);
  }
  if (question.ranked) {
    final right = rightInOrder(state);
    final place = right.indexOf(teamId);
    if (place >= 0) return (question.byTime ? timePoints(state, question, teamId, right) : null) ?? placePoints(question, place);
  }
  if (question.standingByPlaces) {
    final place = standingPlaces(state)[teamId];
    if (place != null) return placePoints(question, place);
  }
  if (verdict == true) return pointsIfRight(state, question, teamId);
  return null;
}

/// Points still to go on the scoreboard for the open question, by team:
/// what each is due minus what it was given (a team no longer rated gives
/// back what it got). Empty when everything is given.
Map<String, int> pointsToGive(SessionState state, Question question) => {
  for (final team in state.teams)
    if ((pointsDue(state, question, team.id) ?? 0) - (state.results.given[team.id] ?? 0) case final delta when delta != 0) team.id: delta,
};
