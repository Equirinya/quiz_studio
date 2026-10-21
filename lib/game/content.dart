/// The content of a game as it is stored: category groups, categories and
/// questions. Plain Dart only: no Flutter and no Firebase types, so the same
/// models work on the host, on a controller and in tests.
///
/// Field names are the v1 Firestore field names; see the data model header in
/// firebase/firestore.rules.
library;

import 'cards.dart';
import 'companion.dart';
import 'matching.dart';
import 'top_answers.dart';
import 'rapid_fire.dart';

// Music slots and built-in effect keys (v1 names, also used as stored keys).
const String musicBackground = 'musicBackground';
const String musicCalm = 'musicCalm';
const String musicExciting = 'musicExciting';
const List<String> musicSlots = [musicBackground, musicCalm, musicExciting];

// Quiet loops that come with the app and keep the speakers from switching
// themselves off when no music should play. Played like music, but never set
// up per game: the slot names the bundled asset.
const String ambienceWhiteNoise = 'ambienceWhiteNoise';
const String ambienceSoftNoise = 'ambienceSoftNoise';
/// Sound effects that come with the app (assets/sounds/effects). Played
/// with the key `builtin:<id>`; a game's own effect of the same moment wins.
class BuiltinSound {
  const BuiltinSound(this.id, this.label, this.asset);

  final String id;
  final String label;
  final String asset;

  String get key => '$builtinSoundPrefix$id';
}

const String builtinSoundPrefix = 'builtin:';

/// Picked by Jacob from generated and CC0 sounds (credits in
/// assets/sounds/CREDITS.md). The first of each moment is its default.
const List<BuiltinSound> builtinSounds = [
  BuiltinSound('right_answer/right_answer', "Right answer", 'sounds/effects/right_answer/right_answer.mp3'),
  BuiltinSound('right_answer/ding_ding', "Ding ding", 'sounds/effects/right_answer/ding_ding.wav'),
  BuiltinSound('right_answer/voice_correct_female', "\"Correct!\" (female)", 'sounds/effects/right_answer/voice_correct_female.ogg'),
  BuiltinSound('right_answer/voice_correct_male', "\"Correct!\" (male)", 'sounds/effects/right_answer/voice_correct_male.ogg'),
  BuiltinSound('right_answer/confirm', "Confirm", 'sounds/effects/right_answer/confirm.ogg'),
  BuiltinSound('right_answer/counter_bell', "Counter bell", 'sounds/effects/right_answer/counter_bell.ogg'),
  BuiltinSound('wrong_answer/bwomp', "Bwomp", 'sounds/effects/wrong_answer/bwomp.wav'),
  BuiltinSound('wrong_answer/voice_wrong_female', "\"Wrong!\" (female)", 'sounds/effects/wrong_answer/voice_wrong_female.ogg'),
  BuiltinSound('wrong_answer/voice_wrong_male', "\"Wrong!\" (male)", 'sounds/effects/wrong_answer/voice_wrong_male.ogg'),
  BuiltinSound('wrong_answer/error_low', "Error, low", 'sounds/effects/wrong_answer/error_low.ogg'),
  BuiltinSound('wrong_answer/error_short', "Error, short", 'sounds/effects/wrong_answer/error_short.ogg'),
  BuiltinSound('fanfare/fanfare', "Fanfare", 'sounds/effects/fanfare/fanfare.mp3'),
  BuiltinSound('fanfare/brass', "Brass fanfare", 'sounds/effects/fanfare/brass.wav'),
  BuiltinSound('fanfare/voice_congratulations', "\"Congratulations!\"", 'sounds/effects/fanfare/voice_congratulations.ogg'),
  BuiltinSound('question_open/brass_stab', "Brass stab", 'sounds/effects/question_open/brass_stab.wav'),
  BuiltinSound('reveal/pluck', "Pluck", 'sounds/effects/reveal/pluck.ogg'),
  BuiltinSound('reveal/rise_high', "Rise", 'sounds/effects/reveal/rise_high.ogg'),
  BuiltinSound('reveal/pop_up', "Pop up", 'sounds/effects/reveal/pop_up.wav'),
  BuiltinSound('reveal/rise_soft', "Soft rise", 'sounds/effects/reveal/rise_soft.ogg'),
  BuiltinSound('countdown/alarm_clock_ticking', "Ticking clock", 'sounds/effects/countdown/alarm_clock_ticking.ogg'),
  BuiltinSound('times_up/game_show_buzzer', "Game-show buzzer", 'sounds/effects/times_up/game_show_buzzer.wav'),
  BuiltinSound('lock_in/pop', "Pop", 'sounds/effects/lock_in/pop.wav'),
  BuiltinSound('lock_in/select', "Select", 'sounds/effects/lock_in/select.ogg'),
  BuiltinSound('next_item/woodblock', "Woodblock", 'sounds/effects/next_item/woodblock.wav'),
  BuiltinSound('steal/riser', "Riser", 'sounds/effects/steal/riser.wav'),
  BuiltinSound('applause/crowd_40', "Applause", 'sounds/effects/applause/crowd_40.ogg'),
  BuiltinSound('applause/bar_short', "Applause, short", 'sounds/effects/applause/bar_short.ogg'),
  BuiltinSound('drumroll/snare', "Drumroll", 'sounds/effects/drumroll/snare.ogg'),
  BuiltinSound('joke/rimshot', "Ba-dum-tss", 'sounds/effects/joke/rimshot.ogg'),
  BuiltinSound('announcer/ready', "\"Ready\"", 'sounds/effects/announcer/ready.ogg'),
  BuiltinSound('announcer/set', "\"Set\"", 'sounds/effects/announcer/set.ogg'),
  BuiltinSound('announcer/go', "\"Go!\"", 'sounds/effects/announcer/go.ogg'),
  BuiltinSound('announcer/hurry_up', "\"Hurry up!\"", 'sounds/effects/announcer/hurry_up.ogg'),
  BuiltinSound('announcer/final_round', "\"Final round\"", 'sounds/effects/announcer/final_round.ogg'),
  BuiltinSound('announcer/its_a_tie', "\"It's a tie\"", 'sounds/effects/announcer/its_a_tie.ogg'),
  BuiltinSound('announcer/game_over', "\"Game over\"", 'sounds/effects/announcer/game_over.ogg'),
];

