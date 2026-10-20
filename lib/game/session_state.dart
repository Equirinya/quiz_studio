/// The live state of one running show. Immutable; only the reducer makes new
/// ones. Plain Dart only, and fully JSON-serialisable so any transport can
/// carry it.
library;

import 'cards.dart';
import 'companion.dart';
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

class Team {
  const Team({required this.id, required this.name, this.points = 0, this.sound});

  final String id;
  final String name;
  final int points;

  /// The team's own buzzer sound: a file among the session's files. Null
  /// for the default sound.
  final String? sound;

  Team copyWith({String? name, int? points}) =>
      Team(id: id, name: name ?? this.name, points: points ?? this.points, sound: sound);

  Team withSound(String? sound) => Team(id: id, name: name, points: points, sound: sound);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'points': points, if (sound != null) 'sound': sound};

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String,
        points: (json['points'] as num?)?.toInt() ?? 0,
        sound: json['sound'] as String?,
      );
}

/// Something the gamemaster puts on top of the screen: a text card, an
/// image, a video, or text with a picture. A card stays until it is hidden;
/// a video takes itself off when it has played to the end.
class OverlayCard {
  const OverlayCard({this.title, this.text, this.image, this.video});

  final String? title;
  final String? text;

  /// A media file of the game.
  final String? image;

  /// A media file of the game; shown full screen, without the text.
  final String? video;

  bool get isEmpty =>
      (title ?? '').trim().isEmpty && (text ?? '').trim().isEmpty && (image ?? '').isEmpty && (video ?? '').isEmpty;

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (text != null) 'text': text,
        if (image != null) 'image': image,
        if (video != null) 'video': video,
      };

  factory OverlayCard.fromJson(Map<String, dynamic> json) => OverlayCard(
        title: json['title'] as String?,
        text: json['text'] as String?,
        image: json['image'] as String?,
        video: json['video'] as String?,
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
    this.cardAnimation = CardAnimation.fade,
    this.buzzQueue = const [],
    this.revealed = 0,
    this.imageFocus = 0,
    this.feudRevealed = const [],
    this.wrongAttempts = 0,
    this.media = MediaPlayback.stopped,
    this.music,
    this.ambience = ambienceSoftNoise,
    this.musicVolume = 100,
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

  /// How cards come on screen and go again.
  final CardAnimation cardAnimation;

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

  /// A noise from `ambienceAssets` that fills every silence, so the speakers
  /// never switch themselves off; null for none. Music and a question's own
  /// sound play instead of it while they play.
  final String? ambience;

  /// 0 to 100: how loud the music plays.
  final int musicVolume;
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
    CardAnimation? cardAnimation,
    List<String>? buzzQueue,
    int? revealed,
    int? imageFocus,
    List<int>? feudRevealed,
    int? wrongAttempts,
    MediaPlayback? media,
    Object? music = _unset,
    Object? ambience = _unset,
    int? musicVolume,
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
        cardAnimation: cardAnimation ?? this.cardAnimation,
        buzzQueue: buzzQueue ?? this.buzzQueue,
        revealed: revealed ?? this.revealed,
        imageFocus: imageFocus ?? this.imageFocus,
        feudRevealed: feudRevealed ?? this.feudRevealed,
        wrongAttempts: wrongAttempts ?? this.wrongAttempts,
        media: media ?? this.media,
        music: music is String? ? music : this.music,
        ambience: identical(ambience, _unset) ? this.ambience : ambience as String?,
        musicVolume: musicVolume ?? this.musicVolume,
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
        'cardAnimation': cardAnimation.name,
        'buzzQueue': buzzQueue,
        'revealed': revealed,
        'imageFocus': imageFocus,
        'feudRevealed': feudRevealed,
        'wrongAttempts': wrongAttempts,
        'media': media.name,
        'music': music,
        'ambience': ambience,
        'musicVolume': musicVolume,
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
        cardAnimation: CardAnimation.fromName(json['cardAnimation']),
        buzzQueue: (json['buzzQueue'] as List? ?? const []).cast<String>().toList(),
        revealed: (json['revealed'] as num?)?.toInt() ?? 0,
        imageFocus: (json['imageFocus'] as num?)?.toInt() ?? 0,
        feudRevealed: [for (final index in json['feudRevealed'] as List? ?? const []) (index as num).toInt()],
        wrongAttempts: (json['wrongAttempts'] as num?)?.toInt() ?? 0,
        media: MediaPlayback.values.byName(json['media'] as String? ?? MediaPlayback.stopped.name),
        music: json['music'] as String?,
        // Sessions from before the switch get it on, like new ones.
        ambience: json.containsKey('ambience') ? json['ambience'] as String? : ambienceSoftNoise,
        musicVolume: (json['musicVolume'] as num?)?.toInt().clamp(0, 100) ?? 100,
        answerRound:
            json['answerRound'] == null ? null : AnswerRound.fromJson(Map<String, dynamic>.from(json['answerRound'] as Map)),
        overlay: json['overlay'] == null ? null : OverlayCard.fromJson(Map<String, dynamic>.from(json['overlay'] as Map)),
      );
}
