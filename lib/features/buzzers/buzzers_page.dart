import 'package:flutter/material.dart';

import 'package:quiz_show/features/audio/team_sounds.dart';
import 'package:quiz_show/features/buzzers/serial_buzzers.dart';
import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/features/buzzers/serial_protocol.dart';
import 'package:quiz_show/game/game.dart';

/// Setup of the buzzer box plugged into this device: which port, how hard a
/// press has to be, and which buzzer belongs to which team.
class BuzzersPage extends StatefulWidget {
  const BuzzersPage({super.key, required this.teams, required this.sessionId});

  /// The session's teams, to name the mapping targets.
  final List<Team> teams;
  final String sessionId;

  @override
  State<BuzzersPage> createState() => _BuzzersPageState();
}

class _BuzzersPageState extends State<BuzzersPage> {
  SerialBuzzers get _serial => SerialBuzzers.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Buzzers")),
      body: ListenableBuilder(
        listenable: Listenable.merge([_serial.status, _serial.values]),
        builder: (context, _) {
          final status = _serial.status.value;
          if (status == SerialStatus.unsupported) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text("USB buzzers work on Windows, macOS and Linux."),
                const Divider(height: 32),
                ..._teamSounds(theme),
              ],
            );
          }
          final ports = _serial.availablePorts;
          final values = _serial.values.value;
          final ids = values.keys.toList()..sort();
          final teamCount = widget.teams.length > ids.length ? widget.teams.length : ids.length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownMenu<String>(
                key: ValueKey('${_serial.portName}/${ports.length}'),
                expandedInsets: EdgeInsets.zero,
                label: const Text("Serial port"),
                leadingIcon: const Icon(Icons.usb),
                initialSelection: ports.contains(_serial.portName) ? _serial.portName : null,
                dropdownMenuEntries: [for (final port in ports) DropdownMenuEntry(value: port, label: port)],
                onSelected: (port) async {
                  await _serial.selectPort(port);
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    status == SerialStatus.connected ? Icons.check_circle : Icons.error_outline,
                    color: status == SerialStatus.connected ? Colors.green : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(switch (status) {
                      SerialStatus.connected => ids.isEmpty ? "Connected, waiting for readings…" : "Connected",
                      SerialStatus.disconnected => "Could not open the port. Is the box plugged in?",
                      _ => "Pick the port the buzzer box is on.",
                    }),
                  ),
                  TextButton(
                    onPressed: () {
                      _serial.connect();
                      setState(() {});
                    },
                    child: const Text("Reconnect"),
                  ),
                ],
              ),
              const Divider(height: 32),
              if (ids.isNotEmpty)
                Text(
                  "The bar shows how hard each buzzer is pressed. It counts as a press when it passes the marker.",
                  style: theme.textTheme.bodySmall,
                ),
              for (final id in ids)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      SizedBox(width: 72, child: Text("Buzzer ${id + 1}", style: theme.textTheme.titleSmall)),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            LinearProgressIndicator(
                              value: (values[id]! / kBuzzerMaxValue).clamp(0, 1).toDouble(),
                              minHeight: 12,
                              borderRadius: BorderRadius.circular(6),
                              color: values[id]! > _serial.thresholdOf(id) ? theme.colorScheme.primary : theme.colorScheme.outline,
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.transparent,
                                inactiveTrackColor: Colors.transparent,
                                overlayShape: SliderComponentShape.noOverlay,
                              ),
                              child: Slider(
                                min: 0,
                                max: kBuzzerMaxValue.toDouble(),
                                value: _serial.thresholdOf(id).toDouble(),
                                onChanged: (value) async {
                                  await _serial.setThreshold(id, value.round());
                                  if (mounted) setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _serial.teamIndexOf(id) < teamCount ? _serial.teamIndexOf(id) : null,
                        hint: const Text("Team"),
                        items: [
                          for (var i = 0; i < teamCount; i++)
                            DropdownMenuItem(value: i, child: Text(widget.teams.elementAtOrNull(i)?.name ?? "Team ${i + 1}")),
                        ],
                        onChanged: (index) async {
                          if (index == null) return;
                          await _serial.setTeamIndex(id, index);
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              const Divider(height: 32),
              ..._teamSounds(theme),
            ],
          );
        },
      ),
    );
  }

  /// A buzzer sound per team, whatever the team buzzes with.
  List<Widget> _teamSounds(ThemeData theme) => [
        Text("Buzzer sounds", style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        Text("Played on this device when the team buzzes. Teams without one get the default sound.", style: theme.textTheme.bodySmall),
        for (final team in widget.teams)
          Builder(builder: (context) {
            final own = TeamSounds.instance.pathFor(widget.sessionId, team.id);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(own == null ? Icons.notifications_none : Icons.notifications_active),
              title: Text(team.name),
              subtitle: Text(own == null ? "Default sound" : "Own sound"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () async {
                      final path = await MediaKind.audio.pick();
                      if (path == null) return;
                      await TeamSounds.instance.set(widget.sessionId, team.id, path);
                      if (mounted) setState(() {});
                    },
                    child: Text(own == null ? "Choose" : "Change"),
                  ),
                  if (own != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: "Back to the default sound",
                      onPressed: () async {
                        await TeamSounds.instance.clear(widget.sessionId, team.id);
                        if (mounted) setState(() {});
                      },
                    ),
                ],
              ),
            );
          }),
        if (widget.teams.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text("Add teams first.")),
      ];
}
