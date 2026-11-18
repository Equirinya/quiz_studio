/// What a question left behind when it was closed as played: the teams'
/// answers, the ratings, the points given and how far it was uncovered. A
/// question reopened "with its answers" picks up from here. Plain Dart,
/// JSON-serialisable.
///
/// Kept apart from [SessionState], which only lists the questions that have
/// one ([SessionState.storedRounds]): whiteboards add up to more than the
/// session document may hold, and the state goes out on every change.
library;

import 'companion.dart';
import 'last_standing.dart';
import 'rapid_fire.dart';
import 'session_state.dart';

class PlayedRound {
  const PlayedRound({
    this.revealed = 0,
    this.feudRevealed = const [],
    this.foundBy = const {},
    this.wrongAttempts = 0,
    this.answerRound,
    this.betting,
    this.results = const Results(),
    this.standing,
    this.rapidSteps = const {},
    this.notesTeams = const [],
    this.notes = const {},
    this.closedAtMillis,
  });

  /// The open question of [s] as it stands, or null when it left nothing
  /// worth bringing back (a buzzer question: its points are on the board).
  /// The answers are locked: the time to change them was over.
  static PlayedRound? of(SessionState s, {int? now}) {
    final round = s.answerRound;
    final played = PlayedRound(
      revealed: s.revealed,
      feudRevealed: s.feudRevealed,
      foundBy: s.foundBy,
      wrongAttempts: s.wrongAttempts,
      answerRound: round?.copyWith(open: false, endsAtMillis: null),
      betting: s.betting?.copyWith(open: false, shown: false),
      results: s.results,
      standing: s.standing,
      rapidSteps: s.rapidSteps,
      notesTeams: s.notesTeams,
      notes: s.notes,
      closedAtMillis: now,
    );
    return played.isEmpty ? null : played;
  }

  final int revealed;
  final List<int> feudRevealed;
  final Map<int, String> foundBy;
  final int wrongAttempts;
  final AnswerRound? answerRound;
  final Betting? betting;
  final Results results;
  final StandingPlay? standing;
  final Map<int, RapidStep> rapidSteps;
  final List<String> notesTeams;
  final Map<String, String> notes;

  /// Host clock, when the question was closed.
  final int? closedAtMillis;

  bool get isEmpty =>
      (answerRound == null || answerRound!.answers.isEmpty) &&
      results.isEmpty &&
      feudRevealed.isEmpty &&
      (betting == null || betting!.bets.isEmpty) &&
      standing == null &&
      rapidSteps.isEmpty &&
      notes.isEmpty;

  /// [s], just opened on this question, as it was left.
  SessionState restoreInto(SessionState s) => s.copyWith(
    revealed: revealed,
    feudRevealed: feudRevealed,
    foundBy: foundBy,
    wrongAttempts: wrongAttempts,
    answerRound: answerRound,
    betting: betting,
    results: results,
    standing: standing,
    rapidSteps: rapidSteps,
    notesTeams: notesTeams,
    notes: notes,
    // Nothing runs on a question brought back: the gamemaster sets a clock
    // or unlocks a team if it is to go on.
    timer: null,
  );

  Map<String, dynamic> toJson() => {
    if (revealed != 0) 'revealed': revealed,
    if (feudRevealed.isNotEmpty) 'feudRevealed': feudRevealed,
    if (foundBy.isNotEmpty) 'foundBy': {for (final entry in foundBy.entries) '${entry.key}': entry.value},
    if (wrongAttempts != 0) 'wrongAttempts': wrongAttempts,
    if (answerRound != null) 'answerRound': answerRound!.toJson(),
    if (betting != null) 'betting': betting!.toJson(),
    if (!results.isEmpty) 'results': results.toJson(),
    if (standing != null) 'standing': standing!.toJson(),
    if (rapidSteps.isNotEmpty) 'rapidSteps': {for (final MapEntry(:key, :value) in rapidSteps.entries) '$key': value.toJson()},
    if (notesTeams.isNotEmpty) 'notesTeams': notesTeams,
    if (notes.isNotEmpty) 'notes': notes,
    'closedAt': ?closedAtMillis,
  };

  /// Null for anything that is not a stored round.
  static PlayedRound? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      return PlayedRound(
        revealed: (json['revealed'] as num?)?.toInt() ?? 0,
        feudRevealed: [for (final index in json['feudRevealed'] as List? ?? const []) (index as num).toInt()],
        foundBy: {
          for (final entry in (json['foundBy'] as Map? ?? const {}).entries)
            if (int.tryParse('${entry.key}') != null) int.parse('${entry.key}'): '${entry.value}',
        },
        wrongAttempts: (json['wrongAttempts'] as num?)?.toInt() ?? 0,
        answerRound: json['answerRound'] is Map ? AnswerRound.fromJson(Map<String, dynamic>.from(json['answerRound'] as Map)) : null,
        betting: json['betting'] is Map ? Betting.fromJson(Map<String, dynamic>.from(json['betting'] as Map)) : null,
        results: Results.fromJson(json['results']),
        standing: StandingPlay.fromJson(json['standing']),
        rapidSteps: {
          for (final MapEntry(:key, :value) in (json['rapidSteps'] as Map? ?? const {}).entries)
            if (int.tryParse('$key') != null) int.parse('$key'): RapidStep.fromJson(value),
        },
        notesTeams: [for (final id in json['notesTeams'] as List? ?? const []) '$id'],
        notes: {for (final MapEntry(:key, :value) in (json['notes'] as Map? ?? const {}).entries) '$key': '$value'},
        closedAtMillis: (json['closedAt'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
