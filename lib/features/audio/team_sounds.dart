import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A buzzer sound of its own for a team. The files live on the presenting
/// device, which is the only one that plays them, so nothing is uploaded.
class TeamSounds {
  TeamSounds._();

  static final TeamSounds instance = TeamSounds._();

  SharedPreferences? _prefs;
  final Map<String, String> _paths = {};

  static String _key(String sessionId, String teamId) => 'team_sound.$sessionId.$teamId';

  /// Loads what was chosen for [sessionId] earlier on this device.
  Future<void> load(String sessionId) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final prefix = 'team_sound.$sessionId.';
    _paths.removeWhere((key, _) => key.startsWith(prefix));
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final path = prefs.getString(key);
      if (path != null && File(path).existsSync()) _paths[key] = path;
    }
  }

  /// The sound file for a team, or null for the default buzzer.
  String? pathFor(String sessionId, String teamId) => _paths[_key(sessionId, teamId)];

  /// Copies [sourcePath] into the app's own storage and makes it the team's
  /// sound; the original may be moved or deleted afterwards.
  Future<void> set(String sessionId, String teamId, String sourcePath) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final root = await getApplicationSupportDirectory();
    final dot = sourcePath.lastIndexOf('.');
    final extension = dot < 0 ? '' : sourcePath.substring(dot).toLowerCase();
    final target = File('${root.path}/session_$sessionId/team_$teamId$extension');
    await target.parent.create(recursive: true);
    await File(sourcePath).copy(target.path);
    _paths[_key(sessionId, teamId)] = target.path;
    await prefs.setString(_key(sessionId, teamId), target.path);
  }

  Future<void> clear(String sessionId, String teamId) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final path = _paths.remove(_key(sessionId, teamId));
    await prefs.remove(_key(sessionId, teamId));
    if (path != null && File(path).existsSync()) await File(path).delete();
  }
}
