/// What the gamemaster's "rate automatically" and scoring buttons send for
/// an answer round. Plain Dart.
library;

import 'auto_rating.dart';
import 'commands.dart';
import 'companion.dart';
import 'content.dart';
import 'scoring.dart';
import 'session_state.dart';
import 'top_answers.dart';

/// The ratings that can be worked out without a human and would change
/// something, one command per team:
///   * top answers typed in: the answers on the list the team's lines match
///   * put in order, match pairs: points for every item in the right place
///   * pick one, numbers with a solution: right or wrong
/// Only answers that are final count: locked in, or the round is closed.
/// Empty when there is nothing the button would do, so it is not shown.
List<Command> autoRating(SessionState state, AnswerRound round, Question question) => [
  for (final command in _candidates(state, round, question))
    if (_final(round, command) && _changes(state, round, command, question)) command,
];

/// Whether [question] has its teams' answers rated as soon as they are
/// final, without the button: ABCD picked on the devices, and top answers
/// typed in, unless the editor switched it off.
bool ratesItself(Question question, AnswerRound round) =>
    question.autoRating.on &&
    switch (question.type) {
      QuestionType.abcd => round.kind == CompanionKind.choice,
      QuestionType.topAnswers => round.kind == CompanionKind.list,
      _ => false,
    };

/// The ratings for [teams] whose answers just became final, as the
/// gamemaster would have tapped them. A team the gamemaster has rated
/// already keeps that rating. Empty unless [ratesItself].
List<Command> ratingByItself(SessionState state, AnswerRound round, Question question, Iterable<String> teams) {
  if (!ratesItself(question, round)) return const [];
  final ids = teams.toSet();
  return [
    for (final command in _candidates(state, round, question))
      if (_teamOf(command) case final teamId? when ids.contains(teamId) && !_rated(state, teamId)) command,
  ];
}

/// Whether [teamId]'s rating in [state] is the one rating by itself gives
/// its answer in [round]: not one the gamemaster chose.
bool ratedByItself(SessionState state, AnswerRound round, Question question, String teamId) {
  final automatic = _candidates(state, round, question).where((command) => _teamOf(command) == teamId).firstOrNull;
  return switch (automatic) {
    RateAnswer(:final correct) => state.results.verdicts[teamId] == correct && !state.results.points.containsKey(teamId),
    AwardAnswer(:final points) => state.results.points[teamId] == points,
    _ => false,
  };
}

bool _rated(SessionState state, String teamId) =>
    state.results.verdicts.containsKey(teamId) || state.results.points.containsKey(teamId);

String? _teamOf(Command command) => switch (command) {
  RateAnswer(:final teamId) || AwardAnswer(:final teamId) || MarkTopAnswers(:final teamId) => teamId,
  _ => null,
};

bool _final(AnswerRound round, Command command) {
  final teamId = _teamOf(command);
  return teamId != null && (!round.open || round.answers[teamId]?.locked == true);
}

/// Several picks on an ABCD question, scored as [scoring] says: how much of
/// it is right, out of how much. All or nothing is 1 of 1 or 0 of 1. Null
/// for a single pick, or without the right options.
({int right, int of})? multipleChoiceScore(PlayerAnswer? answer, List<bool> correct, MultipleChoiceScoring scoring) {
  final picked = answer?.choices?.toSet();
  if (picked == null || correct.isEmpty) return null;
  final right = {for (final (i, yes) in correct.indexed) if (yes) i};
  final hits = picked.where(right.contains).length;
  final misses = picked.length - hits;
  return switch (scoring) {
    MultipleChoiceScoring.all => (right: hits == right.length && misses == 0 ? 1 : 0, of: 1),
    MultipleChoiceScoring.any => (right: hits > 0 && misses == 0 ? 1 : 0, of: 1),
    MultipleChoiceScoring.partial => (right: (hits - misses).clamp(0, right.length), of: right.length),
  };
}

/// How much of a team's answer is right, out of how much, where points are
/// shared out by it: items in place ([partialScore]), or several ABCD
/// picks scored per right one.
({int right, int of})? shareOf(Question question, CompanionSpec spec, PlayerAnswer? answer) {
  final partial = partialScore(spec, answer);
  if (partial != null) return partial;
  final scoring = question.autoRating.multiple;
  if (spec.kind != CompanionKind.choice || scoring != MultipleChoiceScoring.partial) return null;
  return multipleChoiceScore(answer, question.answersCorrect, scoring);
}

