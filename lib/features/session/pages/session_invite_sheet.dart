import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/auth/widgets/user_name.dart';
import 'package:quiz_show/features/session/session_links.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// The invite link of a session and who joined with it. Host only.
Future<void> showSessionInviteSheet(BuildContext context, {required String sessionId, required String title}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _SessionInviteSheet(sessionId: sessionId, title: title),
  );
}

class _SessionInviteSheet extends StatefulWidget {
  const _SessionInviteSheet({required this.sessionId, required this.title});

  final String sessionId;
  final String title;

  @override
  State<_SessionInviteSheet> createState() => _SessionInviteSheetState();
}

class _SessionInviteSheetState extends State<_SessionInviteSheet> {
  late final Stream<SessionSummary?> _session = _repo.watchSession(widget.sessionId);
  SessionInviteLink? _link;
  bool _failed = false;

  SessionRepository get _repo => SessionRepository.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool renew = false}) async {
    setState(() {
      _link = null;
      _failed = false;
    });
    try {
      final link = await _repo.inviteLink(widget.sessionId, renew: renew);
      if (mounted) setState(() => _link = link);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _copy(SessionInviteLink link) async {
    await Clipboard.setData(ClipboardData(text: link.webLink));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.inviteLinkCopied)));
  }

  Future<void> _renew() async {
    final sure = await confirm(
      context,
      title: context.l10n.newInviteLink,
      message: context.l10n.newInviteLinkText,
      action: context.l10n.newInviteLink,
    );
    if (sure && mounted) await _load(renew: true);
  }

  Future<void> _remove(String uid) async {
    final sure = await confirm(
      context,
      title: context.l10n.removeFromSession,
      message: context.l10n.removeFromSessionText,
      action: context.l10n.remove,
    );
    if (!sure || !mounted) return;
    await guarded(context, () => _repo.removeInvited(widget.sessionId, uid));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = _link;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.inviteToSessionTitle(widget.title), style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(context.l10n.inviteToSessionText, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          if (_failed)
            Text(context.l10n.couldNotCreateInvite, style: TextStyle(color: theme.colorScheme.error))
          else if (link == null)
            const Center(child: CupertinoActivityIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _copy(link),
                    icon: const Icon(Icons.copy),
                    label: Text(context.l10n.copyLink),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _renew,
                  icon: const Icon(Icons.refresh),
                  tooltip: context.l10n.newInviteLink,
                ),
              ],
            ),
          const SizedBox(height: 16),
          Text(context.l10n.invitedPeople, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          StreamBuilder<SessionSummary?>(
            stream: _session,
            builder: (context, snapshot) {
              final invited = snapshot.data?.invited ?? const <String>[];
              if (invited.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(context.l10n.nobodyInvitedYet, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                );
              }
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final uid in invited)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: UserName(uid),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove_outlined),
                          tooltip: context.l10n.removeFromSession,
                          onPressed: () => _remove(uid),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