/// Buzzer sounds a team can have without uploading one. The first is what
/// every team gets until it picks another.
const List<BuiltinSound> builtinBuzzers = [
  BuiltinSound('buzzer/buzzer', "Buzzer", 'sounds/buzzers/buzzer.wav'),
  BuiltinSound('buzzer/power', "Power", 'sounds/buzzers/power.mp3'),
  BuiltinSound('buzzer/light', "Light", 'sounds/buzzers/light.mp3'),
  BuiltinSound('buzzer/soft', "Soft", 'sounds/buzzers/soft.wav'),
];

/// Music that comes with the app, played for a slot the game has no music for.
const Map<String, String> builtinMusic = {
  musicBackground: 'sounds/music/quiz_theme.mp3',
  musicCalm: 'sounds/music/chill.mp3',
  musicExciting: 'sounds/music/thrilling.mp3',
};

BuiltinSound? builtinBuzzer(String? key) => builtinBuzzers.where((sound) => sound.key == key).firstOrNull;

/// The ones the gamemaster plays by hand from the Effects sheet.
const List<String> handSoundMoments = ['applause', 'drumroll', 'joke', 'fanfare', 'countdown', 'times_up', 'announcer'];

BuiltinSound? builtinSound(String key) =>
    builtinSounds.where((sound) => sound.key == key || sound.id == key).firstOrNull;

/// The folder of built-in sounds each moment can choose from.
const Map<String, String> effectMoments = {
  effectAnswerCorrect: 'right_answer',
  effectAnswerWrong: 'wrong_answer',
  effectReveal: 'reveal',
  effectQuestionOpen: 'question_open',
  effectLockIn: 'lock_in',
  effectNextItem: 'next_item',
  effectCountdown: 'countdown',
  effectTimesUp: 'times_up',
  effectSteal: 'steal',
  effectFanfare: 'fanfare',
};

/// The built-in sounds [effectKey] can be set to.
List<BuiltinSound> builtinSoundsFor(String effectKey) =>
    [for (final sound in builtinSounds) if (sound.id.split('/').first == effectMoments[effectKey]) sound];

/// Stored for a moment that should stay silent, even if a level above has a sound.
const String silentSound = 'off';

