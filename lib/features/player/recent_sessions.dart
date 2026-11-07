import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:quiz_show/features/session/session_links.dart';

/// A session this device joined before, to get back in without the code.
class RecentSession {
  const RecentSession({required this.link, required this.joinedAtMillis});

  final SessionJoinLink link;
  final int joinedAtMillis;
}

/// The most recent joins, newest first, one per session and role.
List<RecentSession> decodeRecentSessions(List<String>? stored) {
  final result = <RecentSession>[];
  for (final entry in stored ?? const <String>[]) {
    try {
      final json = jsonDecode(entry) as Map<String, dynamic>;
      final link = SessionJoinLink.tryParse(json['link'] as String);
      if (link != null) result.add(RecentSession(link: link, joinedAtMillis: (json['at'] as num).toInt()));
    } catch (_) {
      // An entry from another version; skip it.
    }
  }
  return result;
}

/// Puts [link] in front of [existing], replacing an older join of the same
/// session in the same role and team, and keeps the list short.
List<String> encodeRecentSessions(List<RecentSession> existing, SessionJoinLink link, int nowMillis, {int keep = 5}) {
  bool same(RecentSession other) =>
      other.link.sessionId == link.sessionId && other.link.role == link.role && other.link.teamId == link.teamId;
  final all = [RecentSession(link: link, joinedAtMillis: nowMillis), ...existing.where((other) => !same(other))];
  return [
    for (final recent in all.take(keep)) jsonEncode({'link': recent.link.link, 'at': recent.joinedAtMillis}),
  ];
}

class RecentSessions {
  static const String _key = 'recent_sessions';

  static Future<List<RecentSession>> load() async =>
      decodeRecentSessions((await SharedPreferences.getInstance()).getStringList(_key));

  static Future<void> remember(SessionJoinLink link) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = decodeRecentSessions(prefs.getStringList(_key));
    await prefs.setStringList(_key, encodeRecentSessions(existing, link, DateTime.now().millisecondsSinceEpoch));
  }
}
