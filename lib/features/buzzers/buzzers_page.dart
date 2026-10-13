import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/features/audio/team_sounds.dart';
import 'package:quiz_show/features/buzzers/buzzer_link.dart';
import 'package:quiz_show/features/buzzers/serial_buzzers.dart';
import 'package:quiz_show/features/buzzers/serial_protocol.dart';
import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

/// The buzzer box of this device: connection, a live test of every buzzer,
/// which buzzer belongs to which team, and each team's sound.
class BuzzersPage extends StatefulWidget {
  const BuzzersPage({super.key, required this.connection});

  final SessionConnection connection;

  @override
  State<BuzzersPage> createState() => _BuzzersPageState();
}

class _BuzzersPageState extends State<BuzzersPage> {
  Buzzers get _buzzers => Buzzers.instance;

  String get _sessionId => widget.connection.sessionId;

  /// Teams whose sound is being uploaded.
  final Set<String> _uploading = {};

  @override
  void initState() {
    super.initState();
    if (Buzzers.supported) {
      _buzzers.start().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _chooseSound(Team team) async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await MediaKind.audio.pick();
    if (path == null || !mounted) return;
    setState(() => _uploading.add(team.id));
    try {
      final name = await TeamSounds.instance.upload(_sessionId, path);
      widget.connection.send(SetTeamSound(team.id, name));
      if (team.sound != null) TeamSounds.instance.delete(_sessionId, team.sound!);
    } on UnsupportedError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message ?? "This file cannot be used.")));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Could not upload the sound. The team keeps the one it had.")));
    }
    if (mounted) setState(() => _uploading.remove(team.id));
  }

  void _clearSound(Team team) {
    widget.connection.send(SetTeamSound(team.id, null));
    if (team.sound != null) TeamSounds.instance.delete(_sessionId, team.sound!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buzzers")),
      body: ValueListenableBuilder(
        valueListenable: widget.connection.state,
        builder: (context, state, _) {
          final teams = state?.teams ?? const <Team>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (Buzzers.supported)
                BuzzersView(
                  link: _buzzers.link,
                  teams: teams,
                  assignments: _buzzers.assignments(_sessionId),
                  onPort: (port) async {
                    await _buzzers.selectPort(port);
                    if (mounted) setState(() {});
                  },
                  onAssign: (buzzerId, teamId) async {
                    await _buzzers.assign(_sessionId, buzzerId, teamId);
                    if (mounted) setState(() {});
                  },
                  onThreshold: (buzzerId, threshold) async {
                    await _buzzers.setThreshold(buzzerId, threshold);
                    if (mounted) setState(() {});
                  },
                )
              else
                const Text(
                  "A USB buzzer box works on Windows, macOS and Linux. Phones and tablets can still be buzzers: see Connect devices.",
                ),
              const Divider(height: 40),
              TeamSoundsList(teams: teams, uploading: _uploading, onChoose: _chooseSound, onClear: _clearSound),
            ],
          );
        },
      ),
    );
  }
}

/// A buzzer sound per team, whatever the team buzzes with.
class TeamSoundsList extends StatelessWidget {
  const TeamSoundsList({super.key, required this.teams, required this.uploading, required this.onChoose, required this.onClear});

  final List<Team> teams;

  /// Ids of teams whose sound is on its way up.
  final Set<String> uploading;
  final ValueChanged<Team> onChoose;
  final ValueChanged<Team> onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Buzzer sounds", style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          "Saved with the session and played by whichever device presents. "
          "Until that device has fetched a sound, and for teams without one, the built-in buzzer plays.",
          style: theme.textTheme.bodySmall,
        ),
        for (final team in teams)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(team.sound == null ? Icons.notifications_none : Icons.notifications_active),
            title: Text(team.name),
            subtitle: Text(uploading.contains(team.id)
                ? "Uploading…"
                : team.sound == null
                    ? "Built-in buzzer"
                    : "Own sound"),
            trailing: uploading.contains(team.id)
                ? const SizedBox(width: 48, child: Center(child: CupertinoActivityIndicator()))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(onPressed: () => onChoose(team), child: Text(team.sound == null ? "Choose" : "Change")),
                      if (team.sound != null)
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: "Back to the built-in buzzer",
                          onPressed: () => onClear(team),
                        ),
                    ],
                  ),
          ),
        if (teams.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text("Add teams first.")),
      ],
    );
  }
}

