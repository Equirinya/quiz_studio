/// The tools an assistant gets for working on games: what each is called,
/// what it takes, and what it does. Plain Dart; where the games are kept is
/// behind [GameToolsBackend].
library;

import 'package:quiz_show/game/game.dart';

/// A request that cannot be carried out as asked; the message goes back to
/// the assistant so it can correct itself.
class ToolError implements Exception {
  const ToolError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reading and writing games on behalf of the signed-in user. Every method
/// may throw; a [ToolError] carries a message meant for the assistant.
abstract class GameToolsBackend {
  /// Games the user may edit in full, as (id, name).
  Future<List<({String id, String name})>> listGames();

  /// The whole game, inactive categories included.
  Future<GameContent> loadGame(String gameId);

  Future<String> createGame(String name);
  Future<String> addGroup(String gameId, String name, BoardType type, int index);
  Future<void> updateGroup(String gameId, String groupId, Map<String, dynamic> data);
  Future<void> deleteGroup(String gameId, String groupId);
  Future<String> addCategory(String gameId, String name, {String? groupId, required int index});
  Future<void> updateCategory(String gameId, String categoryId, Map<String, dynamic> data);
  Future<void> deleteCategory(String gameId, Category category);
  Future<String> addQuestion(String gameId, String categoryId, Map<String, dynamic> data);
  Future<void> updateQuestion(String gameId, String categoryId, String questionId, Map<String, dynamic> data);
  Future<void> deleteQuestion(String gameId, String categoryId, String questionId);

