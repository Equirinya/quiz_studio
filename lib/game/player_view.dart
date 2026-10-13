/// What a player's device is told. The host builds this from the full state
/// and content, so answers never leave the host before they are revealed.
library;

import 'content.dart';
import 'reducer.dart';
import 'session_state.dart';

/// The session as [teamId] may see it, ready to send as JSON.
///
/// Left out on purpose: answer hints, which answers are correct before the
/// reveal, anything not yet revealed, other teams' submissions before the
/// gamemaster reveals them, and all questions other than the open one.
Map<String, dynamic> playerView(SessionState state, GameContent? game, String teamId) {
  final question = state.current == null ? null : game?.question(state.current!);
  final round = state.answerRound;
  return {
    'seq': state.seq,
    'phase': state.phase.name,
    'teamId': teamId,
    'teams': [for (final team in state.teams) team.toJson()],
    'buzzQueue': state.buzzQueue,
    'canBuzz': canBuzz(state, game, teamId),
    'question': question == null ? null : _visibleQuestion(state, question),
    'answerRound': round == null
        ? null
        : {
            'kind': round.kind.name,
            'open': round.open,
            'revealed': round.revealed,
            'mine': round.answers[teamId]?.toJson(),
            'submitted': round.answers.keys.toList(),
            if (round.revealed) 'answers': {for (final entry in round.answers.entries) entry.key: entry.value.toJson()},
          },
  };
}

Map<String, dynamic> _visibleQuestion(SessionState state, Question question) {
  final view = <String, dynamic>{
    'type': question.type.name,
    'text': question.text,
    if (question.description != null) 'description': question.description,
    'pointsPlus': question.pointsPlus,
    'pointsMinus': question.pointsMinus,
  };
  switch (question.type) {
    case QuestionType.abcd:
      final shown = state.revealed.clamp(0, question.answers.length);
      view['answerCount'] = question.answers.length;
      view['answers'] = question.answers.sublist(0, shown);
      if (state.revealed > question.answers.length) {
        view['answersCorrect'] = [
          for (var i = 0; i < question.answers.length; i++) i < question.answersCorrect.length && question.answersCorrect[i],
        ];
      }
    case QuestionType.progressingReveal:
      final shown = state.revealed.clamp(0, question.information.length);
      view['informationCount'] = question.information.length;
      view['information'] = question.information.sublist(0, shown);
    case QuestionType.feud:
      view['informationCount'] = question.information.length;
      view['wrongAttempts'] = state.wrongAttempts;
      view['information'] = {
        for (final index in state.feudRevealed)
          if (index >= 0 && index < question.information.length) '$index': question.information[index],
      };
    case QuestionType.free:
    case QuestionType.unsupported:
      break;
  }
  return view;
}