/// What plays for a built-in moment when the game set nothing for it.
const Map<String, String> defaultEffectSounds = {
  effectReveal: 'reveal/pluck',
  effectAnswerCorrect: 'right_answer/right_answer',
  effectAnswerWrong: 'wrong_answer/bwomp',
  effectQuestionOpen: 'question_open/brass_stab',
  effectLockIn: 'lock_in/pop',
  effectNextItem: 'next_item/woodblock',
  effectCountdown: 'countdown/alarm_clock_ticking',
  effectTimesUp: 'times_up/game_show_buzzer',
  effectSteal: 'steal/riser',
  effectFanfare: 'fanfare/fanfare',
};

const Map<String, String> ambienceAssets = {
  ambienceWhiteNoise: 'sounds/ambience/white_noise.wav',
  ambienceSoftNoise: 'sounds/ambience/soft_noise.wav',
};

const String effectReveal = 'musicEffectReveal';
const String effectAnswerCorrect = 'musicEffectAnswerCorrect';
const String effectAnswerWrong = 'musicEffectAnswerWrong';
const String effectAnswerClosed = 'musicEffectAnswerClosed';
// Moments added in v2; v1 never stored these.
const String effectQuestionOpen = 'musicEffectQuestionOpen';
const String effectLockIn = 'musicEffectLockIn';
const String effectNextItem = 'musicEffectNextItem';
const String effectCountdown = 'musicEffectCountdown';
const String effectTimesUp = 'musicEffectTimesUp';
const String effectSteal = 'musicEffectSteal';
const String effectFanfare = 'musicEffectFanfare';
const List<String> builtInEffects = [
  effectAnswerCorrect,
  effectAnswerWrong,
  effectAnswerClosed,
  effectReveal,
  effectQuestionOpen,
  effectLockIn,
  effectNextItem,
  effectCountdown,
  effectTimesUp,
  effectSteal,
  effectFanfare,
];

/// A copy of [value] holding only what JSON can represent.
Object? _jsonSafe(Object? value) {
  if (value == null || value is num || value is String || value is bool) return value;
  if (value is List) return [for (final item in value) _jsonSafe(item)];
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: _jsonSafe(entry.value),
    };
  }
  return null;
}

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

List<String> _strings(Object? v) => v is List ? [for (final e in v) e is String ? e : ''] : const [];

/// Music and sound effects set on one level (game, group, category or
/// question). A more specific level overrides a less specific one per slot.
class MusicConfig {
  const MusicConfig({this.slots = const {}, this.effects = const {}});

  /// Media file name per music slot ([musicSlots]).
  final Map<String, String> slots;

  /// Media file name per effect key, built-in and custom.
  final Map<String, String> effects;

  static const MusicConfig empty = MusicConfig();

  factory MusicConfig.fromMap(Map<String, dynamic> data) {
    final slots = <String, String>{
      for (final slot in musicSlots)
        if (_str(data[slot]) != null) slot: data[slot] as String,
    };
    final effects = <String, String>{
      // v1 read the built-in effects from the top level as well as the map.
      for (final key in builtInEffects)
        if (_str(data[key]) != null) key: data[key] as String,
    };
    final stored = data['musicEffects'];
    if (stored is Map) {
      for (final entry in stored.entries) {
        if (entry.key is String && _str(entry.value) != null) effects[entry.key as String] = entry.value as String;
      }
    }
    return MusicConfig(slots: slots, effects: effects);
  }

  /// Merges levels given most specific first (question, category, group, game).
  static MusicConfig resolve(Iterable<MusicConfig> mostSpecificFirst) {
    final slots = <String, String>{};
    final effects = <String, String>{};
    for (final level in mostSpecificFirst) {
      level.slots.forEach((key, value) => slots.putIfAbsent(key, () => value));
      level.effects.forEach((key, value) => effects.putIfAbsent(key, () => value));
    }
    return MusicConfig(slots: slots, effects: effects);
  }

  /// Files to download: built-in sounds and silence come with the app.
  Iterable<String> get mediaPaths =>
      [...slots.values, ...effects.values].where((name) => !name.startsWith(builtinSoundPrefix) && name != silentSound);
}

enum QuestionType {
  free("Free Question"),
  abcd("ABCD"),
  progressingReveal("Progressing Reveal"),
  feud("Survey duel"),
  connections("Word groups"),
  rapidFire("Fragenhagel"),
  matching("Matching"),
  topAnswers("Top answers"),
  unsupported("Unsupported");

  /// Played only on the teams' own devices: without them there is nothing
  /// to answer with.
  bool get needsDevices => this == connections || this == matching;

  const QuestionType(this.uiString);