  /// Uploads the file at [path] on this computer into the game's media and
  /// returns the name to store.
  Future<String> uploadMedia(String gameId, String path);
}

/// One tool as MCP describes it.
class ToolSpec {
  const ToolSpec(this.name, this.description, this.inputSchema);

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  Map<String, dynamic> toJson() => {'name': name, 'description': description, 'inputSchema': inputSchema};
}

Map<String, dynamic> _object(Map<String, dynamic> properties, [List<String> required = const []]) => {
      'type': 'object',
      'properties': properties,
      'required': required,
      'additionalProperties': false,
    };

const Map<String, dynamic> _string = {'type': 'string'};

/// The fields of a question as the tools take them. Shared by add and update.
final Map<String, dynamic> _questionFields = {
  'type': {
    'type': 'string',
    'enum': ['free', 'abcd', 'progressingReveal', 'feud', 'connections', 'rapidFire', 'matching', 'topAnswers'],
    'description': 'free: plain question. abcd: 2 to 9 answer options (A, B, C, ...). progressingReveal: hints revealed one by one. '
        'feud ("Survey duel"): a survey; the team that buzzed uncovers answers until its third strike, then the other '
        'team may steal; each answer is worth a share of the points. '
        'topAnswers ("Top answers"): "name the five most popular ...": teams find answers on a list by buzzing or on '
        'their devices and get the points of each answer found, see "topAnswers". '
        'connections: sixteen words in four groups of four, solved by every team on its own '
        'device; each group found is worth a quarter of pointsPlus. '
        'rapidFire ("Fragenhagel"): many short questions in a row inside this one, see "rapidFire"; pointsPlus is '
        'per item. matching: pairs the teams put back together on their devices, see "pairs".',
  },
  'question': {'type': 'string', 'description': 'The question as shown to the audience.'},
  'answerHint': {'type': 'string', 'description': 'The answer or notes; only the gamemaster sees this.'},
  'label': {'type': 'string', 'description': 'Optional short badge shown on the question card, e.g. a sub-topic.'},
  'image': {'type': 'string', 'description': 'A picture shown with the question: a name from upload_media. "" removes it.'},
  'music': {'type': 'string', 'description': 'A sound played with the question: a name from upload_media. "" removes it.'},
  'pointsPlus': {
    'type': 'integer',
    'minimum': 0,
    'description': 'Points for a right answer. Questions sort by this unless the category has its own order '
        '(reorder_questions).',
  },
  'pointsMinus': {'type': 'integer', 'minimum': 0, 'description': 'Points taken for a wrong answer; usually 0 or half.'},
  'noBuzzer': {'type': 'boolean', 'description': 'free only: no buzzing, e.g. for estimation questions.'},
  'answers': {
    'type': 'array',
    'items': _string,
    'minItems': 2,
    'maxItems': 9,
    'description': 'abcd only: 2 to 9 options, shown as A, B, C, ...',
  },
  'correct': {
    'type': 'array',
    'items': {'type': 'boolean'},
    'minItems': 2,
    'maxItems': 9,
    'description': 'abcd only: which of the options are right, one entry per answer.',
  },
  'information': {
    'type': 'array',
    'items': _string,
    'description': 'progressingReveal: the hints in the order they are revealed. feud: the answers on the board.',
  },
  'informationImages': {
    'type': 'array',
    'items': _string,
    'description': 'progressingReveal only, given together with "information": a picture per hint, names from '
        'upload_media, "" for none. A hint may be "" when its picture says it all.',
  },
  'informationMusic': {
    'type': 'array',
    'items': _string,
    'description': 'progressingReveal only, given together with "information": a sound per hint, "" for none.',
  },
  'pictureStrip': {
    'type': 'boolean',
    'description': 'progressingReveal with pictures: the row of small pictures under the question. Default true.',
  },
  'absoluteValues': {
    'type': 'boolean',
    'description': 'feud only: "values" are counts (e.g. votes) rather than percentages.',
  },
  'rapidFire': {
    'type': 'object',
    'description': 'rapidFire only: the items and how they are played.',
    'properties': {
      'mode': {
        'type': 'string',
        'enum': ['buzzer', 'devices'],
        'description': 'buzzer (default): teams buzz, the gamemaster judges, a right answer moves on. devices: each '
            'item is a statement every team marks right or wrong on its own device.',
      },
      'progress': {
        'type': 'string',
        'enum': ['off', 'bar', 'dots', 'battery', 'thermometer', 'flux'],
        'description': 'What shows on the big screen how far the round has come. Default bar; flux is a flux capacitor.',
      },
      'items': {
        'type': 'array',
        'minItems': 1,
        'items': {
          'type': 'object',
          'properties': {
            'question': {'type': 'string', 'description': 'The question, or in devices mode the statement.'},
            'answer': {'type': 'string', 'description': 'buzzer mode: the answer, for the gamemaster.'},
            'true': {'type': 'boolean', 'description': 'devices mode: whether the statement is right. Default true.'},
            'image': {'type': 'string', 'description': 'Optional picture, a name from upload_media.'},
            'music': {'type': 'string', 'description': 'Optional sound, e.g. a soundtrack to guess.'},
          },
          'required': ['question'],
        },
      },
    },
    'required': ['items'],
  },
  'topAnswers': {
    'type': 'object',
    'description': 'topAnswers only: the list and how teams answer.',
    'properties': {
      'mode': {
        'type': 'string',
        'enum': ['buzzer', 'typed', 'whiteboard'],
        'description': 'buzzer (default): a team buzzes and names an answer, the gamemaster taps it and the team gets its '
            'points. typed: every team types a list on its device. whiteboard: every team writes on a numbered whiteboard. '
            'On the devices the gamemaster ticks what each team found.',
      },
      'items': {
        'type': 'array',
        'minItems': 1,
        'description': 'The answers, most popular first. Other spellings to accept go after a slash: "The Lion King / Lion King".',
        'items': {
          'type': 'object',
          'properties': {
            'answer': _string,
            'points': {'type': 'integer', 'description': 'Optional; without it the answer is worth pointsPlus.'},
          },
          'required': ['answer'],
        },
      },
    },
    'required': ['items'],
  },
  'pairs': {
    'type': 'array',
    'minItems': 2,
    'description': 'matching only: the pairs in the RIGHT pairing; the devices show them shuffled. Each side is a '
        'text, a picture (a name from upload_media; only the big screen shows it) or both.',
    'items': {
      'type': 'object',
      'properties': {
        'left': _string,
        'right': _string,
        'leftImage': _string,
        'rightImage': _string,
      },
    },
  },
  'values': {
    'type': 'array',
    'items': {'type': 'number'},
    'description': 'feud only: one number per entry of information, as percentages that should add up to about 100.',
  },
  'groups': {
    'type': 'array',
    'minItems': 4,
    'maxItems': 4,
    'description': 'connections only: exactly four groups, easiest (yellow) first and hardest (purple) last. '
        'No word may appear twice. A good puzzle has red herrings: words that seem to fit another group.',
    'items': {
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'description': 'What the four words have in common.'},
        'words': {'type': 'array', 'items': _string, 'minItems': 4, 'maxItems': 4},
      },
      'required': ['name', 'words'],
    },
  },
  'companion': {
    'type': 'object',
    'description': 'Optional screen on the teams\' own devices while the question is open. For connections, '
        'matching and topAnswers the screen comes from the question; only timer, lock (and mistakes) apply.',
    'properties': {
      'kind': {
        'type': 'string',
        'enum': ['whiteboard', 'text', 'number', 'slider', 'choice', 'order', 'match', 'list'],
      },
      'timer': {'type': 'integer', 'description': 'Seconds until answers lock; leave out for no timer.'},
      'background': {
        'type': 'string',
        'enum': ['blank', 'lines', 'grid', 'list', 'image'],
        'description': 'whiteboard only. image: draw on backgroundImage, e.g. a map to mark.',
      },
      'backgroundImage': {'type': 'string', 'description': 'whiteboard with image background: a name from upload_media.'},
      'listRows': {'type': 'integer', 'description': 'whiteboard with list background, and list: how many lines.'},
      'min': {'type': 'number'},
      'max': {'type': 'number'},
      'step': {'type': 'number'},
      'unit': {'type': 'string'},
      'solution': {'type': 'number', 'description': 'number and slider: the right value.'},
      'tolerance': {'type': 'number', 'description': 'number and slider: how far from the solution still counts as right.'},
      'options': {
        'type': 'array',
        'items': _string,
        'description': 'order: the items in the RIGHT order. match: the left-hand items.',
      },
      'targets': {'type': 'array', 'items': _string, 'description': 'match: right-hand items, aligned with options.'},
      'lock': {'type': 'boolean', 'description': 'Whether teams may lock in before the time is up. Default true.'},
      'mistakes': {'type': 'integer', 'minimum': 1, 'maximum': 6, 'description': 'connections: wrong guesses allowed, default 3.'},
    },
    'required': ['kind'],
  },
};

