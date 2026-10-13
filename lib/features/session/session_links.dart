import 'package:quiz_show/game/game.dart';

/// What a device needs to join a session, as carried by the QR code the
/// presenter shows. The token is the secret; role and team ride along because
/// a joining device cannot read the token document.
class SessionJoinLink {
  const SessionJoinLink({required this.sessionId, required this.token, required this.role, this.teamId})
      : assert(role != Role.host),
        assert((role == Role.player) == (teamId != null));

  final String sessionId;
  final String token;
  final Role role;

  /// Players only: the team this code is for.
  final String? teamId;

  /// `quiz-studio://session/{sessionId}/{role}/{token}[/{teamId}]`
  String get link => 'quiz-studio://session/$sessionId/${role.name}/$token${teamId == null ? '' : '/$teamId'}';

  static SessionJoinLink? tryParse(String input) {
    const prefix = 'quiz-studio://session/';
    final text = input.trim();
    if (!text.startsWith(prefix)) return null;
    final parts = text.substring(prefix.length).split('/');
    final valid = RegExp(r'^[A-Za-z0-9_-]+$');
    if (parts.length < 3 || parts.length > 4 || !parts.every(valid.hasMatch)) return null;
    final role = switch (parts[1]) {
      'controller' => Role.controller,
      'player' => Role.player,
      _ => null,
    };
    if (role == null || (role == Role.player) != (parts.length == 4)) return null;
    return SessionJoinLink(sessionId: parts[0], token: parts[2], role: role, teamId: parts.length == 4 ? parts[3] : null);
  }
}

/// Where a device sends its commands: straight into the local host when it is
/// presenting, or over a transport when it is not.
abstract class CommandSink {
  void send(Command command);
}

class LocalCommandSink implements CommandSink {
  const LocalCommandSink(this.host);

  final SessionHost host;

  @override
  void send(Command command) => host.dispatch(command);
}