  final String uiString;

  factory QuestionType.fromString(Object? type) =>
      QuestionType.values.firstWhere((e) => e.name == type, orElse: () => QuestionType.unsupported);
}

class Question {
  Question({
    required this.id,
    required this.type,
    this.text = '',
    this.description,
    this.answerHint,
    this.image,
    this.music,
    this.pointsPlus = 0,
    this.pointsMinus = 0,
    this.noBuzzer = false,
    this.answers = const [],
    this.answersCorrect = const [],
    this.information = const [],
    this.informationImages = const [],
    this.informationMusic = const [],
    this.percentages = const [],
    this.absoluteValues = false,
    this.pictureStrip = true,
    this.connectionGroups = const [],
    this.rapidFire,
    this.matching,
    this.topAnswers,
    this.sounds = MusicConfig.empty,
    this.data = const {},
  });

  final String id;
  final QuestionType type;
  final String text;

  /// Short label shown as a badge on the question card.
  final String? description;

  /// Only ever shown to the gamemaster.
  final String? answerHint;
  final String? image;
  final String? music;
  final int pointsPlus;
  final int pointsMinus;

  /// Free questions only: no buzzing, e.g. for estimation questions.
  final bool noBuzzer;

  // abcd
  final List<String> answers;
  final List<bool> answersCorrect;

  // progressingReveal and feud; the three lists are index-aligned
  final List<String> information;
  final List<String> informationImages;
  final List<String> informationMusic;

  // feud; index-aligned with [information]
  final List<double> percentages;
  final bool absoluteValues;

  /// progressingReveal with pictures: the row of small pictures under the
  /// question on the big screen. Stored only when switched off.
  final bool pictureStrip;

  /// connections: the four groups, easiest first. Stored as `connections`.
  final List<ConnectionGroup> connectionGroups;

  /// rapidFire: its items and how they are played. Stored as `rapidFire`.
  final RapidFire? rapidFire;

  /// matching: its pairs, in the right pairing. Stored as `matching`.
  final Matching? matching;

  /// topAnswers: the list and how teams answer. Stored as `topAnswers`.
  final TopAnswers? topAnswers;

  /// Whether this question can only be played with the teams' devices.
  bool get needsDevices => type.needsDevices ||
      (type == QuestionType.rapidFire && rapidFire?.mode == RapidMode.devices) ||
      (type == QuestionType.topAnswers && topAnswers?.onDevices == true);

  final MusicConfig sounds;

  /// The stored document, for fields this version doesn't know.
  final Map<String, dynamic> data;

  factory Question.fromMap(String id, Map<String, dynamic> data) {
    final correct = data['answersCorrect'];
    final percentages = data['informationPercentage'];
    return Question(
      id: id,
      type: QuestionType.fromString(data['type']),
      text: data['question'] is String ? data['question'] as String : '',
      description: _str(data['description']),
      answerHint: _str(data['answerHint']),
      image: _str(data['image']),
      music: _str(data['music']),
      pointsPlus: _int(data['pointsPlus']),
      pointsMinus: _int(data['pointsMinus']),
      noBuzzer: data['noBuzzer'] == true,
      answers: _strings(data['answers']),
      answersCorrect: correct is List ? [for (final e in correct) e == true] : const [],
      information: _strings(data['information']),
      informationImages: _strings(data['informationImage']),
      informationMusic: _strings(data['informationMusic']),
      percentages: percentages is List ? [for (final e in percentages) e is num ? e.toDouble() : 0.0] : const [],
      absoluteValues: data['absoluteValues'] == true,
      pictureStrip: data['pictureStrip'] != false,
      connectionGroups: QuestionType.fromString(data['type']) == QuestionType.connections
          ? ConnectionGroup.listFrom(data['connections'])
          : const [],
      rapidFire: QuestionType.fromString(data['type']) == QuestionType.rapidFire ? RapidFire.fromMap(data['rapidFire']) : null,
      matching: QuestionType.fromString(data['type']) == QuestionType.matching ? Matching.fromMap(data['matching']) : null,
      topAnswers: QuestionType.fromString(data['type']) == QuestionType.topAnswers ? TopAnswers.fromMap(data['topAnswers']) : null,
      sounds: MusicConfig.fromMap(data),
      data: data,
    );
  }

