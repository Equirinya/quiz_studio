/// What players' devices are told. The host builds this from the full state
/// and content, so answers never leave the host before they are revealed.
library;

import 'companion.dart';
import 'content.dart';
import 'reducer.dart';
import 'session_state.dart';

/// The session as any player may see it, ready to send as JSON.
///
/// Left out on purpose: answer hints, which answers are correct before the
/// reveal, anything not yet revealed, submissions before the gamemaster
/// reveals them, and all questions other than the open one.
Map<String, dynamic> publicView(SessionState state, GameContent? game) {
  final question = state.current == null ? null : game?.question(state.current!);
  final round = state.answerRound;
  return {
    'seq': state.seq,
    'phase': state.phase.name,
    'teams': [for (final team in state.teams) team.toJson()],
    'buzzQueue': state.buzzQueue,
    'buzzersOpen': buzzersOpen(state, game),
    'question': question == null ? null : _visibleQuestion(state, question),
    'answerRound': round == null
        ? null
        : {
            // Without the solution, and with the items to sort or assign
            // shuffled; the seed keeps the shuffle the same for everyone.
            'spec': round.spec.toPublicMap(state.current?.key ?? ''),
            'open': round.open,
            'openedAt': round.openedAtMillis,
            'endsAt': round.endsAtMillis,
            'submitted': [
              for (final entry in round.answers.entries)
                if (!entry.value.isEmpty) entry.key,
            ],
            'locked': [
              for (final entry in round.answers.entries)
                if (entry.value.locked) entry.key,
            ],
            // Only what the gamemaster has put on the big screen.
            'revealed': round.revealed,
            'answers': {
              for (final teamId in round.revealed)
                if (round.answers[teamId] != null) teamId: round.answers[teamId]!.toJson(),
            },
            'verdicts': {
              for (final teamId in round.revealed)
                if (round.verdicts.containsKey(teamId)) teamId: round.verdicts[teamId],
            },
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

/// A player device's reading of [publicView].
class PublicView {
  PublicView(this.json);

  final Map<String, dynamic> json;

  int get seq => (json['seq'] as num?)?.toInt() ?? 0;

  Phase get phase => Phase.values.firstWhere((p) => p.name == json['phase'], orElse: () => Phase.overview);

  List<Team> get teams =>
      [for (final team in json['teams'] as List? ?? const []) Team.fromJson(Map<String, dynamic>.from(team as Map))];

  List<String> get buzzQueue => (json['buzzQueue'] as List? ?? const []).cast<String>();

  /// The open question as far as it is revealed, or null on the board.
  Map<String, dynamic>? get question =>
      json['question'] == null ? null : Map<String, dynamic>.from(json['question'] as Map);

  Map<String, dynamic>? get _round => json['answerRound'] == null ? null : Map<String, dynamic>.from(json['answerRound'] as Map);

  /// The companion screen to show, as the device may know it (see
  /// `CompanionSpec.toPublicMap`); null when no answers are collected.
  Map<String, dynamic>? get companion => _round == null ? null : Map<String, dynamic>.from(_round!['spec'] as Map? ?? const {});

  CompanionKind? get answerKind => CompanionKind.fromName(companion?['kind']);

  bool get answersOpen => _round?['open'] == true;

  /// Host clock; see `AnswerRound`.
  int? get answersOpenedAt => (_round?['openedAt'] as num?)?.toInt();

  int? get answersEndAt => (_round?['endsAt'] as num?)?.toInt();

  bool hasSubmitted(String teamId) => (_round?['submitted'] as List? ?? const []).contains(teamId);

  bool hasLocked(String teamId) => (_round?['locked'] as List? ?? const []).contains(teamId);

  bool isRevealed(String teamId) => (_round?['revealed'] as List? ?? const []).contains(teamId);

  bool? verdictOf(String teamId) => (_round?['verdicts'] as Map?)?[teamId] as bool?;

  /// Whether a buzz by [teamId] would count right now.
  bool canBuzz(String teamId) {
    if (json['buzzersOpen'] != true || !teams.any((team) => team.id == teamId)) return false;
    return phase != Phase.buzzered || !buzzQueue.contains(teamId);
  }
}
