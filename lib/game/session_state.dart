/// The live state of one running show. Immutable; only the reducer makes new
/// ones. Plain Dart only, and fully JSON-serialisable so any transport can
/// carry it.
library;

import 'content.dart';

enum Phase {
  /// The board is shown, no question open.
  overview,

  /// A question is open and nobody has buzzed.
  question,

  /// At least one team has buzzed; the first in the queue answers.
  buzzered,

  /// The question is resolved but still on screen.
  answerRevealed,

  /// Buzzers light up their team without a question, to check the hardware.
  buzzerTest,
}

enum MediaPlayback { stopped, playing, paused }

/// What players' devices are asked for during an answer round.
enum AnswerKind { text, choice, drawing }

class Team {
  const Team({required this.id, required this.name, this.points = 0});

  final String id;
  final String name;
  final int points;

  Team copyWith({String? name, int? points}) => Team(id: id, name: name ?? this.name, points: points ?? this.points);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'points': points};

  factory Team.fromJson(Map<String, dynamic> json) =>
      Team(id: json['id'] as String, name: json['name'] as String, points: (json['points'] as num?)?.toInt() ?? 0);
}

/// One team's submission in an answer round. Exactly the field matching the
/// round's [AnswerKind] is set.
class PlayerAnswer {
  const PlayerAnswer({this.text, this.choice, this.drawing});

  final String? text;

  /// Index into the question's answers.
  final int? choice;

  /// Encoded strokes; opaque to the game core.
  final String? drawing;

  bool matches(AnswerKind kind) => switch (kind) {
        AnswerKind.text => text != null && choice == null && drawing == null,
        AnswerKind.choice => choice != null && text == null && drawing == null,
        AnswerKind.drawing => drawing != null && text == null && choice == null,
      };

  Map<String, dynamic> toJson() => {
        if (text != null) 'text': text,
        if (choice != null) 'choice': choice,
        if (drawing != null) 'drawing': drawing,
      };

  factory PlayerAnswer.fromJson(Map<String, dynamic> json) => PlayerAnswer(
        text: json['text'] as String?,
        choice: (json['choice'] as num?)?.toInt(),
        drawing: json['drawing'] as String?,
      );
}

/// Players answering on their own devices. Submissions stay with the host
/// until the gamemaster reveals them.
class AnswerRound {
  const AnswerRound({required this.kind, this.open = true, this.revealed = false, this.answers = const {}});

  final AnswerKind kind;

  /// Whether submissions are still accepted.
  final bool open;
  final bool revealed;

  /// By team id.
  final Map<String, PlayerAnswer> answers;

  AnswerRound copyWith({bool? open, bool? revealed, Map<String, PlayerAnswer>? answers}) => AnswerRound(
        kind: kind,
        open: open ?? this.open,
        revealed: revealed ?? this.revealed,
        answers: answers ?? this.answers,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'open': open,
        'revealed': revealed,
        'answers': {for (final entry in answers.entries) entry.key: entry.value.toJson()},
      };

  factory AnswerRound.fromJson(Map<String, dynamic> json) => AnswerRound(
        kind: AnswerKind.values.byName(json['kind'] as String),
        open: json['open'] == true,
        revealed: json['revealed'] == true,
        answers: {
          for (final entry in (json['answers'] as Map? ?? const {}).entries)
            entry.key as String: PlayerAnswer.fromJson(Map<String, dynamic>.from(entry.value as Map)),
        },
      );
}

/// Something the gamemaster puts on top of the screen: a text card, an image,
/// or both. Stays until it is hidden.
class OverlayCard {
  const OverlayCard({this.title, this.text, this.image});

  final String? title;
  final String? text;

  /// A media file of the game.
  final String? image;

  bool get isEmpty => (title ?? '').trim().isEmpty && (text ?? '').trim().isEmpty && (image ?? '').isEmpty;

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (text != null) 'text': text,
        if (image != null) 'image': image,
      };

  factory OverlayCard.fromJson(Map<String, dynamic> json) => OverlayCard(
        title: json['title'] as String?,
        text: json['text'] as String?,
        image: json['image'] as String?,
      );
}

const Object _unset = Object();

class SessionState {
  const SessionState({
    this.seq = 0,
    this.gameId,
    this.teams = const [],
    this.phase = Phase.overview,
    this.groupId,
    this.current,
    this.played = const {},
    this.queueBuzzers = false,
    this.buzzQueue = const [],
    this.revealed = 0,
    this.imageFocus = 0,
    this.feudRevealed = const [],
    this.wrongAttempts = 0,
    this.media = MediaPlayback.stopped,
    this.music,
    this.answerRound,
    this.overlay,
  });

  /// Incremented on every accepted command; lets a client drop stale updates.
  final int seq;
  final String? gameId;
  final List<Team> teams;
  final Phase phase;

