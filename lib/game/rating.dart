/// What the gamemaster's "rate automatically" and scoring buttons send for
/// an answer round. Plain Dart.
library;

import 'commands.dart';
import 'companion.dart';
import 'content.dart';
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
        if (_final(round, command) && _changes(round, command, question)) command,
    ];

bool _final(AnswerRound round, Command command) {
  final teamId = switch (command) {
    RateAnswer(:final teamId) || AwardAnswer(:final teamId) || MarkTopAnswers(:final teamId) => teamId,
    _ => null,
  };
  return teamId != null && (!round.open || round.answers[teamId]?.locked == true);
}

bool _changes(AnswerRound round, Command command, Question question) => switch (command) {
      RateAnswer(:final teamId, :final correct) => round.verdicts[teamId] != correct ||
          round.awarded[teamId] != (correct == true ? question.pointsPlus : -question.pointsMinus),
      AwardAnswer(:final teamId, :final points) => round.awarded[teamId] != points,
      MarkTopAnswers(:final teamId, :final found) =>
        !round.awarded.containsKey(teamId) || !_sameSet(round.found[teamId] ?? const [], found),
      _ => true,
    };

bool _sameSet(List<int> a, List<int> b) => a.toSet().length == b.toSet().length && a.toSet().containsAll(b);

List<Command> _candidates(SessionState state, AnswerRound round, Question question) {
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
    final partial = partialScore(round.spec, answer);
    if (partial != null) {
      commands.add(
        partial.right == partial.of || partial.right == 0
            ? RateAnswer(team.id, correct: partial.right == partial.of)
            : AwardAnswer(team.id, partialPoints(partial, question.pointsPlus)),
      );
      continue;
    }
    final verdict = autoVerdict(round.spec, answer, choiceCorrect: question.answersCorrect);
    if (verdict != null) commands.add(RateAnswer(team.id, correct: verdict));
  }
  return commands;
}

/// Points for an estimate, shared out the way [scoring] says: a full hit is
/// rated right, nothing is rated wrong without taking points away.
List<Command> estimateRating(AnswerRound round, Question question, EstimateScoring scoring) => [
  for (final MapEntry(key: teamId, value: points) in estimatePoints(round.spec, round.answers, question.pointsPlus, scoring).entries)
    points == question.pointsPlus ? RateAnswer(teamId, correct: true) : AwardAnswer(teamId, points),
];

/// The answers on the top answers list that [team] found, as ticked so far.
List<int> foundBy(AnswerRound round, String teamId) => round.found[teamId] ?? const [];

/// [found] with answer [index] added or taken away.
List<int> toggled(List<int> found, int index) => found.contains(index) ? ([...found]..remove(index)) : [...found, index];

/// Suggestions for a team's typed answers, by line; null where a line
/// matches nothing on the list.
List<int?> suggestionsFor(Question question, PlayerAnswer? answer) {
  final items = answer?.items;
  final top = question.topAnswers ?? const TopAnswers();
  return items == null ? const [] : top.suggest(items);
}