/// Connection, test and team assignment of a buzzer box. Works on any
/// [BuzzerLink], so it can be shown and tested without hardware.
class BuzzersView extends StatefulWidget {
  const BuzzersView({
    super.key,
    required this.link,
    required this.teams,
    required this.assignments,
    required this.onPort,
    required this.onAssign,
    required this.onThreshold,
  });

  final BuzzerLink link;
  final List<Team> teams;

  /// Buzzers assigned by hand, as buzzer id to team id.
  final Map<int, String> assignments;
  final ValueChanged<String?> onPort;
  final void Function(int buzzerId, String? teamId) onAssign;
  final void Function(int buzzerId, int threshold) onThreshold;

  @override
  State<BuzzersView> createState() => _BuzzersViewState();
}

class _BuzzersViewState extends State<BuzzersView> {
  StreamSubscription<int>? _presses;
  Timer? _clock;

  /// Buzzers in the order they were pressed since the last reset.
  final List<int> _order = [];

  /// Whether the box's raw lines are shown. For finding faults only.
  bool _console = false;

  /// Teams waiting for their buzzer to be pressed; the first is up.
  final List<String> _awaiting = [];

  BuzzerLink get _link => widget.link;

  @override
  void initState() {
    super.initState();
    _presses = _link.pressed.listen(_onPress);
    // The uptime in the connection card moves on even when nothing changes.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _presses?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  void _onPress(int id) {
    if (!mounted) return;
    if (_awaiting.isNotEmpty) {
      // This press says "this buzzer is that team's".
      final teamId = _awaiting.removeAt(0);
      widget.onAssign(id, teamId);
      setState(() {});
      return;
    }
    setState(() {
      _order
        ..remove(id)
        ..add(id);
    });
  }

  String? _teamOf(int buzzerId) => teamForBuzzer(buzzerId, widget.teams, widget.assignments);

