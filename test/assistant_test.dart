import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/assistant/assistant.dart';
import 'package:quiz_show/features/assistant/game_tools.dart';
import 'package:quiz_show/features/assistant/mcp_server.dart';
import 'package:quiz_show/game/game.dart';

/// Games kept as the raw maps the database would hold.
class FakeBackend implements GameToolsBackend {
  final Map<String, Map<String, dynamic>> games = {
    'g': {'name': 'Pub quiz'},
  };
  final Map<String, Map<String, Map<String, dynamic>>> groups = {
    'g': {
      'r1': {'name': 'Round 1', 'categoryGroupType': 'category_wheel', 'categoryGroupIndex': 0},
    },
  };
  final Map<String, Map<String, Map<String, dynamic>>> categories = {
    'g': {
      'c1': {'name': 'Capitals', 'categoryGroup': 'r1', 'categoryIndex': 0, 'active': true},
    },
  };
  final Map<String, Map<String, Map<String, dynamic>>> questions = {
    'c1': {
      'q1': {'type': 'free', 'question': 'Capital of France?', 'answerHint': 'Paris', 'pointsPlus': 100, 'pointsMinus': 50},
    },
  };
  int _next = 0;

  String _id(String prefix) => '$prefix${++_next}';

  @override
  Future<List<({String id, String name})>> listGames() async =>
      [for (final entry in games.entries) (id: entry.key, name: entry.value['name'] as String)];

  @override
  Future<GameContent> loadGame(String gameId) async {
    if (!games.containsKey(gameId)) throw ToolError('Could not load game "$gameId".');
    final own = categories[gameId] ?? {};
    return GameContent.assemble(
      id: gameId,
      game: games[gameId]!,
      groups: groups[gameId] ?? {},
      categories: own,
      questions: {for (final id in own.keys) id: questions[id] ?? {}},
      activeOnly: false,
    );
  }

  @override
  Future<String> createGame(String name) async {
    final id = _id('game');
    games[id] = {'name': name};
    return id;
  }

  @override
  Future<String> addGroup(String gameId, String name, BoardType type, int index) async {
    final id = _id('group');
    (groups[gameId] ??= {})[id] = {'name': name, 'categoryGroupType': type.databaseString, 'categoryGroupIndex': index};
    return id;
  }

  @override
  Future<String> addCategory(String gameId, String name, {String? groupId, required int index}) async {
    final id = _id('cat');
    (categories[gameId] ??= {})[id] = {'name': name, 'categoryGroup': groupId, 'categoryIndex': index, 'active': true};
    return id;
  }

  @override
  Future<void> updateCategory(String gameId, String categoryId, Map<String, dynamic> data) async =>
      categories[gameId]![categoryId]!.addAll(data);

  @override
  Future<void> deleteCategory(String gameId, Category category) async {
    categories[gameId]!.remove(category.id);
    questions.remove(category.id);
  }

  @override
  Future<String> addQuestion(String gameId, String categoryId, Map<String, dynamic> data) async {
    final id = _id('question');
    (questions[categoryId] ??= {})[id] = Map.of(data);
    return id;
  }

  @override
  Future<void> updateQuestion(String gameId, String categoryId, String questionId, Map<String, dynamic> data) async =>
      questions[categoryId]![questionId]!.addAll(data);

  @override
  Future<void> deleteQuestion(String gameId, String categoryId, String questionId) async =>
      questions[categoryId]!.remove(questionId);

  @override
  Future<void> updateGroup(String gameId, String groupId, Map<String, dynamic> data) async =>
      groups[gameId]![groupId]!.addAll(data);

  @override
  Future<void> deleteGroup(String gameId, String groupId) async => groups[gameId]!.remove(groupId);

  final List<String> uploads = [];

  @override
  Future<String> uploadMedia(String gameId, String path) async {
    uploads.add(path);
    return 'media${uploads.length}.png';
  }
}

