import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;

import 'package:quiz_show/features/assistant/game_tools.dart';
import 'package:quiz_show/features/assistant/mcp_server.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/game/game.dart';

/// [GameToolsBackend] over the user's own games. It goes through
/// [GameRepository] as the signed-in user, so the security rules decide what
/// an assistant may touch, exactly as they do for the app itself.
class RepositoryToolsBackend implements GameToolsBackend {
  GameRepository get _repo => GameRepository.instance;

  @override
  Future<List<({String id, String name})>> listGames() async {
    final games = await _repo.watchMyGames().first;
    return [
      for (final game in games)
        if (game.role.seesEverything) (id: game.id, name: game.name),
    ];
  }

  @override
  Future<GameContent> loadGame(String gameId) async {
    try {
      return (await _repo.watchGame(gameId).first.timeout(const Duration(seconds: 15))).content;
    } catch (_) {
      throw ToolError('Could not load game "$gameId". Use list_games to see the ids.');
    }
  }

  @override
  Future<String> createGame(String name) => _repo.createGame(name: name);

  @override
  Future<String> addGroup(String gameId, String name, BoardType type, int index) =>
      _repo.addGroup(gameId, type, index, name: name);

  @override
  Future<String> addCategory(String gameId, String name, {String? groupId, required int index}) =>
      _repo.addCategory(gameId, groupId: groupId, index: index, name: name);

  @override
  Future<void> updateCategory(String gameId, String categoryId, Map<String, dynamic> data) =>
      _repo.updateCategory(gameId, categoryId, data);

  @override
  Future<void> deleteCategory(String gameId, Category category) => _repo.deleteCategory(gameId, category);

  @override
  Future<String> addQuestion(String gameId, String categoryId, Map<String, dynamic> data) =>
      _repo.addQuestion(gameId, categoryId, data: data);

  @override
  Future<void> updateQuestion(String gameId, String categoryId, String questionId, Map<String, dynamic> data) =>
      _repo.updateQuestion(gameId, categoryId, questionId, data);

  @override
  Future<void> deleteQuestion(String gameId, String categoryId, String questionId) =>
      _repo.deleteQuestion(gameId, categoryId, questionId);
}

/// The switch behind "Let Claude edit my games". Off whenever the app starts:
/// nothing here is remembered between runs.
class Assistant extends ChangeNotifier {
  Assistant({GameToolsBackend? backend}) : _backend = backend ?? RepositoryToolsBackend();

  static final Assistant instance = Assistant();

  /// Only computers run the assistant server.
  static bool get supported => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  final GameToolsBackend _backend;
  McpServer? _server;
  final List<String> _activity = [];

  bool get running => _server != null;

  String? get url => _server?.url;

  /// The command that adds this app to Claude Code.
  String? get connectCommand => running ? 'claude mcp add --transport http quiz-studio $url' : null;

  /// What the assistant changed since it was switched on, newest first.
  List<String> get activity => List.unmodifiable(_activity);

  Future<void> start({int port = kAssistantPort}) async {
    if (running) return;
    final server = McpServer(GameTools(_backend, onActivity: _record));
    await server.start(port: port);
    _server = server;
    _activity.clear();
    notifyListeners();
  }

  Future<void> stop() async {
    final server = _server;
    if (server == null) return;
    _server = null;
    notifyListeners();
    await server.stop();
  }

  void _record(String line) {
    _activity.insert(0, line);
    if (_activity.length > 50) _activity.removeLast();
    notifyListeners();
  }
}