final List<ToolSpec> gameToolSpecs = [
  ToolSpec('list_games', 'Lists the quiz games the user can edit.', _object({})),
  ToolSpec(
    'get_game',
    'Returns one game in full: its category groups (boards), their categories, and every question with all fields. '
        'Call this before changing a game, to see what is there and to get the ids.',
    _object({'gameId': _string}, ['gameId']),
  ),
  ToolSpec('create_game', 'Creates a new, empty game and returns its id.', _object({'name': _string}, ['name'])),
  ToolSpec(
    'add_category_group',
    'Adds a category group, which is one board of the show (e.g. "Round 1"). Categories belong to a group.',
    _object({
      'gameId': _string,
      'name': _string,
      'board': {
        'type': 'string',
        'enum': ['wheel', 'map', 'display'],
        'description': 'How the board is drawn. wheel is the default.',
      },
    }, ['gameId', 'name']),
  ),
  ToolSpec(
    'add_category',
    'Adds a category to a game, at the end of the given group. Returns its id.',
    _object({
      'gameId': _string,
      'name': _string,
      'groupId': {'type': 'string', 'description': 'From get_game. Leave out to add it outside any group.'},
    }, ['gameId', 'name']),
  ),
  ToolSpec(
    'update_category',
    'Renames a category or switches it in or out of play.',
    _object({
      'gameId': _string,
      'categoryId': _string,
      'name': _string,
      'active': {'type': 'boolean', 'description': 'Inactive categories stay in the editor but are not played.'},
    }, ['gameId', 'categoryId']),
  ),
  ToolSpec(
    'delete_category',
    'Deletes a category and all its questions. Cannot be undone; only do this when the user asked for it.',
    _object({'gameId': _string, 'categoryId': _string}, ['gameId', 'categoryId']),
  ),
  ToolSpec(
    'add_question',
    'Adds a question to a category, at its end when the category has its own order. Give at least the question '
        'text and pointsPlus. A typical category has five questions rising in value, e.g. 100 to 500. Pictures and '
        'sounds are names from upload_media.',
    _object({'gameId': _string, 'categoryId': _string, ..._questionFields}, ['gameId', 'categoryId', 'question']),
  ),
  ToolSpec(
    'update_question',
    'Changes fields of an existing question. Only the fields given are changed. When changing "type", give the '
        'fields the new type needs.',
    _object({'gameId': _string, 'categoryId': _string, 'questionId': _string, ..._questionFields},
        ['gameId', 'categoryId', 'questionId']),
  ),
  ToolSpec(
    'delete_question',
    'Deletes one question. Cannot be undone; only do this when the user asked for it.',
    _object({'gameId': _string, 'categoryId': _string, 'questionId': _string}, ['gameId', 'categoryId', 'questionId']),
  ),
  ToolSpec(
    'reorder_questions',
    'Puts the questions of a category in the given order, independent of their points. Use it when the order of '
        'play is not the order of value, e.g. on a display board played top to bottom.',
    _object({
      'gameId': _string,
      'categoryId': _string,
      'questionIds': {'type': 'array', 'items': _string, 'description': 'Every question of the category, in order.'},
    }, ['gameId', 'categoryId', 'questionIds']),
  ),
  ToolSpec(
    'update_category_group',
    'Changes a category group (board): its name, how it is drawn, and its look.',
    _object({
      'gameId': _string,
      'groupId': _string,
      'name': _string,
      'board': {'type': 'string', 'enum': ['wheel', 'map', 'display']},
      'text': {'type': 'string', 'description': 'display boards: text shown on the board. "" removes it.'},
      'color': {'type': 'string', 'description': 'Board colour as #RRGGBB. "" goes back to the theme\'s.'},
      'accentColor': {'type': 'string', 'description': 'Accent colour as #RRGGBB. "" goes back to the theme\'s.'},
      'splitPointFields': {'type': 'boolean', 'description': 'wheel only: split a point field when a value appears twice.'},
    }, ['gameId', 'groupId']),
  ),
  ToolSpec(
    'delete_category_group',
    'Deletes an empty category group. Delete or move its categories first. Only do this when the user asked for it.',
    _object({'gameId': _string, 'groupId': _string}, ['gameId', 'groupId']),
  ),
  ToolSpec(
    'set_cards',
    'Replaces the cards of a category or a group: what the gamemaster can put over the big screen while one of '
        'its questions (or the board) is in play, e.g. a line a mute guest "says" or a picture. Give exactly one of '
        'categoryId and groupId. Pass all cards; an empty list removes them.',
    _object({
      'gameId': _string,
      'categoryId': _string,
      'groupId': _string,
      'cards': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'title': _string,
            'text': _string,
            'image': {'type': 'string', 'description': 'A name from upload_media, or a built-in picture "builtin:<id>".'},
            'video': {'type': 'string', 'description': 'A name from upload_media; the card plays it.'},
            'hidden': {'type': 'boolean', 'description': 'Kept but not offered during the show.'},
            'style': {
              'type': 'string',
              'enum': [for (final style in CardStyle.values) style.name],
              'description': 'How the card looks: standard (default), silentFilm (an intertitle of an old silent '
                  'film, pictures in sepia), poster (big letters on the theme colour), plain (just the words).',
            },
          },
        },
      },
    }, ['gameId', 'cards']),
  ),
  ToolSpec(
    'set_sounds',
    'Sets music and sound effects of a question, category or group. Only do this when the user asks for sounds: '
        'they choose them in the app otherwise. A question needs categoryId and questionId; a category categoryId; '
        'a group groupId. Values: a name from upload_media, a built-in sound "builtin:<id>" (list_builtin_media), '
        '"off" for silence even if a level above has a sound, or "" to inherit again. Keys not given stay.',
    _object({
      'gameId': _string,
      'groupId': _string,
      'categoryId': _string,
      'questionId': _string,
      'music': {
        'type': 'object',
        'description': 'Music slots: ${musicSlots.join(', ')}.',
        'additionalProperties': _string,
      },
      'effects': {
        'type': 'object',
        'description': 'Moments: ${builtInEffects.join(', ')}.',
        'additionalProperties': _string,
      },
    }, ['gameId']),
  ),
  ToolSpec(
    'upload_media',
    'Uploads a picture, sound or video from this computer (the one running the app) into the game and returns '
        'the name to use in image, music and similar fields. Only upload files the user pointed you to.',
    _object({
      'gameId': _string,
      'path': {'type': 'string', 'description': 'Absolute path of the file on this computer.'},
    }, ['gameId', 'path']),
  ),
  ToolSpec(
    'list_builtin_media',
    'Lists the pictures and sound effects that come with the app, for cards and set_sounds.',
    _object({}),
  ),
];

