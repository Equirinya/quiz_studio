import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:quiz_show/features/assistant/game_tools.dart';

/// Port the assistant server listens on when it is free.
const int kAssistantPort = 47820;

/// MCP protocol revisions this server can speak, newest first.
const List<String> _protocolVersions = ['2025-06-18', '2025-03-26', '2024-11-05'];

/// A Model Context Protocol server for [GameTools], over the "streamable
/// HTTP" transport: JSON-RPC messages POSTed to `/mcp`, each answered with a
/// single JSON response.
///
/// It listens on this computer only. There is no password; what keeps other
/// machines out is that it is bound to the loopback address, and what keeps
/// websites out is the check of the `Origin` and `Host` headers below: a page
/// in a browser cannot pretend to be a local program.
class McpServer {
  McpServer(this.tools, {this.name = 'quiz-studio', this.version = '2.0.0'});

  final GameTools tools;
  final String name;
  final String version;
  HttpServer? _server;

  int get port => _server?.port ?? 0;

  bool get running => _server != null;

  String get url => 'http://localhost:$port/mcp';

  /// Starts listening on [port], or on any free port when that is taken.
  Future<int> start({int port = kAssistantPort}) async {
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }
    _server!.listen(_handle, onError: (Object _) {});
    return this.port;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  static bool _isLocal(String? host) {
    if (host == null) return false;
    final name = host.startsWith('[') ? host.substring(1, host.indexOf(']')) : host.split(':').first;
    return name == 'localhost' || name == '127.0.0.1' || name == '::1';
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      // A request that arrives with a web page's origin, or that was sent to
      // some other name that merely resolves here, is not a local program.
      final origin = request.headers.value('origin');
      if (!_isLocal(request.headers.value('host')) || (origin != null && !_isLocal(Uri.tryParse(origin)?.host))) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      if (request.uri.path != '/mcp') {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (request.method != 'POST') {
        // No server-initiated stream, and no sessions to end.
        response.statusCode = HttpStatus.methodNotAllowed;
        response.headers.set('allow', 'POST');
        return;
      }
      Object? message;
      try {
        message = jsonDecode(await utf8.decoder.bind(request).join());
      } catch (_) {
        _json(response, _error(null, -32700, 'Parse error'));
        return;
      }
      final replies = <Map<String, dynamic>>[];
      for (final item in message is List ? message : [message]) {
        final reply = await _dispatch(item);
        if (reply != null) replies.add(reply);
      }
      if (replies.isEmpty) {
        // Only notifications: nothing to answer.
        response.statusCode = HttpStatus.accepted;
      } else {
        _json(response, message is List ? replies : replies.single);
      }
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }

  void _json(HttpResponse response, Object body) {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
  }

  static Map<String, dynamic> _error(Object? id, int code, String message) => {
        'jsonrpc': '2.0',
        'id': id,
        'error': {'code': code, 'message': message},
      };

  /// Answers one JSON-RPC message; null for a notification.
  Future<Map<String, dynamic>?> _dispatch(Object? message) async {
    if (message is! Map || message['jsonrpc'] != '2.0' || message['method'] is! String) {
      return _error(message is Map ? message['id'] : null, -32600, 'Invalid request');
    }
    final id = message['id'];
    final method = message['method'] as String;
    final params = message['params'] is Map ? Map<String, dynamic>.from(message['params'] as Map) : <String, dynamic>{};
    if (id == null) return null;
    Map<String, dynamic> result(Object? value) => {'jsonrpc': '2.0', 'id': id, 'result': value};

    switch (method) {
      case 'initialize':
        final asked = params['protocolVersion'];
        return result({
          'protocolVersion': _protocolVersions.contains(asked) ? asked : _protocolVersions.first,
          'capabilities': {'tools': <String, dynamic>{}},
          'serverInfo': {'name': name, 'version': version},
          'instructions': 'Tools for editing the quiz games of Quiz Studio, the app this server runs in. '
              'Start with list_games and get_game. Changes appear in the app at once. '
              'Pictures, sounds and videos cannot be added from here.',
        });
      case 'ping':
        return result(<String, dynamic>{});
      case 'tools/list':
        return result({
          'tools': [for (final tool in gameToolSpecs) tool.toJson()],
        });
      case 'tools/call':
        final toolName = params['name'];
        if (toolName is! String) return _error(id, -32602, 'Missing tool name');
        final args = params['arguments'] is Map ? Map<String, dynamic>.from(params['arguments'] as Map) : <String, dynamic>{};
        try {
          final value = await tools.call(toolName, args);
          return result({
            'content': [
              {'type': 'text', 'text': const JsonEncoder.withIndent(' ').convert(value)},
            ],
            'isError': false,
          });
        } on ToolError catch (error) {
          // Told to the assistant as a failed tool call, so it can try again.
          return result({
            'content': [
              {'type': 'text', 'text': error.message},
            ],
            'isError': true,
          });
        } catch (_) {
          return result({
            'content': [
              {'type': 'text', 'text': 'The app could not do that. The game may not exist, or the user may not edit it.'},
            ],
            'isError': true,
          });
        }
    }
    return _error(id, -32601, 'Method not found: $method');
  }
}