/// Right or wrong, where that can be told without a human ([autoVerdict]),
/// with several ABCD picks counted as the question says.
bool? verdictOf(Question question, CompanionSpec spec, PlayerAnswer? answer) {
  if (spec.kind == CompanionKind.choice && answer?.choices != null) {
    final score = multipleChoiceScore(answer, question.answersCorrect, question.autoRating.multiple);
    return score == null ? null : score.right == score.of;
  }
  return autoVerdict(spec, answer, choiceCorrect: question.answersCorrect);
}

bool _changes(SessionState state, AnswerRound round, Command command, Question question) => switch (command) {
  RateAnswer(:final teamId, :final correct) => state.results.verdicts[teamId] != correct || state.results.points.containsKey(teamId),
  AwardAnswer(:final teamId, :final points) => state.results.points[teamId] != points,
  MarkTopAnswers(:final teamId, :final found) =>
    !state.results.points.containsKey(teamId) || !_sameSet(round.found[teamId] ?? const [], found),
  _ => true,
};

bool _sameSet(List<int> a, List<int> b) => a.toSet().length == b.toSet().length && a.toSet().containsAll(b);

List<Command> _candidates(SessionState state, AnswerRound round, Question question) {
  // Whether a team reached the number it bet is for the gamemaster to say.
  if (question.amountBet != null) return const [];
  // By closeness the places say it all.
  if (question.byCloseness) return const [];
  final top = question.topAnswers;
  if (question.type == QuestionType.topAnswers) {
    if (top == null || round.kind != CompanionKind.list) return const [];
    return [
      for (final team in state.teams)
        if (round.answers[team.id]?.items case final items?) MarkTopAnswers(team.id, top.suggest(items).nonNulls.toList()),
    ];
  }
  if (round.kind == CompanionKind.connections) return const [];
  final commands = <Command>[];
  for (final team in state.teams) {
    final answer = round.answers[team.id];
    final partial = shareOf(question, round.spec, answer);
    if (partial != null) {
      commands.add(
        partial.right == partial.of || partial.right == 0
            ? RateAnswer(team.id, correct: partial.right == partial.of)
            : AwardAnswer(team.id, partialPoints(partial, pointsIfRight(state, question, team.id))),
      );
      continue;
    }
    final verdict = verdictOf(question, round.spec, answer);
    if (verdict != null) commands.add(RateAnswer(team.id, correct: verdict));
  }
  return commands;
}

/// Points for an estimate, shared out the way [scoring] says: a full hit is
/// rated right, nothing is rated wrong without taking points away.
///
/// With bets each team's share is of its own bet, and a team that gets
/// nothing loses its bet.
List<Command> estimateRating(SessionState state, AnswerRound round, Question question, EstimateScoring scoring) {
  if (question.amountBet != null) return const [];
  if (!question.betting || state.betting == null) {
    return [
      for (final MapEntry(key: teamId, value: points) in estimatePoints(round.spec, round.answers, question.pointsPlus, scoring).entries)
        points == question.pointsPlus ? RateAnswer(teamId, correct: true) : AwardAnswer(teamId, points),
    ];
  }
  const whole = 1000;
  return [
    for (final MapEntry(key: teamId, value: share) in estimatePoints(round.spec, round.answers, whole, scoring).entries)
      share == whole || share == 0
          ? RateAnswer(teamId, correct: share == whole)
          : AwardAnswer(teamId, (state.betting!.betOf(teamId) * share / whole).round()),
  ];
}

/// The answers on the top answers list that [team] found, as ticked so far.
List<int> foundBy(AnswerRound round, String teamId) => round.found[teamId] ?? const [];

/// [found] with answer [index] added or taken away.
List<int> toggled(List<int> found, int index) => found.contains(index) ? ([...found]..remove(index)) : [...found, index];

/// An answer list with right answers set in the editor: for each line a
/// team wrote, the right answer it matches, or null. Matched as loosely as
/// top answers, so small typos still count; each right answer is matched
/// once at most.
List<int?> listMatches(CompanionSpec spec, PlayerAnswer? answer) {
  final items = answer?.items;
  if (items == null || spec.kind != CompanionKind.list || spec.solutions.isEmpty) return const [];
  return TopAnswers(items: [for (final text in spec.solutions) TopAnswer(answer: text)]).suggest(items);
}

/// Suggestions for a team's typed answers, by line; null where a line
/// matches nothing on the list.
List<int?> suggestionsFor(Question question, PlayerAnswer? answer) {
  final items = answer?.items;
  final top = question.topAnswers ?? const TopAnswers();
  return items == null ? const [] : top.suggest(items);
}