/// Turns a tool's question arguments into the fields stored on a question.
/// With [partial] only what was given is returned, for an update; without it
/// a new question gets its defaults.
Map<String, dynamic> questionDataFromArgs(Map<String, dynamic> args, {required bool partial, QuestionType? existingType}) {
  final data = <String, dynamic>{};
  T? take<T>(String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is! T) throw ToolError('"$key" has the wrong type.');
    return value;
  }

  final typeName = take<String>('type');
  final type = typeName == null ? null : QuestionType.fromString(typeName);
  if (type == QuestionType.unsupported) throw ToolError('Unknown question type "$typeName".');
  if (type != null) data['type'] = type.name;
  final effective = type ?? existingType ?? QuestionType.free;

  final text = take<String>('question');
  if (text != null) data['question'] = text;
  if (!partial && (text == null || text.trim().isEmpty)) throw const ToolError('A question needs its text.');
  final hint = take<String>('answerHint');
  if (hint != null) data['answerHint'] = hint;
  final label = take<String>('label');
  if (label != null) data['description'] = label;
  for (final key in ['image', 'music']) {
    final name = take<String>(key);
    if (name != null) data[key] = name.isEmpty ? null : name;
  }
  for (final key in ['pointsPlus', 'pointsMinus']) {
    final points = take<num>(key);
    if (points == null) continue;
    if (points < 0) throw ToolError('"$key" cannot be negative.');
    data[key] = points.round();
  }
  final noBuzzer = take<bool>('noBuzzer');
  if (noBuzzer != null) data['noBuzzer'] = noBuzzer;

  List<S>? list<S>(String key) {
    final value = take<List<dynamic>>(key);
    if (value == null) return null;
    if (value.any((e) => e is! S)) throw ToolError('Every entry of "$key" must be a ${S == String ? 'string' : S}.');
    return value.cast<S>();
  }

  final answers = list<String>('answers');
  final correct = list<bool>('correct');
  if (answers != null || correct != null) {
    if (effective != QuestionType.abcd) throw const ToolError('"answers" and "correct" are for abcd questions.');
    bool fits(List<Object> list) => list.length >= kMinAbcdAnswers && list.length <= kMaxAbcdAnswers;
    if (answers != null && !fits(answers)) throw const ToolError('An abcd question needs 2 to 9 answers.');
    if (correct != null && !fits(correct)) throw const ToolError('"correct" needs 2 to 9 entries.');
    if (answers != null && correct != null && answers.length != correct.length) {
      throw const ToolError('"correct" needs one entry per answer.');
    }
    if (answers != null) data['answers'] = answers;
    if (correct != null) data['answersCorrect'] = correct;
  }
  if (!partial && effective == QuestionType.abcd && (answers == null || correct == null)) {
    throw const ToolError('An abcd question needs "answers" and "correct", one entry per answer each.');
  }

  final information = list<String>('information');
  final values = list<num>('values');
  if (information != null || values != null) {
    if (effective != QuestionType.feud && effective != QuestionType.progressingReveal) {
      throw const ToolError('"information" is for progressingReveal and feud questions.');
    }
    if (values != null && effective != QuestionType.feud) throw const ToolError('"values" is for feud questions.');
    if (information != null) {
      data['information'] = information;
      if (effective == QuestionType.progressingReveal) {
        // The three lists are stored index-aligned.
        for (final (arg, stored) in [('informationImages', 'informationImage'), ('informationMusic', 'informationMusic')]) {
          final media = list<String>(arg) ?? const [];
          if (media.length > information.length) throw ToolError('"$arg" has more entries than "information".');
          data[stored] = [for (var i = 0; i < information.length; i++) i < media.length ? media[i] : ''];
        }
      }
    }
    if (values != null) {
      if (information != null && values.length != information.length) {
        throw const ToolError('"values" needs one number per entry of "information".');
      }
      data['informationPercentage'] = [for (final v in values) v.toDouble()];
    }
  }
  if (!partial && effective == QuestionType.feud && (information == null || values == null)) {
    throw const ToolError('A feud question needs "information" and "values" of equal length.');
  }
  if (information == null && (args['informationImages'] != null || args['informationMusic'] != null)) {
    throw const ToolError('Give "informationImages" and "informationMusic" together with "information".');
  }
  final absolute = take<bool>('absoluteValues');
  if (absolute != null) {
    if (effective != QuestionType.feud) throw const ToolError('"absoluteValues" is for feud questions.');
    data['absoluteValues'] = absolute;
  }
  final strip = take<bool>('pictureStrip');
  if (strip != null) {
    if (effective != QuestionType.progressingReveal) throw const ToolError('"pictureStrip" is for progressingReveal questions.');
    data['pictureStrip'] = strip;
  }

  final rapid = take<Map<dynamic, dynamic>>('rapidFire');
  if (rapid != null) {
    if (effective != QuestionType.rapidFire) throw const ToolError('"rapidFire" is for rapidFire questions.');
    final mode = rapid['mode'] ?? RapidMode.buzzer.name;
    if (!RapidMode.values.any((m) => m.name == mode)) throw const ToolError('"mode" must be buzzer or devices.');
    final progress = rapid['progress'] ?? ProgressStyle.bar.name;
    if (!ProgressStyle.values.any((p) => p.name == progress)) throw ToolError('Unknown "progress" "$progress".');
    final items = rapid['items'];
    if (items is! List || items.isEmpty || items.any((i) => i is! Map || i['question'] is! String || (i['question'] as String).trim().isEmpty)) {
      throw const ToolError('"rapidFire" needs "items", each with its "question".');
    }
    data['rapidFire'] = RapidFire(
      mode: RapidMode.fromName(mode),
      progress: ProgressStyle.fromName(progress),
      items: [
        for (final item in items.cast<Map>())
          RapidItem.fromMap({
            ...item,
            for (final key in ['image', 'music'])
              if (item[key] == '') key: null,
          }),
      ],
    ).toMap();
  }
  if (!partial && effective == QuestionType.rapidFire && rapid == null) {
    throw const ToolError('A rapidFire question needs "rapidFire" with its items.');
  }

  final pairs = take<List<dynamic>>('pairs');
  if (pairs != null) {
    if (effective != QuestionType.matching) throw const ToolError('"pairs" is for matching questions.');
    String? side(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
    final parsed = [
      for (final pair in pairs)
        if (pair is Map)
          MatchPair(
            left: MatchSide(text: side(pair['left']) ?? '', image: side(pair['leftImage'])),
            right: MatchSide(text: side(pair['right']) ?? '', image: side(pair['rightImage'])),
          ),
    ];
    if (parsed.length != pairs.length || parsed.length < 2 || parsed.any((p) => p.left.isEmpty || p.right.isEmpty)) {
      throw const ToolError('"pairs" needs at least two pairs, each side with a text or a picture.');
    }
    data['matching'] = Matching(pairs: parsed).toMap();
  }
  if (!partial && effective == QuestionType.matching && pairs == null) {
    throw const ToolError('A matching question needs "pairs".');
  }

  final top = take<Map<dynamic, dynamic>>('topAnswers');
  if (top != null) {
    if (effective != QuestionType.topAnswers) throw const ToolError('"topAnswers" is for topAnswers questions.');
    final mode = top['mode'] ?? TopAnswersMode.buzzer.name;
    if (!TopAnswersMode.values.any((m) => m.name == mode)) throw const ToolError('"mode" must be buzzer, typed or whiteboard.');
    final items = top['items'];
    if (items is! List || items.isEmpty || items.any((i) => i is! Map || i['answer'] is! String || (i['answer'] as String).trim().isEmpty)) {
      throw const ToolError('"topAnswers" needs "items", each with its "answer".');
    }
    if (items.length > 20) throw const ToolError('A top answers list has at most 20 answers.');
    data['topAnswers'] = TopAnswers(mode: TopAnswersMode.fromName(mode), items: [for (final item in items) TopAnswer.fromMap(item)]).toMap();
  }
  if (!partial && effective == QuestionType.topAnswers && top == null) {
    throw const ToolError('A topAnswers question needs "topAnswers" with its items.');
  }

  final groups = args['groups'];
  if (groups != null) {
    if (effective != QuestionType.connections) throw const ToolError('"groups" is for connections questions.');
    final parsed = ConnectionGroup.listFrom(groups);
    if (groups is! List || groups.length != kConnectionsGroups || parsed.any((g) => !g.isComplete)) {
      throw const ToolError('A connections question needs exactly four groups, each with a name and four words.');
    }
    final words = [for (final g in parsed) ...g.words.map((w) => w.trim().toLowerCase())];
    if (words.toSet().length != words.length) throw const ToolError('A word appears twice in the puzzle.');
    data['connections'] = [for (final g in parsed) g.toMap()];
  }
  if (!partial && effective == QuestionType.connections && groups == null) {
    throw const ToolError('A connections question needs "groups": four groups of four words.');
  }

  final companion = args['companion'];
  if (companion != null && effective == QuestionType.connections) {
    if (companion is! Map) throw const ToolError('"companion" must be an object.');
    // The puzzle is always played on the devices; only how is set here.
    data['companion'] = CompanionSpec.fromMap({...companion, 'kind': CompanionKind.connections.name})!.toMap();
  } else if (companion != null && effective == QuestionType.matching) {
    if (companion is! Map) throw const ToolError('"companion" must be an object.');
    // The pairs come from "pairs"; the screen keeps only its timer and lock.
    final spec = CompanionSpec.fromMap({...companion, 'kind': CompanionKind.match.name})!;
    data['companion'] = {'kind': CompanionKind.match.name, if (spec.timerSeconds != null) 'timer': spec.timerSeconds, if (!spec.lockable) 'lock': false};
  } else if (companion != null && effective == QuestionType.topAnswers) {
    if (companion is! Map) throw const ToolError('"companion" must be an object.');
    // The screen follows from the mode; only its timer and lock are kept.
    final spec = CompanionSpec.fromMap({...companion, 'kind': CompanionKind.text.name})!;
    data['companion'] = {if (spec.timerSeconds != null) 'timer': spec.timerSeconds, if (!spec.lockable) 'lock': false};
  } else if (companion != null && effective == QuestionType.rapidFire) {
    throw const ToolError('A rapidFire question has no "companion"; devices mode gives every team right and wrong.');
  } else if (companion != null) {
    if (companion is! Map) throw const ToolError('"companion" must be an object.');
    final spec = CompanionSpec.fromMap(companion);
    if (spec == null || spec.kind == CompanionKind.connections) {
      throw const ToolError('"companion" needs a known "kind"; for word groups use the connections question type instead.');
    }
    if ((spec.kind == CompanionKind.order || spec.kind == CompanionKind.match) && spec.options.length < 2) {
      throw const ToolError('This companion screen needs at least two "options".');
    }
    if (spec.kind == CompanionKind.match && spec.targets.length != spec.options.length) {
      throw const ToolError('"targets" needs one entry per entry of "options".');
    }
    data['companion'] = spec.toMap();
    // Teams answer on their devices; a buzzer would only get in the way.
    if (effective == QuestionType.free && noBuzzer == null) data['noBuzzer'] = true;
  }

  if (!partial) {
    data.putIfAbsent('type', () => QuestionType.free.name);
    data.putIfAbsent('pointsPlus', () => 0);
    data.putIfAbsent('pointsMinus', () => 0);
    data.putIfAbsent('answerHint', () => '');
    data.putIfAbsent('description', () => '');
    data.putIfAbsent('image', () => null);
    data.putIfAbsent('music', () => null);
  }
  return data;
}