  /// The screen the teams' own devices show while this question is open,
  /// if it has one. For "pick one" the options are the ABCD answers.
  CompanionSpec? get companion {
    if (type == QuestionType.matching) {
      // Always on the teams' devices; the `companion` map holds the timer and
      // whether teams may lock in. Pictures are shown on the big screen and
      // named on the devices.
      final pairs = matching ?? const Matching();
      final numbers = pairs.rightNumbers(id);
      final stored = data['companion'] is Map ? Map<String, dynamic>.from(data['companion'] as Map) : <String, dynamic>{};
      final spec = CompanionSpec.fromMap({...stored, 'kind': CompanionKind.match.name});
      return CompanionSpec(
        kind: CompanionKind.match,
        timerSeconds: spec?.timerSeconds,
        lockable: spec?.lockable ?? true,
        options: [for (var i = 0; i < pairs.pairs.length; i++) pairs.leftLabel(i)],
        targets: [for (var i = 0; i < pairs.pairs.length; i++) pairs.rightLabel(i, numbers)],
      );
    }
    if (type == QuestionType.rapidFire) {
      // Right or wrong for each statement; a fresh round for every item.
      return rapidFire?.mode == RapidMode.devices ? const CompanionSpec(kind: CompanionKind.choice, options: rapidChoices) : null;
    }
    if (type == QuestionType.topAnswers) {
      // On the devices: one line per answer on the list. The `companion` map
      // holds the timer and whether teams may lock in.
      final top = topAnswers ?? const TopAnswers();
      if (!top.onDevices) return null;
      final stored = data['companion'] is Map ? Map<String, dynamic>.from(data['companion'] as Map) : <String, dynamic>{};
      final spec = CompanionSpec.fromMap({...stored, 'kind': CompanionKind.text.name});
      final rows = top.items.isEmpty ? 1 : top.items.length;
      return top.mode == TopAnswersMode.typed
          ? CompanionSpec(kind: CompanionKind.list, timerSeconds: spec?.timerSeconds, lockable: spec?.lockable ?? true, listRows: rows)
          : CompanionSpec(
              kind: CompanionKind.whiteboard,
              timerSeconds: spec?.timerSeconds,
              lockable: spec?.lockable ?? true,
              background: 'list',
              listRows: rows,
            );
    }
    if (type == QuestionType.connections) {
      // Always played on the teams' devices. The `companion` map holds the
      // timer, the mistakes allowed and whether teams may lock in.
      final stored = data['companion'] is Map ? Map<String, dynamic>.from(data['companion'] as Map) : <String, dynamic>{};
      return CompanionSpec.fromMap({...stored, 'kind': CompanionKind.connections.name})!.withGroups(connectionGroups);
    }
    final spec = CompanionSpec.fromMap(data['companion']);
    if (spec == null || spec.kind == CompanionKind.connections) return null;
    return spec.kind == CompanionKind.choice && spec.options.isEmpty ? spec.withOptions(answers) : spec;
  }

  bool get buzzerable => switch (type) {
        QuestionType.free => !noBuzzer,
        QuestionType.connections || QuestionType.matching => false,
        QuestionType.rapidFire => rapidFire?.mode != RapidMode.devices,
        QuestionType.topAnswers => topAnswers?.onDevices != true,
        _ => true,
      };

  /// Whether the generic "answer right / answer wrong" judging applies. Feud
  /// and Connections award points through their own flow, and so does a
  /// Fragenhagel played on the teams' devices.
  bool get defaultJudging => switch (type) {
        QuestionType.feud || QuestionType.connections => false,
        QuestionType.rapidFire => rapidFire?.mode != RapidMode.devices,
        // Buzzing for an answer on the list: Wrong as usual, Right by
        // picking the answer the team named.
        QuestionType.topAnswers => topAnswers?.onDevices != true,
        _ => true,
      };

  bool get hasMusic => music != null;

  /// The sound to play at reveal counter [revealed]: a Fragenhagel item's own
  /// one, or the question's.
  String? musicAt(int revealed) => type == QuestionType.rapidFire ? (rapidFire?.itemAt(revealed)?.music ?? music) : music;

  bool get hasInformationImages => informationImages.any((e) => e.isNotEmpty);

  /// Highest value of the session's reveal counter for this question. ABCD and
  /// progressing reveal each have one step beyond their list: showing which
  /// answers are correct, and the final step of the reveal.
  int get maxReveal => switch (type) {
        QuestionType.abcd => answers.length + 1,
        QuestionType.progressingReveal => information.length + 1,
        // One step per group, easiest first.
        QuestionType.connections => kConnectionsGroups,
        // One step per item; the last one ends the round.
        QuestionType.rapidFire => rapidFire?.items.length ?? 0,
        _ => 0,
      };

