import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/auth/widgets/user_name.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/l10n/l10n.dart';

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
    }, failure: context.l10n.couldNotCreateInvite);
  }

  Future<void> _copy(GameInvite invite) async {
    await Clipboard.setData(ClipboardData(text: invite.link));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.inviteLinkCopied)));
  }

  Future<void> _remove(String uid) async {
    final sure = await confirm(
      context,
      title: context.l10n.removeFromGame,
      message: context.l10n.removeFromGameText,
      action: context.l10n.remove,
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
      appBar: AppBar(title: Text(context.l10n.access)),
      body: StreamBuilder<GameSnapshot>(
        stream: _game,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(context.l10n.gameNotAvailable));
          final game = snapshot.data;
          if (game == null) return const Center(child: CupertinoActivityIndicator());
          final admins = List<String>.from(game.data[GameRole.admin.name] as List? ?? const []);
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              header(context.l10n.members),
              for (final role in GameRole.values)
                for (final uid in List<String>.from(game.data[role.name] as List? ?? const []))
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: UserName(uid),
                    subtitle: uid == me ? Text(context.l10n.you) : null,
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
                            for (final option in GameRole.values) DropdownMenuItem(value: option, child: Text(context.l10n.gameRole(option))),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_remove_outlined),
                          tooltip: context.l10n.remove,
                          onPressed: role == GameRole.admin && admins.length == 1 ? null : () => _remove(uid),
                        ),
                      ],
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  context.l10n.accessExplanation,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              header(context.l10n.inviteLinks),
              StreamBuilder<List<GameInvite>>(
                stream: _invites,
                builder: (context, snapshot) {
                  final now = DateTime.now();
                  final invites = snapshot.data ?? const <GameInvite>[];
                  return Column(
                    children: [
                      if (snapshot.hasData && invites.isEmpty)
                        ListTile(title: Text(context.l10n.noInviteLinksYet)),
                      for (final invite in invites)
                        ListTile(
                          leading: const Icon(Icons.link),
                          title: Text(context.l10n.gameRole(invite.role)),
                          subtitle: Text(
                            invite.isExpired(now)
                                ? context.l10n.expired
                                : invite.expiresAtMillis == null
                                    ? context.l10n.valid
                                    : context.l10n.validFor(_remaining(context.l10n, invite.expiresAtMillis! - now.millisecondsSinceEpoch)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy),
                                tooltip: context.l10n.copyLink,
                                onPressed: invite.isExpired(now) ? null : () => _copy(invite),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: context.l10n.revoke,
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
                        label: Text(context.l10n.newRoleLink(role.name)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.inviteLinksText,
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

String _remaining(AppLocalizations l10n, int millis) {
  final hours = (millis / Duration.millisecondsPerHour).ceil();
  if (hours < 48) return l10n.hourCount(hours);
  return l10n.dayCount((hours / 24).floor());
}

/// Paste an invite link, see what it grants, join. Returns the game's id.
/// With [link] (one tapped elsewhere) it is looked up right away.
Future<String?> showJoinGameDialog(BuildContext context, {String? link}) =>
    showDialog<String>(context: context, builder: (_) => _JoinGameDialog(link: link));

class _JoinGameDialog extends StatefulWidget {
  const _JoinGameDialog({this.link});

  final String? link;

  @override
  State<_JoinGameDialog> createState() => _JoinGameDialogState();
}

class _JoinGameDialogState extends State<_JoinGameDialog> {
  late final TextEditingController _link = TextEditingController(text: widget.link);
  GameInvite? _invite;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.link != null) WidgetsBinding.instance.addPostFrameCallback((_) => _lookUp());
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _lookUp() async {
    final parsed = parseInviteLink(_link.text);
    if (parsed == null) {
      setState(() => _error = context.l10n.notAnInviteLink);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    GameInvite? invite;
    String? error;
    final l10n = context.l10n;
    try {
      invite = await GameRepository.instance.loadInvite(parsed.gameId, parsed.inviteId);
      if (invite == null) {
        error = l10n.inviteGone;
      } else if (invite.isExpired(DateTime.now())) {
        invite = null;
        error = l10n.inviteExpired;
      }
    } catch (_) {
      error = l10n.couldNotCheckInvite;
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
        _error = context.l10n.couldNotJoinGame;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    return AlertDialog(
      title: Text(context.l10n.joinAGame),
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
                decoration: InputDecoration(labelText: context.l10n.inviteLink),
                onSubmitted: (_) => _lookUp(),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.quiz_outlined),
                title: Text(invite.gameName.isEmpty ? context.l10n.unnamedGame : invite.gameName),
                subtitle: Text(context.l10n.youWillJoinWith(invite.role.name)),
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
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(context.l10n.cancel)),
        FilledButton(
          onPressed: _busy ? null : (invite == null ? _lookUp : _join),
          child: _busy ? const CupertinoActivityIndicator() : Text(invite == null ? context.l10n.continueLabel : context.l10n.join),
        ),
      ],
    );
  }
}