Map<String, dynamic> _describeQuestion(Question q) => {
      'id': q.id,
      'type': q.type.name,
      'question': q.text,
      if (q.answerHint != null) 'answerHint': q.answerHint,
      if (q.description != null) 'label': q.description,
      'pointsPlus': q.pointsPlus,
      'pointsMinus': q.pointsMinus,
      if (q.position != null) 'position': q.position,
      if (q.noBuzzer) 'noBuzzer': true,
      if (q.type == QuestionType.abcd) ...{'answers': q.answers, 'correct': q.answersCorrect},
      if (q.type == QuestionType.progressingReveal || q.type == QuestionType.feud) 'information': q.information,
      if (q.type == QuestionType.progressingReveal && q.hasInformationImages) 'informationImages': q.informationImages,
      if (q.type == QuestionType.progressingReveal && q.informationMusic.any((e) => e.isNotEmpty))
        'informationMusic': q.informationMusic,
      if (q.type == QuestionType.progressingReveal && !q.pictureStrip) 'pictureStrip': false,
      if (q.type == QuestionType.feud) 'values': q.percentages,
      if (q.type == QuestionType.feud && q.absoluteValues) 'absoluteValues': true,
      if (q.type == QuestionType.connections) 'groups': [for (final g in q.connectionGroups) g.toMap()],
      if (q.type == QuestionType.rapidFire && q.rapidFire != null) 'rapidFire': q.rapidFire!.toMap(),
      if (q.type == QuestionType.matching && q.matching != null)
        'pairs': [
          for (final pair in q.matching!.pairs)
            {
              'left': pair.left.text,
              'right': pair.right.text,
              if (pair.left.image != null) 'leftImage': pair.left.image,
              if (pair.right.image != null) 'rightImage': pair.right.image,
            },
        ],
      if (q.type == QuestionType.topAnswers && q.topAnswers != null) 'topAnswers': q.topAnswers!.toMap(),
      if (q.companion != null && q.type != QuestionType.rapidFire)
        'companion': switch (q.type) {
          QuestionType.connections => q.companion!.toMap()..remove('groups'),
          QuestionType.matching => q.companion!.toMap()..remove('options')..remove('targets'),
          QuestionType.topAnswers => {
              if (q.companion!.timerSeconds != null) 'timer': q.companion!.timerSeconds,
              if (!q.companion!.lockable) 'lock': false,
            },
          _ => q.companion!.toMap(),
        },
      if (q.image != null) 'image': q.image,
      if (q.music != null) 'music': q.music,
      ..._describeSounds(q.sounds),
    };