  /// Every media file this question needs, for caching ahead of the show.
  List<String> get mediaPaths => [
        ?image,
        ?music,
        ...informationImages.where((e) => e.isNotEmpty),
        ...informationMusic.where((e) => e.isNotEmpty),
        ?companion?.backgroundImage,
        ...?rapidFire?.mediaPaths,
        ...?matching?.mediaPaths,
        ...sounds.mediaPaths,
      ];
}

class Category {
  Category({
    required this.id,
    required this.name,
    this.groupId,
    this.index = 0,
    this.active = true,
    this.createdAtMillis,
    this.questions = const [],
    this.sounds = MusicConfig.empty,
    this.data = const {},
  });

  final String id;
  final String name;
  final String? groupId;

  /// Position within the group.
  final int index;
  final bool active;
  final int? createdAtMillis;

  /// Sorted by [Question.pointsPlus], ascending.
  final List<Question> questions;
  final MusicConfig sounds;
  final Map<String, dynamic> data;

  /// Cards offered while one of this category's questions is open.
  List<CueCard> get cards => CueCard.listFrom(data['cards']);
}

/// How a category group is shown on the presenter.
enum BoardType {
  display('Display Board'),
  wheel('Wheel Playboard'),
  map('Map Playboard');

  const BoardType(this.uiString);

  final String uiString;

  String get databaseString => 'category_$name';

  factory BoardType.fromDatabase(Object? value) =>
      BoardType.values.firstWhere((e) => e.databaseString == value, orElse: () => BoardType.wheel);
}

class CategoryGroup {
  CategoryGroup({
    required this.id,
    this.name = '',
    this.type = BoardType.wheel,
    this.index = 0,
    this.color,
    this.accentColor,
    this.text,
    this.imagePath,
    this.connections,
    this.splitPointFields = false,
    this.categories = const [],
    this.sounds = MusicConfig.empty,
    this.data = const {},
  });

  /// Id of the implicit group holding categories that belong to no group.
  static const String ungroupedId = '';

  final String id;
  final String name;
  final BoardType type;
  final int index;

  /// ARGB, as stored.
  final int? color;
  final int? accentColor;

  /// Display boards only.
  final String? text;
  final String? imagePath;
  final String? connections;

  /// Wheel only: split a point field when a value appears more than once.
  final bool splitPointFields;
  final List<Category> categories;
  final MusicConfig sounds;
  final Map<String, dynamic> data;

  bool get isUngrouped => id == ungroupedId;

  /// Cards offered while this board is played.
  List<CueCard> get cards => CueCard.listFrom(data['cards']);

  Iterable<String> get mediaPaths => [?imagePath, ...sounds.mediaPaths];
}

/// Addresses one question. Sessions store these instead of v1's
/// "categoryIndex:questionIndex", which broke whenever content was reordered.
class QuestionRef {
  const QuestionRef(this.categoryId, this.questionId);

  final String categoryId;
  final String questionId;

  String get key => '$categoryId/$questionId';

  static QuestionRef? tryParse(Object? key) {
    if (key is! String) return null;
    final slash = key.indexOf('/');
    if (slash <= 0 || slash == key.length - 1) return null;
    return QuestionRef(key.substring(0, slash), key.substring(slash + 1));
  }

  @override
  bool operator ==(Object other) =>
      other is QuestionRef && other.categoryId == categoryId && other.questionId == questionId;

  @override
  int get hashCode => Object.hash(categoryId, questionId);

  @override
  String toString() => key;
}

/// A card prepared in the editor for the gamemaster to show during the
/// show: rules of a round, a sponsor's logo, a "back in ten minutes".
///
/// Stored as `cards` on the game, a group or a category. The game's list
/// also holds the pictures that come with the app ([builtinImages]): they are
/// offered unless switched off ([hidden]), and a game that never saved them
/// gets them appended ([withBuiltins]).
class CueCard {
  const CueCard({this.title = '', this.text = '', this.image, this.video, this.hidden = false});

  final String title;
  final String text;
  final String? image;

  /// A video clip; when set the card plays it instead of showing text.
  final String? video;

  /// Kept in the list but not offered during the show.
  final bool hidden;

