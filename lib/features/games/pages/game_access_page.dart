import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/auth/widgets/user_name.dart';
import 'package:quiz_show/features/games/game_repository.dart';

/// Who is in a game, with which role, and the invite links that let more
/// people in. Admins only.
class GameAccessPage extends StatefulWidget {
  const GameAccessPage({super.key, required this.gameId});

  final String gameId;

  @override
  State<GameAccessPage> createState() => _GameAccessPageState();
}

class _GameAccessPageState extends State<GameAccessPage> {
  late final Stream<GameSnapshot> _game = GameRepository.instance.watchGame(widget.gameId);
  late final Stream<List<GameInvite>> _invites = GameRepository.instance.watchInvites(widget.gameId);

  GameRepository get _repo => GameRepository.instance;

  Future<void> _createInvite(String gameName, GameRole role) async {
    await guarded(context, () async {
      final invite = await _repo.createInvite(widget.gameId, gameName, role);
      if (mounted) _copy(invite);
    }, failure: "Could not create the invite link.");
  }

  Future<void> _copy(GameInvite invite) async {
    await Clipboard.setData(ClipboardData(text: invite.link));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invite link copied")));
  }

  Future<void> _remove(String uid) async {
    final sure = await confirm(
      context,
      title: "Remove from game",
      message: "They lose access right away. Revoke any invite link they still have, or they can join again.",
      action: "Remove",
    );
    if (!sure || !mounted) return;
    await guarded(context, () => _repo.setRole(widget.gameId, uid, null));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = FirebaseAuth.instance.currentUser?.uid;
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text("Access")),
      body: StreamBuilder<GameSnapshot>(
        stream: _game,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("This game is not available."));
          final game = snapshot.data;
          if (game == null) return const Center(child: CupertinoActivityIndicator());
          final admins = List<String>.from(game.data[GameRole.admin.name] as List? ?? const []);
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              header("Members"),
              for (final role in GameRole.values)
                for (final uid in List<String>.from(game.data[role.name] as List? ?? const []))
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: UserName(uid),
                    subtitle: uid == me ? const Text("You") : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButton<GameRole>(
                          value: role,
                          underline: const SizedBox(),
                          // The last admin stays admin; the rules insist too.
                          onChanged: role == GameRole.admin && admins.length == 1
                              ? null
                              : (value) {
                                  if (value != null && value != role) {
                                    guarded(context, () => _repo.setRole(widget.gameId, uid, value));
                                  }
                                },
                          items: [
                            for (final option in GameRole.values) DropdownMenuItem(value: option, child: Text(option.uiString)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_remove_outlined),
                          tooltip: "Remove",
                          onPressed: role == GameRole.admin && admins.length == 1 ? null : () => _remove(uid),
                        ),
                      ],
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  "Full access edits everything. Limited access only sees categories they created "
                  "or were given, so they can write questions and still play along.",
                  style: theme.textTheme.bodySmall,
                ),
              ),
              header("Invite links"),
              StreamBuilder<List<GameInvite>>(
                stream: _invites,
                builder: (context, snapshot) {
                  final now = DateTime.now();
                  final invites = snapshot.data ?? const <GameInvite>[];
                  return Column(
                    children: [
                      if (snapshot.hasData && invites.isEmpty)
                        const ListTile(title: Text("No invite links yet")),
                      for (final invite in invites)
                        ListTile(
                          leading: const Icon(Icons.link),
                          title: Text(invite.role.uiString),
                          subtitle: Text(
                            invite.isExpired(now)
                                ? "Expired"
                                : invite.expiresAtMillis == null
                                    ? "Valid"
                                    : "Valid for ${_remaining(invite.expiresAtMillis! - now.millisecondsSinceEpoch)}",
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy),
                                tooltip: "Copy link",
                                onPressed: invite.isExpired(now) ? null : () => _copy(invite),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: "Revoke",
                                onPressed: () => guarded(context, () => _repo.revokeInvite(widget.gameId, invite.id)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final role in [GameRole.limited, GameRole.full])
                      FilledButton.tonalIcon(
                        onPressed: () => _createInvite(game.content.name, role),
                        icon: const Icon(Icons.add_link),
                        label: Text("New ${role.uiString.toLowerCase()} link"),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Anyone with a link can join until it expires or you revoke it.",
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _remaining(int millis) {
  final hours = (millis / Duration.millisecondsPerHour).ceil();
  if (hours < 48) return hours == 1 ? "1 hour" : "$hours hours";
  return "${(hours / 24).floor()} days";
}

/// Paste an invite link, see what it grants, join. Returns the game's id.
Future<String?> showJoinGameDialog(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _JoinGameDialog());

class _JoinGameDialog extends StatefulWidget {
  const _JoinGameDialog();

  @override
  State<_JoinGameDialog> createState() => _JoinGameDialogState();
}

class _JoinGameDialogState extends State<_JoinGameDialog> {
  final TextEditingController _link = TextEditingController();
  GameInvite? _invite;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _lookUp() async {
    final parsed = parseInviteLink(_link.text);
    if (parsed == null) {
      setState(() => _error = "That doesn't look like an invite link.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    GameInvite? invite;
    String? error;
    try {
      invite = await GameRepository.instance.loadInvite(parsed.gameId, parsed.inviteId);
      if (invite == null) {
        error = "This invite link no longer exists.";
      } else if (invite.isExpired(DateTime.now())) {
        invite = null;
        error = "This invite link has expired.";
      }
    } catch (_) {
      error = "Could not check the invite link.";
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _invite = invite;
      _error = error;
    });
  }

  Future<void> _join() async {
    final invite = _invite!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await GameRepository.instance.joinGame(invite);
      if (mounted) Navigator.of(context).pop(invite.gameId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "Could not join. You may already be a member, or the link was revoked.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    return AlertDialog(
      title: const Text("Join a game"),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (invite == null)
              TextField(
                controller: _link,
                autofocus: true,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: "Invite link"),
                onSubmitted: (_) => _lookUp(),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.quiz_outlined),
                title: Text(invite.gameName.isEmpty ? "Unnamed game" : invite.gameName),
                subtitle: Text("You will join with ${invite.role.uiString.toLowerCase()}."),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text("Cancel")),
        FilledButton(
          onPressed: _busy ? null : (invite == null ? _lookUp : _join),
          child: _busy ? const CupertinoActivityIndicator() : Text(invite == null ? "Continue" : "Join"),
        ),
      ],
    );
  }
}