Map<String, dynamic> _describeSounds(MusicConfig sounds) => {
      if (sounds.slots.isNotEmpty) 'music': sounds.slots,
      if (sounds.effects.isNotEmpty) 'effects': sounds.effects,
    };

List<Map<String, dynamic>> _describeCards(List<CueCard> cards) => [
      for (final card in cards)
        {
          if (card.title.isNotEmpty) 'title': card.title,
          if (card.text.isNotEmpty) 'text': card.text,
          if (card.image != null) 'image': card.image,
          if (card.video != null) 'video': card.video,
          if (card.hidden) 'hidden': true,
          if (card.style != CardStyle.standard) 'style': card.style.name,
        },
    ];

String _hex(int argb) => '#${(argb & 0xffffff).toRadixString(16).padLeft(6, '0')}';

Map<String, dynamic> describeGame(GameContent game) => {
      'id': game.id,
      'name': game.name,
      'groups': [
        for (final group in game.groups)
          {
            'id': group.isUngrouped ? null : group.id,
            'name': group.isUngrouped ? '(no group)' : group.name,
            'board': group.type.name,
            if (group.text != null) 'text': group.text,
            if (group.color != null) 'color': _hex(group.color!),
            if (group.accentColor != null) 'accentColor': _hex(group.accentColor!),
            if (group.splitPointFields) 'splitPointFields': true,
            if (group.cards.isNotEmpty) 'cards': _describeCards(group.cards),
            ..._describeSounds(group.sounds),
            'categories': [
              for (final category in group.categories)
                {
                  'id': category.id,
                  'name': category.name,
                  'active': category.active,
                  if (category.cards.isNotEmpty) 'cards': _describeCards(category.cards),
                  ..._describeSounds(category.sounds),
                  'questions': [for (final question in category.questions) _describeQuestion(question)],
                },
            ],
          },
      ],
    };

/// Runs tools against a backend and keeps a short record of what was done,
/// for the user to see.
class GameTools {
  GameTools(this.backend, {this.onActivity});

  final GameToolsBackend backend;

  /// Called with a line describing each change, e.g. "Added question …".
  final void Function(String line)? onActivity;

