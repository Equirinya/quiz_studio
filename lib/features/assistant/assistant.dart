import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;

import 'package:quiz_show/features/assistant/game_tools.dart';
import 'package:quiz_show/features/assistant/mcp_server.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/media_service.dart';
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
  Future<void> updateGroup(String gameId, String groupId, Map<String, dynamic> data) => _repo.updateGroup(gameId, groupId, data);

  @override
  Future<void> deleteGroup(String gameId, String groupId) => _repo.deleteGroup(gameId, groupId);

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

  @override
  Future<String> uploadMedia(String gameId, String path) async {
    if (!await File(path).exists()) throw ToolError('There is no file at "$path".');
    if (RegExp(r'\.(ogg|oga|opus)$', caseSensitive: false).hasMatch(path)) {
      throw const ToolError('Ogg sounds do not play on Windows; convert the file to MP3, WAV or M4A first.');
    }
    if (contentTypeForPath(path) == null) throw const ToolError('Only pictures, sounds and videos can be uploaded.');
    return MediaService.instance.upload(gameId, path);
  }
}

/// The switch behind "Let an AI assistant edit my games". Off whenever the app starts:
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
  String? get connectCommand => running ? AssistantClient.claudeCode.snippet(url!) : null;

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

/// The programs that can use the assistant connection, and what each needs
/// to be told about it. They all have to run on this computer: the server
/// only answers here, which leaves out assistants in the browser.
enum AssistantClient {
  claudeCode("Claude Code"),
  claudeDesktop("Claude Desktop"),
  codex("Codex CLI"),
  geminiCli("Gemini CLI"),
  cursor("Cursor"),
  vsCode("VS Code"),
  windsurf("Windsurf"),
  openCode("OpenCode"),
  lmStudio("LM Studio");

  const AssistantClient(this.label);

  final String label;

  /// What to do with [snippet].
  String get instructions => switch (this) {
        claudeCode => "Run this once in a terminal, then ask Claude about your games:",
        claudeDesktop => "Add this to claude_desktop_config.json (Settings > Developer > Edit Config), then restart "
            "Claude Desktop. It needs Node.js, which bridges Claude Desktop to this connection.",
        codex => "Run this once in a terminal, then ask Codex about your games:",
        geminiCli => "Add this to ~/.gemini/settings.json:",
        cursor => "Add this to ~/.cursor/mcp.json, or under Settings > MCP:",
        vsCode => "Add this to .vscode/mcp.json in your folder, or run \"MCP: Add Server\":",
        windsurf => "Add this to ~/.codeium/windsurf/mcp_config.json (Cascade > MCPs > Configure), then refresh:",
        openCode => "Add this to opencode.json in your folder, or to ~/.config/opencode/opencode.json:",
        lmStudio => "Add this to mcp.json (Program > Install > Edit mcp.json). A local model then edits your games:",
      };

  /// Whether [snippet] is a command for a terminal rather than settings to paste.
  bool get isCommand => this == claudeCode || this == codex;

  /// What to run or paste for the server at [url].
  String snippet(String url) => switch (this) {
        claudeCode => 'claude mcp add --transport http quiz-studio $url',
        claudeDesktop => _servers('mcpServers', {
            'command': 'npx',
            'args': ['-y', 'mcp-remote', url],
          }),
        codex => 'codex mcp add quiz-studio --url $url',
        geminiCli => _servers('mcpServers', {'httpUrl': url}),
        cursor || lmStudio => _servers('mcpServers', {'url': url}),
        vsCode => _servers('servers', {'type': 'http', 'url': url}),
        windsurf => _servers('mcpServers', {'serverUrl': url}),
        openCode => _servers('mcp', {'type': 'remote', 'url': url}),
      };

  static String _servers(String key, Map<String, Object> server) => const JsonEncoder.withIndent('  ').convert({
        key: {'quiz-studio': server},
      });
}
