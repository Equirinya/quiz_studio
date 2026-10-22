import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/buzzers/buzzers_page.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/features/session/widgets/team_colors.dart';
import 'package:quiz_show/game/game.dart';

/// The teams of a session and its buzzers, set up before the show.
///
/// No device runs the session yet, so this one holds it for a moment: the
/// stored state is loaded into a host of its own and every change is saved
/// back, for the presenter to start from.
class SessionSetupPage extends StatefulWidget {
  const SessionSetupPage({super.key, required this.session, required this.title});

  final SessionSummary session;
  final String title;

  @override
  State<SessionSetupPage> createState() => _SessionSetupPageState();
}

class _SessionSetupPageState extends State<SessionSetupPage> {
  SessionConnection? _connection;
  StreamSubscription<SessionState>? _saving;
  Object? _error;

  String get _sessionId => widget.session.id;

  @override
  void initState() {
    super.initState();
    FirestoreHostLink.loadState(_sessionId).then(
      (state) {
        if (!mounted) return;
        final host = SessionHost(initial: state);
        final connection = SessionConnection.local(host, sessionId: _sessionId);
        _saving = host.states.listen((state) {
          FirestoreHostLink.saveState(_sessionId, state).catchError((Object _) {
            if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text("Could not save the change.")));
          });
        });
        setState(() => _connection = connection);
      },
      onError: (Object error) {
        if (mounted) setState(() => _error = error);
      },
    );
  }

  @override
  void dispose() {
    _saving?.cancel();
    _connection?.dispose();
    super.dispose();
  }

  void _send(Command command) => _connection!.send(command);

  Future<void> _add() async {
    final name = await promptText(context, title: "New team", label: "Name");
    if (name != null && name.trim().isNotEmpty) _send(AddTeam(newTeamId(), name.trim()));
  }

  Future<void> _rename(Team team) async {
    final name = await promptText(context, title: "Rename team", initial: team.name, label: "Name");
    if (name != null && name.trim().isNotEmpty) _send(RenameTeam(team.id, name.trim()));
  }

  Future<void> _remove(Team team) async {
    final sure = await confirm(
      context,
      title: "Remove team",
      message: "\"${team.name}\" and its points will be removed.",
      action: "Remove",
    );
    if (sure) _send(RemoveTeam(team.id));
  }

  @override
  Widget build(BuildContext context) {
    final connection = _connection;
    return Scaffold(
      appBar: AppBar(title: Text("Set up ${widget.title}")),
      floatingActionButton: connection == null
          ? null
          : FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.group_add), label: const Text("Add team")),
      body: _error != null
          ? const Center(child: Text("Could not load the session."))
          : connection == null
          ? const Center(child: CupertinoActivityIndicator())
          : ValueListenableBuilder<SessionState?>(
              valueListenable: connection.state,
              builder: (context, state, _) => SessionSetupView(
                teams: state?.teams ?? const [],
                presentedBefore: widget.session.hostDevice != null,
                onRename: _rename,
                onColor: (team, color) => _send(SetTeamColor(team.id, color)),
                onRemove: _remove,
                onBuzzers: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BuzzersPage(connection: connection))),
              ),
            ),
    );
  }
}

/// The setup itself. Takes plain data so it can be shown without a backend.
class SessionSetupView extends StatelessWidget {
  const SessionSetupView({
    super.key,
    required this.teams,
    required this.presentedBefore,
    required this.onRename,
    required this.onColor,
    required this.onRemove,
    required this.onBuzzers,
  });

  final List<Team> teams;

  /// A device presented this session before, and may still be doing so.
  final bool presentedBefore;
  final ValueChanged<Team> onRename;
  final void Function(Team team, int? color) onColor;
  final ValueChanged<Team> onRemove;
  final VoidCallback onBuzzers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (presentedBefore)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "If this session is on a screen right now, change it from Control instead: the presenting device keeps its own teams.",
              style: theme.textTheme.bodySmall,
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.radio_button_checked),
            title: const Text("Buzzers and team sounds"),
            subtitle: const Text("The USB buzzer box and the sound each team buzzes with"),
            trailing: const Icon(Icons.chevron_right),
            onTap: onBuzzers,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
          child: Text("Teams", style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        ),
        if (teams.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text("No teams yet. Add them here, or let them join with a code once the show is on."),
          ),
        for (final team in teams)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: teamColor(team) ?? theme.colorScheme.outlineVariant, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(team.name, style: theme.textTheme.titleMedium)),
                      IconButton(tooltip: "Rename", icon: const Icon(Icons.edit_outlined), onPressed: () => onRename(team)),
                      IconButton(tooltip: "Remove", icon: const Icon(Icons.delete_outline), onPressed: () => onRemove(team)),
                    ],
                  ),
                  TeamColorPicker(selected: team.color, onChanged: (color) => onColor(team, color)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