  String _arg(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is! String || value.isEmpty) throw ToolError('"$key" is required.');
    return value;
  }

  Future<Category> _category(String gameId, String categoryId) async {
    final category = (await backend.loadGame(gameId)).category(categoryId);
    if (category == null) throw ToolError('No category "$categoryId" in this game. Use get_game to see the ids.');
    return category;
  }

  Future<CategoryGroup> _group(String gameId, String groupId) async {
    final group = (await backend.loadGame(gameId)).group(groupId);
    if (group == null || group.isUngrouped) throw ToolError('No group "$groupId" in this game. Use get_game to see the ids.');
    return group;
  }

  /// The question, category or group that cards or sounds go on, from
  /// whichever ids [args] give.
  Future<_Target> _soundsOrCardsTarget(String gameId, Map<String, dynamic> args, {required bool allowQuestion}) async {
    final groupId = args['groupId'] is String && (args['groupId'] as String).isNotEmpty ? args['groupId'] as String : null;
    final categoryId = args['categoryId'] is String && (args['categoryId'] as String).isNotEmpty ? args['categoryId'] as String : null;
    final questionId = args['questionId'] is String && (args['questionId'] as String).isNotEmpty ? args['questionId'] as String : null;
    if (questionId != null && !allowQuestion) throw const ToolError('Cards belong to a category or a group, not a question.');
    if ((groupId == null) == (categoryId == null)) throw const ToolError('Give either "groupId" or "categoryId".');
    if (groupId != null) {
      final group = await _group(gameId, groupId);
      return _Target('group "${group.name}"', group.data, (data) => backend.updateGroup(gameId, group.id, data));
    }
    final category = await _category(gameId, categoryId!);
    if (questionId == null) {
      return _Target('category "${category.name}"', category.data, (data) => backend.updateCategory(gameId, category.id, data));
    }
    final question = category.questions.where((q) => q.id == questionId).firstOrNull;
    if (question == null) throw ToolError('No question "$questionId" in this category.');
    return _Target('question "${question.text}"', question.data, (data) => backend.updateQuestion(gameId, category.id, question.id, data));
  }

  /// Carries out [name] with [args] and returns its JSON result. Throws
  /// [ToolError] for anything the assistant got wrong.
  Future<Object?> call(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'list_games':
        return [
          for (final game in await backend.listGames()) {'id': game.id, 'name': game.name},
        ];

      case 'get_game':
        return describeGame(await backend.loadGame(_arg(args, 'gameId')));

      case 'create_game':
        final title = _arg(args, 'name');
        final id = await backend.createGame(title);
        onActivity?.call('Created game "$title"');
        return {'gameId': id};

      case 'add_category_group':
        final gameId = _arg(args, 'gameId');
        final title = _arg(args, 'name');
        final board = BoardType.values.where((b) => b.name == (args['board'] ?? 'wheel')).firstOrNull;
        if (board == null) throw const ToolError('"board" must be wheel, map or display.');
        final game = await backend.loadGame(gameId);
        final id = await backend.addGroup(gameId, title, board, game.groups.where((g) => !g.isUngrouped).length);
        onActivity?.call('Added group "$title"');
        return {'groupId': id};

      case 'add_category':
        final gameId = _arg(args, 'gameId');
        final title = _arg(args, 'name');
        final groupId = args['groupId'] as String?;
        final game = await backend.loadGame(gameId);
        final group = game.group(groupId ?? CategoryGroup.ungroupedId);
        if (groupId != null && group == null) throw ToolError('No group "$groupId" in this game.');
        final id = await backend.addCategory(gameId, title, groupId: groupId, index: group?.categories.length ?? 0);
        onActivity?.call('Added category "$title"');
        return {'categoryId': id};

      case 'update_category':
        final gameId = _arg(args, 'gameId');
        final category = await _category(gameId, _arg(args, 'categoryId'));
        final data = <String, dynamic>{
          if (args['name'] is String) 'name': args['name'],
          if (args['active'] is bool) 'active': args['active'],
        };
        if (data.isEmpty) throw const ToolError('Nothing to change: give "name" or "active".');
        await backend.updateCategory(gameId, category.id, data);
        onActivity?.call('Changed category "${data['name'] ?? category.name}"');
        return {'ok': true};

      case 'delete_category':
        final gameId = _arg(args, 'gameId');
        final category = await _category(gameId, _arg(args, 'categoryId'));
        await backend.deleteCategory(gameId, category);
        onActivity?.call('Deleted category "${category.name}" with ${category.questions.length} questions');
        return {'ok': true};

      case 'add_question':
        final gameId = _arg(args, 'gameId');
        final category = await _category(gameId, _arg(args, 'categoryId'));
        final data = questionDataFromArgs(args, partial: false);
        // A category in its own order keeps it: the new question goes last.
        final last = category.questions.lastOrNull?.position;
        if (last != null) data['questionIndex'] = last + 1;
        final id = await backend.addQuestion(gameId, category.id, data);
        onActivity?.call('Added to "${category.name}": ${data['question']} (${data['pointsPlus']})');
        return {'questionId': id};

      case 'update_question':
        final gameId = _arg(args, 'gameId');
        final category = await _category(gameId, _arg(args, 'categoryId'));
        final questionId = _arg(args, 'questionId');
        final question = category.questions.where((q) => q.id == questionId).firstOrNull;
        if (question == null) throw ToolError('No question "$questionId" in this category.');
        final data = questionDataFromArgs(args, partial: true, existingType: question.type);
        if (data.isEmpty) throw const ToolError('Nothing to change.');
        await backend.updateQuestion(gameId, category.id, questionId, data);
        onActivity?.call('Changed in "${category.name}": ${data['question'] ?? question.text}');
        return {'ok': true};

      case 'delete_question':
        final gameId = _arg(args, 'gameId');
        final category = await _category(gameId, _arg(args, 'categoryId'));
        final questionId = _arg(args, 'questionId');
        final question = category.questions.where((q) => q.id == questionId).firstOrNull;
        if (question == null) throw ToolError('No question "$questionId" in this category.');
        await backend.deleteQuestion(gameId, category.id, questionId);
        onActivity?.call('Deleted from "${category.name}": ${question.text}');
        return {'ok': true};

      case 'reorder_questions':
        final gameId = _arg(args, 'gameId');
        final category = await _category(gameId, _arg(args, 'categoryId'));
        final ids = args['questionIds'];
        final present = {for (final q in category.questions) q.id};
        if (ids is! List || ids.length != present.length || !ids.every(present.contains) || ids.toSet().length != ids.length) {
          throw const ToolError('"questionIds" must list every question of the category exactly once.');
        }
        for (final (index, id) in ids.cast<String>().indexed) {
          await backend.updateQuestion(gameId, category.id, id, {'questionIndex': index});
        }
        onActivity?.call('Reordered the questions of "${category.name}"');
        return {'ok': true};

      case 'update_category_group':
        final gameId = _arg(args, 'gameId');
        final group = await _group(gameId, _arg(args, 'groupId'));
        int? color(String key) {
          final value = args[key] as String;
          if (value.isEmpty) return null;
          final hex = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(value)?.group(1);
          if (hex == null) throw ToolError('"$key" must look like #1A2B3C.');
          return 0xff000000 | int.parse(hex, radix: 16);
        }

        final board = args['board'] == null ? null : BoardType.values.where((b) => b.name == args['board']).firstOrNull;
        if (args['board'] != null && board == null) throw const ToolError('"board" must be wheel, map or display.');
        final data = <String, dynamic>{
          if (args['name'] is String) 'name': args['name'],
          'categoryGroupType': ?board?.databaseString,
          if (args['text'] is String) 'text': (args['text'] as String).isEmpty ? null : args['text'],
          if (args['color'] is String) 'color': color('color'),
          if (args['accentColor'] is String) 'accentColor': color('accentColor'),
          if (args['splitPointFields'] is bool) 'splitPointFields': args['splitPointFields'],
        };
        if (data.isEmpty) throw const ToolError('Nothing to change.');
        await backend.updateGroup(gameId, group.id, data);
        onActivity?.call('Changed group "${data['name'] ?? group.name}"');
        return {'ok': true};

      case 'delete_category_group':
        final gameId = _arg(args, 'gameId');
        final group = await _group(gameId, _arg(args, 'groupId'));
        if (group.categories.isNotEmpty) {
          throw ToolError('Group "${group.name}" still has ${group.categories.length} categories; delete them first.');
        }
        await backend.deleteGroup(gameId, group.id);
        onActivity?.call('Deleted group "${group.name}"');
        return {'ok': true};

      case 'set_cards':
        final gameId = _arg(args, 'gameId');
        final cards = args['cards'];
        if (cards is! List || cards.any((c) => c is! Map)) throw const ToolError('"cards" must be a list of cards.');
        for (final card in cards.cast<Map>()) {
          final style = card['style'];
          if (style != null && !CardStyle.values.any((s) => s.name == style)) throw ToolError('Unknown card style "$style".');
        }
        final stored = [
          for (final card in cards.cast<Map>())
            CueCard(
              title: card['title'] is String ? card['title'] as String : '',
              text: card['text'] is String ? card['text'] as String : '',
              image: card['image'] is String && (card['image'] as String).isNotEmpty ? card['image'] as String : null,
              video: card['video'] is String && (card['video'] as String).isNotEmpty ? card['video'] as String : null,
              hidden: card['hidden'] == true,
              style: CardStyle.fromName(card['style']),
            ).toMap(),
        ];
        if (stored.any((c) => (c['title'] as String).isEmpty && (c['text'] as String).isEmpty && c['image'] == null && c['video'] == null)) {
          throw const ToolError('Every card needs a title, a text, an image or a video.');
        }
        for (final card in stored) {
          final image = card['image'] as String?;
          if (isBuiltinImage(image) && builtinImage(image) == null) throw ToolError('No built-in picture "$image".');
        }
        final target = await _soundsOrCardsTarget(gameId, args, allowQuestion: false);
        await target.save({'cards': stored});
        onActivity?.call('Set ${stored.length} cards of ${target.label}');
        return {'ok': true};

      case 'set_sounds':
        final gameId = _arg(args, 'gameId');
        final target = await _soundsOrCardsTarget(gameId, args, allowQuestion: true);
        final music = args['music'] ?? const {};
        final effects = args['effects'] ?? const {};
        if (music is! Map || effects is! Map) throw const ToolError('"music" and "effects" must be objects.');
        if ((music.isEmpty && effects.isEmpty)) throw const ToolError('Nothing to change.');
        String? value(Object? v, String key) {
          if (v is! String) throw ToolError('"$key" must be a string.');
          if (v.isEmpty) return null;
          final known = musicSlots.contains(key) ? builtinMusicTrack(v) != null : builtinSound(v) != null;
          if (v.startsWith(builtinSoundPrefix) && !known) throw ToolError('No built-in sound "$v" for "$key".');
          return v;
        }

        final data = <String, dynamic>{};
        for (final entry in music.entries) {
          if (!musicSlots.contains(entry.key)) throw ToolError('Unknown music slot "${entry.key}".');
          data[entry.key as String] = value(entry.value, entry.key as String);
        }
        if (effects.isNotEmpty) {
          final merged = Map<String, dynamic>.from(target.data['musicEffects'] is Map ? target.data['musicEffects'] as Map : const {});
          for (final entry in effects.entries) {
            if (!builtInEffects.contains(entry.key)) throw ToolError('Unknown moment "${entry.key}".');
            final picked = value(entry.value, entry.key as String);
            if (picked == null) {
              merged.remove(entry.key);
            } else {
              merged[entry.key as String] = picked;
            }
          }
          data['musicEffects'] = merged;
        }
        await target.save(data);
        onActivity?.call('Changed the sounds of ${target.label}');
        return {'ok': true};

      case 'upload_media':
        final gameId = _arg(args, 'gameId');
        final path = _arg(args, 'path');
        await backend.loadGame(gameId);
        final name = await backend.uploadMedia(gameId, path);
        onActivity?.call('Uploaded ${path.split(RegExp(r'[/\\]')).last}');
        return {'name': name};

      case 'list_builtin_media':
        return {
          'pictures': {for (final image in builtinImages) image.name: image.label},
          'music': {for (final track in builtinMusicTracks) track.key: track.label},
          'sounds': {
            for (final moment in builtInEffects)
              moment: {for (final sound in builtinSoundsFor(moment)) sound.key: sound.label},
          },
        };
    }
    throw ToolError('Unknown tool "$name".');
  }
}

/// Where cards or sounds are stored: its current fields and how to save.
class _Target {
  const _Target(this.label, this.data, this.save);

  final String label;
  final Map<String, dynamic> data;
  final Future<void> Function(Map<String, dynamic> data) save;
}