  /// The category group whose board is shown.
  final String? groupId;

  /// The open question, if any.
  final QuestionRef? current;

  /// [QuestionRef.key]s of questions already played.
  final Set<String> played;

  /// When true, later buzzes queue up behind the first instead of being lost.
  final bool queueBuzzers;

  /// Team ids in buzz order; the first is answering.
  final List<String> buzzQueue;

  /// How far the open question is revealed; see [Question.maxReveal].
  final int revealed;

  /// Progressing reveal with images: which revealed image is enlarged, 1-based;
  /// 0 shows the question's own image.
  final int imageFocus;

  /// Feud: indices of the answers uncovered so far.
  final List<int> feudRevealed;

  /// Feud: strikes of the answering team.
  final int wrongAttempts;

  /// Playback of the open question's own sound.
  final MediaPlayback media;

  /// The music slot playing (one of `musicSlots`), or null for silence.
  final String? music;
  final AnswerRound? answerRound;

  /// The card currently shown on top of the screen, if any.
  final OverlayCard? overlay;

  Team? team(String id) {
    for (final team in teams) {
      if (team.id == id) return team;
    }
    return null;
  }

  SessionState copyWith({
    int? seq,
    Object? gameId = _unset,
    List<Team>? teams,
    Phase? phase,
    Object? groupId = _unset,
    Object? current = _unset,
    Set<String>? played,
    bool? queueBuzzers,
    List<String>? buzzQueue,
    int? revealed,
    int? imageFocus,
    List<int>? feudRevealed,
    int? wrongAttempts,
    MediaPlayback? media,
    Object? music = _unset,
    Object? answerRound = _unset,
    Object? overlay = _unset,
  }) =>
      SessionState(
        seq: seq ?? this.seq,
        gameId: identical(gameId, _unset) ? this.gameId : gameId as String?,
        teams: teams ?? this.teams,
        phase: phase ?? this.phase,
        groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
        current: identical(current, _unset) ? this.current : current as QuestionRef?,
        played: played ?? this.played,
        queueBuzzers: queueBuzzers ?? this.queueBuzzers,
        buzzQueue: buzzQueue ?? this.buzzQueue,
        revealed: revealed ?? this.revealed,
        imageFocus: imageFocus ?? this.imageFocus,
        feudRevealed: feudRevealed ?? this.feudRevealed,
        wrongAttempts: wrongAttempts ?? this.wrongAttempts,
        media: media ?? this.media,
        music: identical(music, _unset) ? this.music : music as String?,
        answerRound: identical(answerRound, _unset) ? this.answerRound : answerRound as AnswerRound?,
        overlay: identical(overlay, _unset) ? this.overlay : overlay as OverlayCard?,
      );

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'gameId': gameId,
        'teams': [for (final team in teams) team.toJson()],
        'phase': phase.name,
        'groupId': groupId,
        'current': current?.key,
        'played': played.toList()..sort(),
        'queueBuzzers': queueBuzzers,
        'buzzQueue': buzzQueue,
        'revealed': revealed,
        'imageFocus': imageFocus,
        'feudRevealed': feudRevealed,
        'wrongAttempts': wrongAttempts,
        'media': media.name,
        'music': music,
        'answerRound': answerRound?.toJson(),
        'overlay': overlay?.toJson(),
      };

  factory SessionState.fromJson(Map<String, dynamic> json) => SessionState(
        seq: (json['seq'] as num?)?.toInt() ?? 0,
        gameId: json['gameId'] as String?,
        teams: [for (final team in json['teams'] as List? ?? const []) Team.fromJson(Map<String, dynamic>.from(team as Map))],
        phase: Phase.values.byName(json['phase'] as String? ?? Phase.overview.name),
        groupId: json['groupId'] as String?,
        current: QuestionRef.tryParse(json['current']),
        played: {...(json['played'] as List? ?? const []).cast<String>()},
        queueBuzzers: json['queueBuzzers'] == true,
        buzzQueue: (json['buzzQueue'] as List? ?? const []).cast<String>().toList(),
        revealed: (json['revealed'] as num?)?.toInt() ?? 0,
        imageFocus: (json['imageFocus'] as num?)?.toInt() ?? 0,
        feudRevealed: [for (final index in json['feudRevealed'] as List? ?? const []) (index as num).toInt()],
        wrongAttempts: (json['wrongAttempts'] as num?)?.toInt() ?? 0,
        media: MediaPlayback.values.byName(json['media'] as String? ?? MediaPlayback.stopped.name),
        music: json['music'] as String?,
        answerRound:
            json['answerRound'] == null ? null : AnswerRound.fromJson(Map<String, dynamic>.from(json['answerRound'] as Map)),
        overlay: json['overlay'] == null ? null : OverlayCard.fromJson(Map<String, dynamic>.from(json['overlay'] as Map)),
      );
}
