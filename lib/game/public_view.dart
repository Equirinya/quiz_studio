/// What players' devices are told. The host builds this from the full state
/// and content, so answers never leave the host before they are revealed.
library;

import 'companion.dart';
import 'content.dart';
import 'reducer.dart';
import 'session_state.dart';

/// The oldest app a team's device may run to play along with this build as
/// the presenter. Raise it whenever a device needs to understand something
/// new in the public view, such as a new kind of companion screen; older
/// devices then ask to be updated instead of showing nothing.
const String kMinCompanionVersion = '2.0.0';

/// The session as any player may see it, ready to send as JSON.
///
/// Left out on purpose: answer hints, which answers are correct before the
/// reveal, anything not yet revealed, submissions before the gamemaster
/// reveals them, and all questions other than the open one.
///
/// With [teamId] the view is for that team's devices only and adds, under
/// `own`, what only they may see: their own answer and, in Connections,
/// the groups they found. It must never reach another team.
Map<String, dynamic> publicView(SessionState state, GameContent? game, {String? teamId}) {
  final question = state.current == null ? null : game?.question(state.current!);
  final round = state.answerRound;
  final seed = state.current?.key ?? '';
  return {
    'seq': state.seq,
    'minAppVersion': kMinCompanionVersion,
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
                if (round.answers[teamId] != null) teamId: _shareable(round.answers[teamId]!),
            },
            // Connections: how far each team got, but not with which words.
            if (round.kind == CompanionKind.connections)
              'progress': {
                for (final entry in round.answers.entries)
                  if (entry.value.connections != null)
                    entry.key: {
                      'solved': entry.value.connections!.solved,
                      'mistakes': entry.value.connections!.mistakes,
                    },
              },
            'verdicts': {
              for (final teamId in round.revealed)
                if (round.verdicts.containsKey(teamId)) teamId: round.verdicts[teamId],
            },
          },
    if (teamId != null && state.team(teamId) != null) 'own': _own(state, round, teamId, seed),
  };
}

/// An answer as everyone may see it once it is on the big screen. A team's
/// Connections guesses would tell which words belong together, so only the
/// counts go out.
Map<String, dynamic> _shareable(PlayerAnswer answer) {
  final json = answer.toJson()..remove('connections');
  final progress = answer.connections;
  if (progress != null) json['connections'] = {'solved': progress.solved, 'mistakes': progress.mistakes};
  return json;
}

/// What one team's devices see beyond the shared view.
Map<String, dynamic> _own(SessionState state, AnswerRound? round, String teamId, String seed) {
  final answer = round?.answers[teamId];
  if (round == null || answer == null) return const {};
  if (round.kind != CompanionKind.connections) return {'answer': answer.toJson()};
  final progress = answer.connections ?? const ConnectionsProgress();
  final order = connectionsOrder(seed);
  final positionOf = {for (final (position, index) in order.indexed) index: position};
  return {
    'locked': answer.locked,
    if (answer.lockedAtMillis != null) 'lockedAt': answer.lockedAtMillis,
    'connections': {
      'solved': [for (final level in progress.solved) _groupView(round.spec, level, positionOf)],
      // In shown places, so the device can tell a repeat before sending it.
      'wrong': [
        for (final guess in progress.wrong) [for (final index in guess) positionOf[index]],
      ],
      'oneAway': progress.oneAway,
      'mistakes': progress.mistakes,
      'finished': progress.finished(round.spec),
    },
  };
}

