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
  Future<String> addCategory(String gameId, String name, {String? groupId, required int index});
  Future<void> updateCategory(String gameId, String categoryId, Map<String, dynamic> data);
  Future<void> deleteCategory(String gameId, Category category);
  Future<String> addQuestion(String gameId, String categoryId, Map<String, dynamic> data);
  Future<void> updateQuestion(String gameId, String categoryId, String questionId, Map<String, dynamic> data);
  Future<void> deleteQuestion(String gameId, String categoryId, String questionId);
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
    'enum': ['free', 'abcd', 'progressingReveal', 'feud', 'connections'],
    'description': 'free: plain question. abcd: four answer options. progressingReveal: hints revealed one by one. '
        'feud: a survey, the most popular answers, each worth a share of the points. '
        'connections: sixteen words in four groups of four, solved by every team on its own '
        'device; each group found is worth a quarter of pointsPlus.',
  },
  'question': {'type': 'string', 'description': 'The question as shown to the audience.'},
  'answerHint': {'type': 'string', 'description': 'The answer or notes; only the gamemaster sees this.'},
  'label': {'type': 'string', 'description': 'Optional short badge shown on the question card, e.g. a sub-topic.'},
  'pointsPlus': {'type': 'integer', 'minimum': 0, 'description': 'Points for a right answer. Questions sort by this.'},
  'pointsMinus': {'type': 'integer', 'minimum': 0, 'description': 'Points taken for a wrong answer; usually 0 or half.'},
  'noBuzzer': {'type': 'boolean', 'description': 'free only: no buzzing, e.g. for estimation questions.'},
  'answers': {
    'type': 'array',
    'items': _string,
    'minItems': 4,
    'maxItems': 4,
    'description': 'abcd only: exactly four options, A to D.',
  },
  'correct': {
    'type': 'array',
    'items': {'type': 'boolean'},
    'minItems': 4,
    'maxItems': 4,
    'description': 'abcd only: which of the four options are right, aligned with answers.',
  },
  'information': {
    'type': 'array',
    'items': _string,
    'description': 'progressingReveal: the hints in the order they are revealed. feud: the answers on the board.',
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
    'description': 'Optional screen on the teams\' own devices while the question is open.',
    'properties': {
      'kind': {
        'type': 'string',
        'enum': ['whiteboard', 'text', 'number', 'slider', 'choice', 'order', 'match'],
      },
      'timer': {'type': 'integer', 'description': 'Seconds until answers lock; leave out for no timer.'},
      'background': {
        'type': 'string',
        'enum': ['blank', 'lines', 'grid', 'list'],
        'description': 'whiteboard only.',
      },
      'listRows': {'type': 'integer', 'description': 'whiteboard with list background.'},
      'min': {'type': 'number'},
      'max': {'type': 'number'},
      'step': {'type': 'number'},
      'unit': {'type': 'string'},
      'solution': {'type': 'number', 'description': 'number and slider: the right value.'},
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
    'Adds a question to a category. Give at least the question text and pointsPlus. A typical category has '
        'five questions rising in value, e.g. 100 to 500. Pictures and sounds cannot be attached here; the user '
        'adds those in the app.',
    _object({'gameId': _string, 'categoryId': _string, ..._questionFields}, ['gameId', 'categoryId', 'question']),
  ),
  ToolSpec(
    'update_question',
    'Changes fields of an existing question. Only the fields given are changed.',
    _object({'gameId': _string, 'categoryId': _string, 'questionId': _string, ..._questionFields},
        ['gameId', 'categoryId', 'questionId']),
  ),
  ToolSpec(
    'delete_question',
    'Deletes one question. Cannot be undone; only do this when the user asked for it.',
    _object({'gameId': _string, 'categoryId': _string, 'questionId': _string}, ['gameId', 'categoryId', 'questionId']),
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
    if (answers != null && answers.length != 4) throw const ToolError('An abcd question needs exactly four answers.');
    if (correct != null && correct.length != 4) throw const ToolError('"correct" needs exactly four entries.');
    if (answers != null) data['answers'] = answers;
    if (correct != null) data['answersCorrect'] = correct;
  }
  if (!partial && effective == QuestionType.abcd && (answers == null || correct == null)) {
    throw const ToolError('An abcd question needs "answers" and "correct", four entries each.');
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
        // The three lists are stored index-aligned; no media from here.
        data['informationImage'] = List.filled(information.length, '');
        data['informationMusic'] = List.filled(information.length, '');
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
      if (q.noBuzzer) 'noBuzzer': true,
      if (q.type == QuestionType.abcd) ...{'answers': q.answers, 'correct': q.answersCorrect},
      if (q.type == QuestionType.progressingReveal || q.type == QuestionType.feud) 'information': q.information,
      if (q.type == QuestionType.feud) 'values': q.percentages,
      if (q.type == QuestionType.connections) 'groups': [for (final g in q.connectionGroups) g.toMap()],
      if (q.companion != null)
        'companion': q.type == QuestionType.connections
            ? (q.companion!.toMap()..remove('groups'))
            : q.companion!.toMap(),
      if (q.image != null) 'hasImage': true,
      if (q.music != null) 'hasSound': true,
    };

Map<String, dynamic> describeGame(GameContent game) => {
      'id': game.id,
      'name': game.name,
      'groups': [
        for (final group in game.groups)
          {
            'id': group.isUngrouped ? null : group.id,
            'name': group.isUngrouped ? '(no group)' : group.name,
            'board': group.type.name,
            'categories': [
              for (final category in group.categories)
                {
                  'id': category.id,
                  'name': category.name,
                  'active': category.active,
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
    }
    throw ToolError('Unknown tool "$name".');
  }
}