  /// One of the pictures that come with the app.
  bool get isBuiltin => isBuiltinImage(image);

  /// Files of the game this card needs; built-in pictures come with the app.
  Iterable<String> get mediaPaths => [if (!isBuiltin) ?image, ?video];

  Map<String, dynamic> toMap() => {
        'title': title,
        'text': text,
        'image': image,
        'video': video,
        if (hidden) 'hidden': true,
      };

  static List<CueCard> listFrom(Object? stored) => [
        if (stored is List)
          for (final entry in stored)
            if (entry is Map)
              CueCard(
                title: entry['title'] is String ? entry['title'] as String : '',
                text: entry['text'] is String ? entry['text'] as String : '',
                image: _str(entry['image']),
                video: _str(entry['video']),
                hidden: entry['hidden'] == true,
              ),
      ];

  /// [cards] with every built-in picture they do not mention added at the end.
  static List<CueCard> withBuiltins(List<CueCard> cards) => [
        ...cards,
        for (final image in builtinImages)
          if (!cards.any((card) => card.image == image.name)) CueCard(image: image.name),
      ];
}

class GameContent {
  GameContent({
    required this.id,
    this.name = '',
    this.groups = const [],
    this.sounds = MusicConfig.empty,
    this.data = const {},
  });

  /// Cards of the whole game, switched off ones and built-in pictures
  /// included, in the order they are offered.
  List<CueCard> get cards => CueCard.withBuiltins(CueCard.listFrom(data['cards']));

  /// The cards to offer: those of the open question's category, then of its
  /// group (or the board shown when no question is open), then the game's.
  List<CueCard> cardsFor({QuestionRef? ref, String? groupId}) {
    final category = ref == null ? null : this.category(ref.categoryId);
    final group = ref == null ? this.group(groupId) : groupOfCategory(ref.categoryId);
    return [...?category?.cards, ...?group?.cards, ...cards].where((card) => !card.hidden).toList();
  }

  final String id;
  final String name;

  /// The stored game document.
  final Map<String, dynamic> data;

  /// Sorted by [CategoryGroup.index]; ungrouped categories come first, in a
  /// group with [CategoryGroup.ungroupedId].
  final List<CategoryGroup> groups;
  final MusicConfig sounds;

  /// Builds the game from its stored documents, each keyed by document id.
  ///
  /// `createdAt` values must already be milliseconds since epoch (or absent);
  /// converting database timestamps is the caller's job.
  factory GameContent.assemble({
    required String id,
    required Map<String, dynamic> game,
    required Map<String, Map<String, dynamic>> groups,
    required Map<String, Map<String, dynamic>> categories,
    required Map<String, Map<String, Map<String, dynamic>>> questions,
    bool activeOnly = true,
  }) {
    final byGroup = <String, List<Category>>{CategoryGroup.ungroupedId: []};
    for (final groupId in groups.keys) {
      byGroup[groupId] = [];
    }
    categories.forEach((categoryId, data) {
      final active = data['active'] != false;
      if (activeOnly && !active) return;
      final groupId = data['categoryGroup'];
      final target = groupId is String && byGroup.containsKey(groupId) ? groupId : CategoryGroup.ungroupedId;
      final categoryQuestions = [
        for (final entry in (questions[categoryId] ?? const <String, Map<String, dynamic>>{}).entries)
          Question.fromMap(entry.key, entry.value),
      ]..sort((a, b) => a.pointsPlus.compareTo(b.pointsPlus));
      byGroup[target]!.add(Category(
        id: categoryId,
        name: data['name'] is String ? data['name'] as String : '',
        groupId: target == CategoryGroup.ungroupedId ? null : target,
        index: _int(data['categoryIndex']),
        active: active,
        createdAtMillis: data['createdAt'] is int ? data['createdAt'] as int : null,
        questions: categoryQuestions,
        sounds: MusicConfig.fromMap(data),
        data: data,
      ));
    });
    for (final list in byGroup.values) {
      list.sort((a, b) {
        if (a.index != b.index) return a.index.compareTo(b.index);
        return (a.createdAtMillis ?? 0).compareTo(b.createdAtMillis ?? 0);
      });
    }

    final result = <CategoryGroup>[
      for (final entry in groups.entries)
        CategoryGroup(
          id: entry.key,
          name: entry.value['name'] is String ? entry.value['name'] as String : '',
          type: BoardType.fromDatabase(entry.value['categoryGroupType']),
          index: _int(entry.value['categoryGroupIndex']),
          color: entry.value['color'] is int ? entry.value['color'] as int : null,
          accentColor: entry.value['accentColor'] is int ? entry.value['accentColor'] as int : null,
          text: _str(entry.value['text']),
          imagePath: _str(entry.value['imagePath']),
          connections: _str(entry.value['connections']),
          splitPointFields: entry.value['splitPointFields'] == true,
          categories: byGroup[entry.key]!,
          sounds: MusicConfig.fromMap(entry.value),
          data: entry.value,
        ),
    ]..sort((a, b) => a.index.compareTo(b.index));
    final ungrouped = byGroup[CategoryGroup.ungroupedId]!;
    if (ungrouped.isNotEmpty) {
      result.insert(0, CategoryGroup(id: CategoryGroup.ungroupedId, categories: ungrouped));
    }

    return GameContent(
      id: id,
      name: game['name'] is String ? game['name'] as String : '',
      groups: result,
      sounds: MusicConfig.fromMap(game),
      data: game,
    );
  }