/// A found or revealed group: its level, name, words, and where its words
/// are in the shown order.
Map<String, dynamic> _groupView(CompanionSpec spec, int level, Map<int, int> positionOf) {
  final group = level < spec.groups.length ? spec.groups[level] : const ConnectionGroup();
  return {
    'level': level,
    'name': group.name,
    'words': group.words,
    'positions': [for (var i = 0; i < kConnectionsGroupSize; i++) positionOf[level * kConnectionsGroupSize + i]],
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
    case QuestionType.topAnswers:
      final items = question.topAnswers?.items ?? const [];
      view['informationCount'] = items.length;
      view['information'] = {
        for (final index in state.feudRevealed)
          if (index >= 0 && index < items.length) '$index': items[index].answer,
      };
    case QuestionType.connections:
      // The groups the gamemaster has put on the big screen, easiest first.
      final spec = question.companion!;
      final order = connectionsOrder(state.current?.key ?? '');
      final positionOf = {for (final (position, index) in order.indexed) index: position};
      view['groupCount'] = kConnectionsGroups;
      view['revealedGroups'] = [
        for (var level = 0; level < state.revealed.clamp(0, kConnectionsGroups); level++) _groupView(spec, level, positionOf),
      ];
    case QuestionType.rapidFire:
      // Only the item being asked, without its answer or whether it is right.
      final rapid = question.rapidFire;
      final item = rapid?.itemAt(state.revealed);
      view['itemCount'] = rapid?.items.length ?? 0;
      view['itemIndex'] = state.revealed;
      if (item != null) view['text'] = item.question;
    case QuestionType.matching:
      // The pairs travel in the answer round, without their pairing.
      break;
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

  /// The oldest app version that may play along; see [kMinCompanionVersion].
  String? get minAppVersion => json['minAppVersion'] as String?;

  /// Whether the team may lock its answer in before the time is up.
  bool get lockable => companion?['lock'] != false;

  /// What only this team's devices see; empty in a shared view.
  Map<String, dynamic> get own => json['own'] is Map ? Map<String, dynamic>.from(json['own'] as Map) : const {};

  /// This team's own answer as the host has it, for kinds other than
  /// Connections.
  PlayerAnswer? get ownAnswer => own['answer'] is Map ? PlayerAnswer.fromJson(Map<String, dynamic>.from(own['answer'] as Map)) : null;

  /// When this team locked in, on the host's clock.
  int? get ownLockedAt => (own['lockedAt'] as num?)?.toInt() ?? ownAnswer?.lockedAtMillis;

  /// Connections: the sixteen words in the order shown.
  List<String> get connectionWords => (companion?['words'] as List? ?? const []).cast<String>();

  /// Connections: all four groups, easiest first, with the places of their
  /// words in the shown order; for checking a guess on the device.
  List<GroupView> get connectionGroups {
    final words = connectionWords;
    return [
      for (final (level, group) in (companion?['groups'] as List? ?? const []).indexed)
        if (group is Map)
          GroupView({
            'level': level,
            'name': group['name'],
            'positions': group['positions'],
            'words': [
              for (final p in group['positions'] as List? ?? const [])
                if (p is num && p.toInt() < words.length) words[p.toInt()],
            ],
          }),
    ];
  }

  int get connectionMistakesAllowed => (companion?['mistakes'] as num?)?.toInt() ?? 3;

  /// Connections: this team's progress; null before its first guess.
  ConnectionsView? get ownConnections =>
      own['connections'] is Map ? ConnectionsView(Map<String, dynamic>.from(own['connections'] as Map)) : null;

  /// Connections: groups on the big screen.
  List<GroupView> get revealedGroups => [
        for (final group in question?['revealedGroups'] as List? ?? const []) GroupView(Map<String, dynamic>.from(group as Map)),
      ];

  /// Connections: how far a team got, as (levels found, mistakes).
  ({List<int> solved, int mistakes})? progressOf(String teamId) {
    final entry = (_round?['progress'] as Map?)?[teamId];
    if (entry is! Map) return null;
    return (
      solved: [for (final e in entry['solved'] as List? ?? const []) (e as num).toInt()],
      mistakes: (entry['mistakes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Whether a buzz by [teamId] would count right now.
  bool canBuzz(String teamId) {
    if (json['buzzersOpen'] != true || !teams.any((team) => team.id == teamId)) return false;
    return phase != Phase.buzzered || !buzzQueue.contains(teamId);
  }
}

/// A Connections group as a device sees it once found or revealed.
class GroupView {
  GroupView(this.json);

  final Map<String, dynamic> json;

  int get level => (json['level'] as num?)?.toInt() ?? 0;

  String get name => json['name'] as String? ?? '';

  List<String> get words => (json['words'] as List? ?? const []).cast<String>();

  /// Places of its words in the shown order.
  List<int> get positions => [for (final p in json['positions'] as List? ?? const []) (p as num).toInt()];
}

/// A team's own Connections progress as its devices see it.
class ConnectionsView {
  ConnectionsView(this.json);

  final Map<String, dynamic> json;

  List<GroupView> get solved => [for (final g in json['solved'] as List? ?? const []) GroupView(Map<String, dynamic>.from(g as Map))];

  /// Wrong guesses, as places in the shown order.
  List<List<int>> get wrong => [
        for (final guess in json['wrong'] as List? ?? const []) [for (final p in guess as List) (p as num).toInt()],
      ];

  List<bool> get oneAway => [for (final e in json['oneAway'] as List? ?? const []) e == true];

  int get mistakes => (json['mistakes'] as num?)?.toInt() ?? 0;

  bool get finished => json['finished'] == true;
}
