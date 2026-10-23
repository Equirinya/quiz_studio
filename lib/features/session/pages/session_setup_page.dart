import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/buzzers/buzzers_page.dart';
import 'package:quiz_show/features/session/pages/sessions_page.dart' show openConnectDevices;
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/features/session/widgets/team_colors.dart';
import 'package:quiz_show/game/game.dart';

/// The setup of a session before the show, from the session list.
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

  @override
  Widget build(BuildContext context) {
    final connection = _connection;
    return Scaffold(
      appBar: AppBar(title: Text("Set up ${widget.title}")),
      body: _error != null
          ? const Center(child: Text("Could not load the session."))
          : connection == null
          ? const Center(child: CupertinoActivityIndicator())
          : ValueListenableBuilder<SessionState?>(
              valueListenable: connection.state,
              builder: (context, state, _) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.session.hostDevice != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          "If this session is on a screen right now, set it up from Control instead: the presenting device keeps its own teams.",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    SessionSetupView(
                      state: state ?? const SessionState(),
                      send: connection.send,
                      onConnectDevices: () => openConnectDevices(context, connection),
                      onBuzzerSetup: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BuzzersPage(connection: connection))),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// The setup of a session, the same before the show and from the
/// controller during it: the teams with their names and colours, how
/// buzzers behave, and where devices and buzzers are connected.
class SessionSetupView extends StatelessWidget {
  const SessionSetupView({super.key, required this.state, required this.send, this.onConnectDevices, this.onBuzzerSetup});

  final SessionState state;
  final void Function(Command command) send;

  /// Opens the screen with the join codes; hidden when null.
  final VoidCallback? onConnectDevices;

  /// Opens the USB buzzer box and team sounds; hidden when null.
  final VoidCallback? onBuzzerSetup;

  Future<void> _add(BuildContext context) async {
    final name = await promptText(context, title: "New team", label: "Name");
    if (name != null && name.trim().isNotEmpty) send(AddTeam(newTeamId(), name.trim()));
  }

  Future<void> _rename(BuildContext context, Team team) async {
    final name = await promptText(context, title: "Rename team", initial: team.name, label: "Name");
    if (name != null && name.trim().isNotEmpty) send(RenameTeam(team.id, name.trim()));
  }

  Future<void> _remove(BuildContext context, Team team) async {
    final sure = await confirm(
      context,
      title: "Remove team",
      message: "\"${team.name}\" and its points will be removed.",
      action: "Remove",
    );
    if (sure) send(RemoveTeam(team.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header("Teams"),
        if (state.teams.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text("No teams yet. Add them here, or let them join with a code."),
          ),
        for (final team in state.teams)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
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
                      Expanded(child: Text(team.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                      IconButton(tooltip: "Rename", icon: const Icon(Icons.edit_outlined), onPressed: () => _rename(context, team)),
                      IconButton(tooltip: "Remove", icon: const Icon(Icons.delete_outline), onPressed: () => _remove(context, team)),
                    ],
                  ),
                  TeamColorPicker(selected: team.color, onChanged: (color) => send(SetTeamColor(team.id, color))),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.group_add_outlined), label: const Text("Add team")),
        ),
        header("Buzzers"),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: const Text("Queue buzzers"),
          subtitle: const Text("Later buzzes line up behind the first"),
          value: state.queueBuzzers,
          onChanged: (value) => send(SetQueueBuzzers(value)),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: const Text("Buzzer test"),
          subtitle: const Text("Buzzers light up their team; only from the board"),
          value: state.phase == Phase.buzzerTest,
          onChanged: state.phase == Phase.overview || state.phase == Phase.buzzerTest ? (value) => send(SetBuzzerTest(value)) : null,
        ),
        if (onBuzzerSetup != null)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.usb),
            title: const Text("Buzzer box and team sounds"),
            subtitle: const Text("The USB buzzer box, and the sound each team buzzes with"),
            trailing: const Icon(Icons.chevron_right),
            onTap: onBuzzerSetup,
          ),
        if (onConnectDevices != null)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.qr_code_2),
            title: const Text("Connect devices"),
            subtitle: const Text("Phones as buzzers, or another controller"),
            trailing: const Icon(Icons.chevron_right),
            onTap: onConnectDevices,
          ),
      ],
    );
  }
}
