/// The content of a game as it is stored: category groups, categories and
/// questions. Plain Dart only: no Flutter and no Firebase types, so the same
/// models work on the host, on a controller and in tests.
///
/// Field names are the v1 Firestore field names; see the data model header in
/// firebase/firestore.rules.
library;

import 'companion.dart';

// Music slots and built-in effect keys (v1 names, also used as stored keys).
const String musicBackground = 'musicBackground';
const String musicCalm = 'musicCalm';
const String musicExciting = 'musicExciting';
const List<String> musicSlots = [musicBackground, musicCalm, musicExciting];

const String effectReveal = 'musicEffectReveal';
const String effectAnswerCorrect = 'musicEffectAnswerCorrect';
const String effectAnswerWrong = 'musicEffectAnswerWrong';
const String effectAnswerClosed = 'musicEffectAnswerClosed';
const List<String> builtInEffects = [effectAnswerCorrect, effectAnswerWrong, effectAnswerClosed, effectReveal];

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

  Iterable<String> get mediaPaths => [...slots.values, ...effects.values];
}

enum QuestionType {
  free("Free Question"),
  abcd("ABCD"),
  progressingReveal("Progressing Reveal"),
  feud("Feud"),
  unsupported("Unsupported");

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
      sounds: MusicConfig.fromMap(data),
      data: data,
    );
  }

  /// The screen the teams' own devices show while this question is open,
  /// if it has one. For "pick one" the options are the ABCD answers.
  CompanionSpec? get companion {
    final spec = CompanionSpec.fromMap(data['companion']);
    if (spec == null) return null;
    return spec.kind == CompanionKind.choice && spec.options.isEmpty ? spec.withOptions(answers) : spec;
  }

  bool get buzzerable => type == QuestionType.free ? !noBuzzer : true;

  /// Whether the generic "answer right / answer wrong" judging applies. Feud
  /// awards points through its own flow.
  bool get defaultJudging => type != QuestionType.feud;

  bool get hasMusic => music != null;

  bool get hasInformationImages => informationImages.any((e) => e.isNotEmpty);

  /// Highest value of the session's reveal counter for this question. ABCD and
  /// progressing reveal each have one step beyond their list: showing which
  /// answers are correct, and the final step of the reveal.
  int get maxReveal => switch (type) {
        QuestionType.abcd => answers.length + 1,
        QuestionType.progressingReveal => information.length + 1,
        _ => 0,
      };

  /// Every media file this question needs, for caching ahead of the show.
  List<String> get mediaPaths => [
        ?image,
        ?music,
        ...informationImages.where((e) => e.isNotEmpty),
        ...informationMusic.where((e) => e.isNotEmpty),
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
class CueCard {
  const CueCard({this.title = '', this.text = '', this.image});

  final String title;
  final String text;
  final String? image;

  Map<String, dynamic> toMap() => {'title': title, 'text': text, 'image': image};

  static List<CueCard> listFrom(Object? stored) => [
        if (stored is List)
          for (final entry in stored)
            if (entry is Map)
              CueCard(
                title: entry['title'] is String ? entry['title'] as String : '',
                text: entry['text'] is String ? entry['text'] as String : '',
                image: _str(entry['image']),
              ),
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

  /// Cards prepared for this game; stored as `cards` on the game document.
  List<CueCard> get cards => CueCard.listFrom(data['cards']);

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
        for (final card in cards) ?card.image,
        for (final group in groups) ...[
          ...group.mediaPaths,
          for (final category in group.categories) ...[
            ...category.sounds.mediaPaths,
            for (final question in category.questions) ...question.mediaPaths,
          ],
        ],
      };
}