  /// The game as plain JSON, to hand to a controller over the local network.
  /// It is the input of [GameContent.assemble] again, so [GameContent.fromJson]
  /// rebuilds exactly this content. Values JSON cannot carry (database
  /// timestamps and the like) are dropped; nothing the show needs is among
  /// them.
  Map<String, dynamic> toJson() => {
        'id': id,
        'game': _jsonSafe(data),
        'groups': {
          for (final group in groups)
            if (!group.isUngrouped) group.id: _jsonSafe(group.data),
        },
        'categories': {
          for (final group in groups)
            for (final category in group.categories) category.id: _jsonSafe(category.data),
        },
        'questions': {
          for (final group in groups)
            for (final category in group.categories)
              category.id: {for (final question in category.questions) question.id: _jsonSafe(question.data)},
        },
      };

  factory GameContent.fromJson(Map<String, dynamic> json) {
    Map<String, Map<String, dynamic>> docs(Object? value) => {
          for (final entry in (value as Map? ?? const {}).entries)
            entry.key as String: Map<String, dynamic>.from(entry.value as Map),
        };
    return GameContent.assemble(
      id: json['id'] as String,
      game: Map<String, dynamic>.from(json['game'] as Map? ?? const {}),
      groups: docs(json['groups']),
      categories: docs(json['categories']),
      questions: {
        for (final entry in (json['questions'] as Map? ?? const {}).entries) entry.key as String: docs(entry.value),
      },
      // Whatever was filtered out is not in the JSON to begin with.
      activeOnly: false,
    );
  }

  CategoryGroup? group(String? id) {
    for (final group in groups) {
      if (group.id == id) return group;
    }
    return null;
  }

  CategoryGroup? groupOfCategory(String categoryId) {
    for (final group in groups) {
      if (group.categories.any((c) => c.id == categoryId)) return group;
    }
    return null;
  }

  Category? category(String categoryId) {
    for (final group in groups) {
      for (final category in group.categories) {
        if (category.id == categoryId) return category;
      }
    }
    return null;
  }

  Question? question(QuestionRef ref) {
    final questions = category(ref.categoryId)?.questions ?? const <Question>[];
    for (final question in questions) {
      if (question.id == ref.questionId) return question;
    }
    return null;
  }

  /// Music and effects in force for [ref], or for the group or whole game
  /// when no question is open.
  MusicConfig soundsFor({QuestionRef? ref, String? groupId}) {
    final category = ref == null ? null : this.category(ref.categoryId);
    final group = ref == null ? this.group(groupId) : groupOfCategory(ref.categoryId);
    return MusicConfig.resolve([
      if (ref != null) ?question(ref)?.sounds,
      ?category?.sounds,
      ?group?.sounds,
      sounds,
    ]);
  }

  /// Every media file the game needs, for caching ahead of the show.
  Set<String> get mediaPaths => {
        ...sounds.mediaPaths,
        // Built-in pictures come with the app; there is nothing to download.
        for (final card in cards) ...card.mediaPaths,
        for (final group in groups) ...[
          ...group.mediaPaths,
          for (final card in group.cards) ...card.mediaPaths,
          for (final category in group.categories) ...[
            ...category.sounds.mediaPaths,
            for (final card in category.cards) ...card.mediaPaths,
            for (final question in category.questions) ...question.mediaPaths,
          ],
        ],
      };
}