void main() {
  group('question arguments', () {
    test('a plain question gets its defaults', () {
      final data = questionDataFromArgs({'question': 'Capital of Peru?', 'answerHint': 'Lima', 'pointsPlus': 200}, partial: false);
      expect(data, {
        'type': 'free',
        'question': 'Capital of Peru?',
        'answerHint': 'Lima',
        'pointsPlus': 200,
        'pointsMinus': 0,
        'description': '',
        'image': null,
        'music': null,
      });
    });

    test('an update carries only what was given', () {
      expect(questionDataFromArgs({'pointsPlus': 300, 'label': 'Hard'}, partial: true), {'pointsPlus': 300, 'description': 'Hard'});
    });

    test('abcd needs four answers and four marks', () {
      final data = questionDataFromArgs({
        'type': 'abcd',
        'question': 'Pick',
        'answers': ['a', 'b', 'c', 'd'],
        'correct': [false, true, false, false],
      }, partial: false);
      expect(data['answers'], ['a', 'b', 'c', 'd']);
      expect(data['answersCorrect'], [false, true, false, false]);
      expect(
        () => questionDataFromArgs({'type': 'abcd', 'question': 'Pick', 'answers': ['a', 'b'], 'correct': [true, false]}, partial: false),
        throwsA(isA<ToolError>()),
      );
      expect(() => questionDataFromArgs({'type': 'abcd', 'question': 'Pick'}, partial: false), throwsA(isA<ToolError>()));
    });

    test('progressing reveal keeps its three lists aligned', () {
      final data = questionDataFromArgs({'type': 'progressingReveal', 'question': 'Who?', 'information': ['one', 'two']}, partial: false);
      expect(data['informationImage'], ['', '']);
      expect(data['informationMusic'], ['', '']);
    });

    test('feud needs a value per answer', () {
      final data = questionDataFromArgs({
        'type': 'feud',
        'question': 'Name a fruit',
        'information': ['Apple', 'Pear'],
        'values': [70, 30],
      }, partial: false);
      expect(data['informationPercentage'], [70.0, 30.0]);
      expect(
        () => questionDataFromArgs({'type': 'feud', 'question': 'x', 'information': ['a', 'b'], 'values': [100]}, partial: false),
        throwsA(isA<ToolError>()),
      );
    });

    test('fields of another type are refused', () {
      expect(() => questionDataFromArgs({'question': 'x', 'answers': ['a', 'b', 'c', 'd']}, partial: false), throwsA(isA<ToolError>()));
      expect(
        () => questionDataFromArgs({'information': ['a']}, partial: true, existingType: QuestionType.abcd),
        throwsA(isA<ToolError>()),
      );
      expect(() => questionDataFromArgs({'type': 'riddle', 'question': 'x'}, partial: false), throwsA(isA<ToolError>()));
      expect(() => questionDataFromArgs({'question': 'x', 'pointsPlus': 'many'}, partial: false), throwsA(isA<ToolError>()));
    });

    test('connections takes four groups of four, no word twice', () {
      final groups = [
        {'name': 'Fruit', 'words': ['Apple', 'Pear', 'Plum', 'Fig']},
        {'name': 'Planets', 'words': ['Mars', 'Venus', 'Earth', 'Saturn']},
        {'name': 'Card games', 'words': ['Bridge', 'Poker', 'Snap', 'Rummy']},
        {'name': '___ Pie', 'words': ['Cherry', 'Humble', 'Shepherd', 'Pork']},
      ];
      final data = questionDataFromArgs({
        'type': 'connections',
        'question': 'Find the groups',
        'pointsPlus': 400,
        'groups': groups,
        'companion': {'timer': 120, 'mistakes': 4},
      }, partial: false);
      final q = Question.fromMap('q', data);
      expect(q.connectionGroups.map((g) => g.name), ['Fruit', 'Planets', 'Card games', '___ Pie']);
      expect((q.companion!.timerSeconds, q.companion!.mistakes), (120, 4));
      expect(() => questionDataFromArgs({'type': 'connections', 'question': 'x'}, partial: false), throwsA(isA<ToolError>()));
      expect(
        () => questionDataFromArgs({'type': 'connections', 'question': 'x', 'groups': groups.take(3).toList()}, partial: false),
        throwsA(isA<ToolError>()),
      );
      final twice = [
        ...groups.take(3),
        {'name': 'Again', 'words': ['Apple', 'A', 'B', 'C']},
      ];
      expect(() => questionDataFromArgs({'type': 'connections', 'question': 'x', 'groups': twice}, partial: false), throwsA(isA<ToolError>()));
      expect(() => questionDataFromArgs({'question': 'x', 'groups': groups}, partial: false), throwsA(isA<ToolError>()));
    });

    test('a companion screen switches the buzzers off', () {
      final data = questionDataFromArgs({
        'question': 'What is 3+5?',
        'companion': {'kind': 'number', 'solution': 8, 'timer': 30},
      }, partial: false);
      expect(data['noBuzzer'], true);
      final spec = CompanionSpec.fromMap(data['companion'] as Map)!;
      expect(spec.kind, CompanionKind.number);
      expect(spec.solution, 8);
      expect(
        () => questionDataFromArgs({'question': 'x', 'companion': {'kind': 'order', 'options': ['only']}}, partial: false),
        throwsA(isA<ToolError>()),
      );
    });

    test('what a stored question is described as can be sent back', () async {
      final backend = FakeBackend();
      final tools = GameTools(backend);
      final id = (await tools.call('add_question', {
        'gameId': 'g',
        'categoryId': 'c1',
        'type': 'feud',
        'question': 'Name a fruit',
        'information': ['Apple', 'Pear'],
        'values': [70, 30],
        'pointsPlus': 400,
      }) as Map)['questionId'];
      final game = await tools.call('get_game', {'gameId': 'g'}) as Map;
      final described = ((game['groups'] as List).first['categories'] as List).first['questions'] as List;
      final feud = Map<String, dynamic>.from(described.firstWhere((q) => q['id'] == id) as Map)..remove('id');
      expect(questionDataFromArgs(feud, partial: true)['informationPercentage'], [70.0, 30.0]);
    });
  });

  group('tools', () {
    late FakeBackend backend;
    late List<String> activity;
    late GameTools tools;

    setUp(() {
      backend = FakeBackend();
      activity = [];
      tools = GameTools(backend, onActivity: activity.add);
    });

    test('building a round from nothing', () async {
      final gameId = (await tools.call('create_game', {'name': 'Birthday'}) as Map)['gameId'] as String;
      final groupId = (await tools.call('add_category_group', {'gameId': gameId, 'name': 'Round 1', 'board': 'map'}) as Map)['groupId'];
      final first = (await tools.call('add_category', {'gameId': gameId, 'name': 'Films', 'groupId': groupId}) as Map)['categoryId'];
      await tools.call('add_category', {'gameId': gameId, 'name': 'Music', 'groupId': groupId});
      for (final points in [100, 200, 300]) {
        await tools.call('add_question', {'gameId': gameId, 'categoryId': first, 'question': 'Film $points', 'pointsPlus': points});
      }
      final game = await backend.loadGame(gameId);
      expect(game.groups.single.type, BoardType.map);
      expect([for (final c in game.groups.single.categories) c.name], ['Films', 'Music']);
      expect([for (final q in game.groups.single.categories.first.questions) q.pointsPlus], [100, 200, 300]);
      expect(activity, hasLength(7));
    });

    test('reading does not count as a change', () async {
      expect(await tools.call('list_games', {}), [
        {'id': 'g', 'name': 'Pub quiz'},
      ]);
      final game = await tools.call('get_game', {'gameId': 'g'}) as Map;
      final question = (((game['groups'] as List).single['categories'] as List).single['questions'] as List).single as Map;
      expect(question['question'], 'Capital of France?');
      expect(question['answerHint'], 'Paris');
      expect(activity, isEmpty);
    });

    test('updating and deleting a question', () async {
      await tools.call('update_question', {'gameId': 'g', 'categoryId': 'c1', 'questionId': 'q1', 'pointsPlus': 500});
      expect(backend.questions['c1']!['q1']!['pointsPlus'], 500);
      expect(backend.questions['c1']!['q1']!['question'], 'Capital of France?');
      await tools.call('delete_question', {'gameId': 'g', 'categoryId': 'c1', 'questionId': 'q1'});
      expect(backend.questions['c1'], isEmpty);
    });

    test('renaming, switching off and deleting a category', () async {
      await tools.call('update_category', {'gameId': 'g', 'categoryId': 'c1', 'name': 'Cities', 'active': false});
      expect(backend.categories['g']!['c1'], containsPair('name', 'Cities'));
      expect(backend.categories['g']!['c1'], containsPair('active', false));
      await tools.call('delete_category', {'gameId': 'g', 'categoryId': 'c1'});
      expect(backend.categories['g'], isEmpty);
      expect(backend.questions.containsKey('c1'), false);
    });

    test('wrong ids are explained, and nothing is written', () async {
      for (final call in <(String, Map<String, dynamic>)>[
        ('get_game', {'gameId': 'nope'}),
        ('add_question', {'gameId': 'g', 'categoryId': 'nope', 'question': 'x'}),
        ('update_question', {'gameId': 'g', 'categoryId': 'c1', 'questionId': 'nope', 'pointsPlus': 1}),
        ('add_category', {'gameId': 'g', 'name': 'x', 'groupId': 'nope'}),
        ('add_category', {'gameId': 'g'}),
        ('update_category', {'gameId': 'g', 'categoryId': 'c1'}),
        ('launch_rocket', {}),
      ]) {
        await expectLater(tools.call(call.$1, call.$2), throwsA(isA<ToolError>()), reason: call.$1);
      }
      expect(activity, isEmpty);
      expect(backend.questions['c1'], hasLength(1));
    });

    Future<List<Map>> described() async {
      final game = await tools.call('get_game', {'gameId': 'g'}) as Map;
      return [for (final q in ((game['groups'] as List).single['categories'] as List).single['questions'] as List) q as Map];
    }

    test('a Fragenhagel and a matching question, read back as they were given', () async {
      final rapid = {
        'mode': 'buzzer',
        'progress': 'flux',
        'items': [
          {'question': 'Who is Marty McFly played by?', 'answer': 'Michael J. Fox'},
          {'question': 'HAL is the computer in which film?', 'answer': '2001'},
        ],
      };
      await tools.call('add_question', {'gameId': 'g', 'categoryId': 'c1', 'type': 'rapidFire', 'question': 'Fragenhagel', 'pointsPlus': 20, 'rapidFire': rapid});
      final pairs = [
        {'left': 'Jaws', 'right': '1975'},
        {'left': 'Alien', 'right': '1979'},
      ];
      await tools.call('add_question', {
        'gameId': 'g',
        'categoryId': 'c1',
        'type': 'matching',
        'question': 'When did they come out?',
        'pointsPlus': 300,
        'pairs': pairs,
        'companion': {'timer': 60},
      });
      final game = await backend.loadGame('g');
      final questions = game.groups.single.categories.single.questions;
      expect(questions.first.rapidFire!.items[1].answer, '2001');
      expect(questions.first.rapidFire!.progress, ProgressStyle.flux);
      expect(questions.last.companion!.targets, hasLength(2));
      expect(questions.last.companion!.timerSeconds, 60);

      final read = await described();
      final rapidRead = read.firstWhere((q) => q['type'] == 'rapidFire');
      expect((rapidRead['rapidFire'] as Map)['items'][0]['answer'], 'Michael J. Fox');
      final matchingRead = read.firstWhere((q) => q['type'] == 'matching');
      expect(matchingRead['pairs'], pairs);
      expect(matchingRead['companion'], {'kind': 'match', 'timer': 60});
    });

    test('a Fragenhagel on the devices takes statements', () async {
      await tools.call('add_question', {
        'gameId': 'g',
        'categoryId': 'c1',
        'type': 'rapidFire',
        'question': 'Fact or fiction?',
        'rapidFire': {
          'mode': 'devices',
          'items': [
            {'question': 'Darth Vader breathes in George Lucas\'s voice.', 'true': false},
          ],
        },
      });
      final question = (await backend.loadGame('g')).groups.single.categories.single.questions.first;
      expect(question.rapidFire!.mode, RapidMode.devices);
      expect(question.rapidFire!.items.single.isTrue, false);
      expect(question.buzzerable, false);
    });

    test('a Fragenhagel needs items, a matching question two pairs', () async {
      for (final args in <Map<String, dynamic>>[
        {'type': 'rapidFire', 'question': 'x'},
        {'type': 'rapidFire', 'question': 'x', 'rapidFire': {'items': []}},
        {'type': 'rapidFire', 'question': 'x', 'rapidFire': {'mode': 'shout', 'items': [{'question': 'y'}]}},
        {'type': 'matching', 'question': 'x', 'pairs': [{'left': 'a', 'right': 'b'}]},
        {'type': 'matching', 'question': 'x', 'pairs': [{'left': 'a'}, {'left': 'b', 'right': 'c'}]},
        {'question': 'x', 'pairs': [{'left': 'a', 'right': 'b'}, {'left': 'c', 'right': 'd'}]},
      ]) {
        await expectLater(tools.call('add_question', {'gameId': 'g', 'categoryId': 'c1', ...args}), throwsA(isA<ToolError>()), reason: '$args');
      }
    });

    test('an own order beats the points, and new questions join at the end', () async {
      final id = (await tools.call('add_question', {'gameId': 'g', 'categoryId': 'c1', 'question': 'Hagel', 'pointsPlus': 20}) as Map)['questionId'];
      expect([for (final q in await described()) q['id']], [id, 'q1']);
      await tools.call('reorder_questions', {'gameId': 'g', 'categoryId': 'c1', 'questionIds': ['q1', id]});
      final added = (await tools.call('add_question', {'gameId': 'g', 'categoryId': 'c1', 'question': 'Last', 'pointsPlus': 10}) as Map)['questionId'];
      expect([for (final q in await described()) q['id']], ['q1', id, added]);
      await expectLater(
          tools.call('reorder_questions', {'gameId': 'g', 'categoryId': 'c1', 'questionIds': ['q1', id]}), throwsA(isA<ToolError>()));
    });

    test('pictures go up and onto questions, whiteboards and hints', () async {
      final name = (await tools.call('upload_media', {'gameId': 'g', 'path': r'C:\pics\moon.png'}) as Map)['name'];
      expect(backend.uploads, [r'C:\pics\moon.png']);
      await tools.call('update_question', {
        'gameId': 'g',
        'categoryId': 'c1',
        'questionId': 'q1',
        'type': 'progressingReveal',
        'information': ['', 'Clue'],
        'informationImages': [name],
        'companion': {'kind': 'whiteboard', 'background': 'image', 'backgroundImage': name},
      });
      final question = (await backend.loadGame('g')).groups.single.categories.single.questions.single;
      expect(question.informationImages, [name, '']);
      expect(question.companion!.backgroundImage, name);
    });

    test('cards and sounds of a category', () async {
      await tools.call('set_cards', {
        'gameId': 'g',
        'categoryId': 'c1',
        'cards': [
          {'text': 'Thanks for having me!', 'style': 'silentFilm'},
          {'image': 'builtin:applause'},
        ],
      });
      final category = (await backend.loadGame('g')).groups.single.categories.single;
      expect([for (final card in category.cards) card.text], ['Thanks for having me!', '']);
      expect([for (final card in category.cards) card.style], [CardStyle.silentFilm, CardStyle.standard]);
      await expectLater(
          tools.call('set_cards', {'gameId': 'g', 'categoryId': 'c1', 'cards': [{'text': 'x', 'style': 'gothic'}]}), throwsA(isA<ToolError>()));
      expect(OverlayCard.fromJson(const OverlayCard(text: 'x', style: CardStyle.poster).toJson()).style, CardStyle.poster);
      await expectLater(
          tools.call('set_cards', {'gameId': 'g', 'categoryId': 'c1', 'cards': [{'image': 'builtin:nope'}]}), throwsA(isA<ToolError>()));

      final sound = builtinSoundsFor(effectAnswerCorrect).first.key;
      await tools.call('set_sounds', {
        'gameId': 'g',
        'categoryId': 'c1',
        'questionId': 'q1',
        'effects': {effectAnswerCorrect: sound, effectAnswerWrong: 'off'},
      });
      await tools.call('set_sounds', {'gameId': 'g', 'categoryId': 'c1', 'questionId': 'q1', 'effects': {effectAnswerWrong: ''}});
      final question = (await backend.loadGame('g')).groups.single.categories.single.questions.single;
      expect(question.sounds.effects, {effectAnswerCorrect: sound});
      await expectLater(tools.call('set_sounds', {'gameId': 'g', 'categoryId': 'c1', 'music': {'disco': 'x.mp3'}}), throwsA(isA<ToolError>()));
    });

    test('changing and deleting a group', () async {
      await tools.call('update_category_group', {'gameId': 'g', 'groupId': 'r1', 'name': 'Finale', 'board': 'display', 'color': '#102030'});
      final group = (await backend.loadGame('g')).groups.single;
      expect(group.name, 'Finale');
      expect(group.type, BoardType.display);
      expect(group.color, 0xff102030);
      await expectLater(tools.call('delete_category_group', {'gameId': 'g', 'groupId': 'r1'}), throwsA(isA<ToolError>()));
      await tools.call('delete_category', {'gameId': 'g', 'categoryId': 'c1'});
      await tools.call('delete_category_group', {'gameId': 'g', 'groupId': 'r1'});
      expect(backend.groups['g'], isEmpty);
    });
  });

  group('server', () {
    late FakeBackend backend;
    late McpServer server;
    late HttpClient http;

    setUp(() async {
      backend = FakeBackend();
      server = McpServer(GameTools(backend));
      await server.start(port: 0);
      http = HttpClient();
    });

    tearDown(() async {
      http.close(force: true);
      await server.stop();
    });

    Future<(int, Object?)> send(Object? body, {String method = 'POST', String path = '/mcp', Map<String, String> headers = const {}, String? raw}) async {
      final request = await http.open(method, '127.0.0.1', server.port, path);
      headers.forEach(request.headers.set);
      if (method == 'POST') {
        request.headers.contentType = ContentType.json;
        request.headers.set('accept', 'application/json, text/event-stream');
        request.write(raw ?? jsonEncode(body));
      }
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
    }

    Future<Map<String, dynamic>> rpc(String method, [Map<String, dynamic>? params]) async {
      final (status, body) = await send({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': ?params});
      expect(status, 200);
      return Map<String, dynamic>.from(body as Map);
    }

    test('the handshake a client makes', () async {
      final init = await rpc('initialize', {
        'protocolVersion': '2025-06-18',
        'capabilities': <String, dynamic>{},
        'clientInfo': {'name': 'test', 'version': '1'},
      });
      expect(init['result']['protocolVersion'], '2025-06-18');
      expect(init['result']['capabilities'], containsPair('tools', isMap));
      expect(init['result']['serverInfo']['name'], 'quiz-studio');
      final (status, body) = await send({'jsonrpc': '2.0', 'method': 'notifications/initialized'});
      expect(status, 202);
      expect(body, isNull);
      expect((await rpc('ping'))['result'], isEmpty);
      // A version from the future is answered with one this server knows.
      expect((await rpc('initialize', {'protocolVersion': '2099-01-01'}))['result']['protocolVersion'], '2025-06-18');
    });

    test('every tool is listed with a schema', () async {
      final listed = (await rpc('tools/list'))['result']['tools'] as List;
      expect([for (final tool in listed) tool['name']], containsAll(['list_games', 'get_game', 'add_category', 'add_question']));
      for (final tool in listed) {
        expect(tool['description'], isNotEmpty);
        expect(tool['inputSchema']['type'], 'object');
      }
    });

    test('calling a tool changes the game', () async {
      final reply = await rpc('tools/call', {
        'name': 'add_question',
        'arguments': {'gameId': 'g', 'categoryId': 'c1', 'question': 'Capital of Peru?', 'answerHint': 'Lima', 'pointsPlus': 200},
      });
      expect(reply['result']['isError'], false);
      final id = jsonDecode(reply['result']['content'][0]['text'] as String)['questionId'];
      expect(backend.questions['c1']![id], containsPair('answerHint', 'Lima'));
    });

    test('a mistake comes back as a failed call the assistant can read', () async {
      final reply = await rpc('tools/call', {
        'name': 'add_question',
        'arguments': {'gameId': 'g', 'categoryId': 'c1', 'type': 'abcd', 'question': 'Pick'},
      });
      expect(reply['result']['isError'], true);
      expect(reply['result']['content'][0]['text'], contains('four'));
      expect(backend.questions['c1'], hasLength(1));
    });

    test('protocol errors', () async {
      expect((await rpc('resources/list'))['error']['code'], -32601);
      final (_, parse) = await send(null, raw: '{not json');
      expect((parse as Map)['error']['code'], -32700);
      final (_, invalid) = await send({'id': 1, 'method': 'ping'});
      expect((invalid as Map)['error']['code'], -32600);
      expect((await send(null, method: 'GET')).$1, 405);
      expect((await send(null, method: 'DELETE')).$1, 405);
      expect((await send({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}, path: '/other')).$1, 404);
    });

    test('a batch gets a batch back', () async {
      final (status, body) = await send([
        {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'},
        {'jsonrpc': '2.0', 'method': 'notifications/initialized'},
        {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'},
      ]);
      expect(status, 200);
      expect([for (final reply in body as List) reply['id']], [1, 2]);
    });

    test('web pages and foreign host names are turned away', () async {
      const ping = {'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'};
      expect((await send(ping, headers: {'origin': 'https://evil.example'})).$1, 403);
      expect((await send(ping, headers: {'origin': 'null'})).$1, 403);
      // DNS rebinding: a name that resolves to this computer.
      expect((await send(ping, headers: {'host': 'evil.example:${server.port}'})).$1, 403);
      expect((await send(ping, headers: {'origin': 'http://localhost:3000'})).$1, 200);
      expect((await send(ping, headers: {'host': 'localhost:${server.port}'})).$1, 200);
    });

    test('it listens on this computer only', () async {
      final others = [
        for (final interface in await NetworkInterface.list())
          for (final address in interface.addresses)
            if (!address.isLoopback && address.type == InternetAddressType.IPv4) address,
      ];
      for (final address in others) {
        await expectLater(Socket.connect(address, server.port, timeout: const Duration(seconds: 2)), throwsA(anything));
      }
    });
  });

  group('clients', () {
    const url = 'http://localhost:47820/mcp';

    test('every program gets the address, as a command or as valid JSON', () {
      for (final client in AssistantClient.values) {
        final snippet = client.snippet(url);
        expect(snippet, contains(url), reason: client.label);
        if (!client.isCommand) expect(() => jsonDecode(snippet), returnsNormally, reason: client.label);
      }
    });

    test('Claude Desktop goes through the bridge', () {
      final config = jsonDecode(AssistantClient.claudeDesktop.snippet(url)) as Map;
      expect(config['mcpServers']['quiz-studio'], {
        'command': 'npx',
        'args': ['-y', 'mcp-remote', url],
      });
    });
  });

  group('switch', () {
    test('off until started, and off again after stop', () async {
      final assistant = Assistant(backend: FakeBackend());
      var changes = 0;
      assistant.addListener(() => changes++);
      expect(assistant.running, false);
      expect(assistant.connectCommand, isNull);

      await assistant.start(port: 0);
      expect(assistant.running, true);
      expect(assistant.connectCommand, 'claude mcp add --transport http quiz-studio ${assistant.url}');
      final port = Uri.parse(assistant.url!).port;

      final http = HttpClient();
      final request = await http.post('127.0.0.1', port, '/mcp');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'tools/call',
        'params': {
          'name': 'add_category',
          'arguments': {'gameId': 'g', 'name': 'Rivers', 'groupId': 'r1'},
        },
      }));
      await (await request.close()).drain<void>();
      http.close(force: true);
      expect(assistant.activity, ['Added category "Rivers"']);

      await assistant.stop();
      expect(assistant.running, false);
      await expectLater(Socket.connect('127.0.0.1', port, timeout: const Duration(seconds: 2)), throwsA(anything));
      expect(changes, 3);
    });

    test('a taken port falls back to a free one', () async {
      final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final server = McpServer(GameTools(FakeBackend()));
      final port = await server.start(port: blocker.port);
      expect(port, isNot(blocker.port));
      expect(port, greaterThan(0));
      await server.stop();
      await blocker.close();
    });
  });
}