  Team? _team(String? id) => widget.teams.where((team) => team.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_link.status, _link.values, _link.rate]),
      builder: (context, _) {
        final values = _link.values.value;
        final ids = values.keys.toList()..sort();
        final down = _link.detector.down;
        final waitingFor = _awaiting.isEmpty ? null : _team(_awaiting.first);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ConnectionCard(link: _link, onPort: widget.onPort),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Text("Test", style: theme.textTheme.titleMedium)),
                TextButton(onPressed: _order.isEmpty ? null : () => setState(_order.clear), child: const Text("Clear order")),
                TextButton(onPressed: ids.isEmpty ? null : _calibrate, child: const Text("Calibrate")),
              ],
            ),
            Text(
              ids.isEmpty
                  ? "Buzzers appear here as soon as the box sends readings."
                  : "Press the buzzers. Each lights up while it is held, and the numbers show who was first. "
                      "Tap one to change its team or sensitivity.",
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final id in ids)
                  _BuzzerDial(
                    key: ValueKey('dial-$id'),
                    number: id + 1,
                    value: values[id]!,
                    threshold: _link.detector.thresholdOf(id),
                    down: down.contains(id),
                    order: _order.contains(id) ? _order.indexOf(id) + 1 : null,
                    team: _team(_teamOf(id))?.name,
                    onTap: () => _editBuzzer(id),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(child: Text("Teams", style: theme.textTheme.titleMedium)),
                if (_awaiting.isNotEmpty)
                  TextButton(onPressed: () => setState(_awaiting.clear), child: const Text("Cancel"))
                else
                  FilledButton.tonal(
                    onPressed:
                        widget.teams.isEmpty ? null : () => setState(() => _awaiting.addAll(widget.teams.map((t) => t.id))),
                    child: const Text("Assign all by pressing"),
                  ),
              ],
            ),
            if (waitingFor != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(Icons.touch_app, color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Press the buzzer of ${waitingFor.name} now"
                        "${_awaiting.length > 1 ? " · ${_awaiting.length - 1} more to go" : ""}",
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                "Without anything assigned, buzzer 1 is the first team, buzzer 2 the second, and so on.",
                style: theme.textTheme.bodySmall,
              ),
            for (final team in widget.teams)
              Builder(builder: (context) {
                final own = [
                  for (final id in ids)
                    if (_teamOf(id) == team.id) id,
                  // Assigned, but not sending right now.
                  for (final entry in widget.assignments.entries)
                    if (entry.value == team.id && !ids.contains(entry.key)) entry.key,
                ];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.group_outlined),
                  title: Text(team.name),
                  subtitle: Text(
                    own.isEmpty ? "No buzzer" : own.map((id) => "Buzzer ${id + 1}").join(", "),
                    style: own.isEmpty ? TextStyle(color: theme.colorScheme.error) : null,
                  ),
                  trailing: TextButton(
                    onPressed: _awaiting.isNotEmpty ? null : () => setState(() => _awaiting.add(team.id)),
                    child: const Text("Assign by pressing"),
                  ),
                );
              }),
            if (widget.teams.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 8), child: Text("Add teams in the session first.")),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Raw data", style: theme.textTheme.titleMedium),
                      Text("Exactly what the box sends, for finding faults", style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Switch(value: _console, onChanged: (on) => setState(() => _console = on)),
              ],
            ),
            if (_console)
              Container(
                key: const ValueKey('serial-console'),
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                height: 220,
                decoration: BoxDecoration(color: const Color(0xFF16181C), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.bottomLeft,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.bottomLeft,
                    maxHeight: double.infinity,
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        _link.recentLines.isEmpty
                            ? (_link.status.value == BuzzerStatus.connected ? "Nothing received yet." : "Not connected.")
                            : _link.recentLines.join("\n"),
                        softWrap: false,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.35, color: Color(0xFFB8F5C0)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Team and sensitivity of one buzzer, with its reading live.
  void _editBuzzer(int id) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ListenableBuilder(
        listenable: _link.values,
        builder: (context, _) {
          final theme = Theme.of(context);
          final value = _link.values.value[id] ?? 0;
          final threshold = _link.detector.thresholdOf(id);
          final teamId = _teamOf(id);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Buzzer ${id + 1}", style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text("Team", style: theme.textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final team in widget.teams)
                      ChoiceChip(
                        label: Text(team.name),
                        selected: teamId == team.id,
                        onSelected: (_) {
                          widget.onAssign(id, team.id);
                          Navigator.of(context).pop();
                        },
                      ),
                    if (widget.assignments.containsKey(id))
                      ActionChip(
                        label: const Text("By position"),
                        onPressed: () {
                          widget.onAssign(id, null);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text("How hard it has to be pressed", style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                // The bar is the reading, the slider's knob where a press starts.
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: LinearProgressIndicator(
                        value: (value / kBuzzerMaxValue).clamp(0, 1).toDouble(),
                        minHeight: 14,
                        borderRadius: BorderRadius.circular(7),
                        color: value > threshold ? theme.colorScheme.primary : theme.colorScheme.outline,
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                      ),
                      child: Slider(
                        min: 0,
                        max: kBuzzerMaxValue.toDouble(),
                        value: threshold.toDouble(),
                        onChanged: (next) {
                          // Applied to the detector at once, so the bar and
                          // the dial react while dragging; saved by the owner.
                          _link.detector.thresholds[id] = next.round();
                          (context as Element).markNeedsBuild();
                        },
                        onChangeEnd: (next) => widget.onThreshold(id, next.round()),
                      ),
                    ),
                  ],
                ),
                Text("Reading $value · counts as pressed above $threshold", style: theme.textTheme.bodySmall),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Two short steps that set every buzzer's sensitivity from how it
  /// actually behaves.
  Future<void> _calibrate() async {
    final result = await showDialog<Map<int, int>>(context: context, builder: (_) => _CalibrationDialog(link: _link));
    if (result == null) return;
    result.forEach(widget.onThreshold);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.isEmpty ? "No buzzer was pressed clearly." : "Calibrated ${result.length} buzzers.")),
      );
    }
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.link, required this.onPort});

  final BuzzerLink link;
  final ValueChanged<String?> onPort;

  static String _duration(int millis) {
    final seconds = millis ~/ 1000;
    if (seconds < 60) return "$seconds s";
    if (seconds < 3600) return "${seconds ~/ 60} min";
    return "${seconds ~/ 3600} h ${(seconds % 3600) ~/ 60} min";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = link.status.value;
    final ports = link.availablePorts;
    final ok = status == BuzzerStatus.connected;
    final (IconData icon, String headline, String detail) = switch (status) {
      BuzzerStatus.connected => (
          Icons.check_circle,
          "Connected",
          "${link.rate.value} readings per second · up ${_duration(link.uptimeMillis)}"
              "${link.reconnects == 0 ? "" : " · reconnected ${link.reconnects}×"}",
        ),
      BuzzerStatus.silent => (
          Icons.hourglass_top,
          "Open, but the box is not sending",
          "Trying again every few seconds. Is it the right port, and is the box powered?",
        ),
      BuzzerStatus.disconnected => (
          Icons.usb_off,
          "Not connected",
          "Trying again every few seconds. Plug the box in; nothing needs to be pressed here.",
        ),
      BuzzerStatus.notConfigured => (Icons.usb, "Choose the port of the buzzer box", "It is remembered on this device."),
      BuzzerStatus.unsupported => (Icons.usb_off, "No serial ports on this device", ""),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ok ? Colors.green.withValues(alpha: 0.14) : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 36,
                color: ok ? Colors.green : (status == BuzzerStatus.notConfigured ? scheme.primary : scheme.error),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: theme.textTheme.titleMedium),
                    if (detail.isNotEmpty) Text(detail, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownMenu<String>(
                  key: ValueKey('${link.portName}/${ports.join(',')}'),
                  expandedInsets: EdgeInsets.zero,
                  label: const Text("Port"),
                  initialSelection: ports.contains(link.portName) ? link.portName : null,
                  hintText: link.portName,
                  dropdownMenuEntries: [for (final port in ports) DropdownMenuEntry(value: port, label: port)],
                  onSelected: onPort,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: "Reconnect now",
                icon: const Icon(Icons.refresh),
                onPressed: link.portName == null ? null : link.reconnect,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One buzzer as a round lamp: it fills with how hard it is pressed, lights
/// up while it counts as pressed, and carries its place in the press order.
class _BuzzerDial extends StatelessWidget {
  const _BuzzerDial({
    super.key,
    required this.number,
    required this.value,
    required this.threshold,
    required this.down,
    required this.order,
    required this.team,
    required this.onTap,
  });

  final int number;
  final int value;
  final int threshold;
  final bool down;
  final int? order;
  final String? team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: SizedBox(
        width: 112,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: down
                        ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.6), blurRadius: 22, spreadRadius: 2)]
                        : null,
                  ),
                  child: CustomPaint(
                    painter: _DialPainter(
                      level: (value / kBuzzerMaxValue).clamp(0, 1).toDouble(),
                      threshold: (threshold / kBuzzerMaxValue).clamp(0, 1).toDouble(),
                      down: down,
                      scheme: scheme,
                    ),
                    child: Center(
                      child: Text(
                        "$number",
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: down ? scheme.onPrimary : scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                if (order != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: order == 1 ? Colors.amber : scheme.secondaryContainer,
                      child: Text(
                        "$order",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: order == 1 ? Colors.black : scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              team ?? "No team",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(color: team == null ? scheme.error : null),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.level, required this.threshold, required this.down, required this.scheme});

  final double level;
  final double threshold;
  final bool down;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(centre, radius, Paint()..color = down ? scheme.primary : scheme.surfaceContainerHighest);
    // The reading as a ring that closes as the press gets harder…
    const start = -pi / 2;
    final ring = Rect.fromCircle(center: centre, radius: radius - 5);
    canvas.drawArc(
      ring,
      start,
      2 * pi * level,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = down ? scheme.onPrimary : scheme.primary,
    );
    // …and a notch where it starts to count.
    final angle = start + 2 * pi * threshold;
    final direction = Offset(cos(angle), sin(angle));
    canvas.drawLine(
      centre + direction * (radius - 11),
      centre + direction * (radius + 1),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = down ? scheme.onPrimary : scheme.outline,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.level != level || old.threshold != threshold || old.down != down || old.scheme != scheme;
}

class _CalibrationDialog extends StatefulWidget {
  const _CalibrationDialog({required this.link});

  final BuzzerLink link;

  @override
  State<_CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends State<_CalibrationDialog> {
  final BuzzerCalibration _calibration = BuzzerCalibration();
  StreamSubscription<Map<int, int>>? _readings;
  Timer? _rest;
  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    _readings = widget.link.readings.listen((reading) {
      _calibration.add(reading);
      if (_pressing && mounted) setState(() {});
    });
    // Two seconds of everyone keeping their hands off.
    _rest = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _calibration.startPressing();
      setState(() => _pressing = true);
    });
  }

  @override
  void dispose() {
    _readings?.cancel();
    _rest?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _calibration.calibrated.toList()..sort();
    return AlertDialog(
      title: const Text("Calibrate"),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _pressing ? "Now press every buzzer once, as hard as a player would." : "Hands off all buzzers for a moment…",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (!_pressing)
              const LinearProgressIndicator()
            else
              Text(done.isEmpty ? "Waiting for the first press." : "Got ${done.map((id) => "buzzer ${id + 1}").join(", ")}."),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
        FilledButton(
          onPressed: _pressing ? () => Navigator.of(context).pop(_calibration.thresholds) : null,
          child: const Text("Done"),
        ),
      ],
    );
  }
}
