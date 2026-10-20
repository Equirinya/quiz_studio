import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:quiz_show/features/session/session_links.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/game/game.dart';

/// The codes other devices scan to join: one per team for the players'
/// phones, and one for a second controller.
class ConnectDevicesPage extends StatefulWidget {
  const ConnectDevicesPage({super.key, required this.sessionId, required this.teams, this.lanEndpoints = const []});

  final String sessionId;
  final List<Team> teams;

  /// Where the presenter listens on the local network; put into every code
  /// so a device on the same network joins without the internet.
  final List<String> lanEndpoints;

  @override
  State<ConnectDevicesPage> createState() => _ConnectDevicesPageState();
}

class _ConnectDevicesPageState extends State<ConnectDevicesPage> {
  late final Future<({SessionJoinLink controller, Map<String, SessionJoinLink> players})> _links =
      SessionRepository.instance.joinLinks(widget.sessionId, widget.teams.map((team) => team.id));

  /// Index into the teams; the controller code comes after the last team.
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Connect devices")),
      body: FutureBuilder(
        future: _links,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Could not create the codes."));
          final links = snapshot.data;
          if (links == null) return const Center(child: CupertinoActivityIndicator());
          final forController = _selected >= widget.teams.length;
          final link = (forController ? links.controller : links.players[widget.teams[_selected].id]!)
              .withLan(widget.lanEndpoints);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final (i, team) in widget.teams.indexed)
                    ChoiceChip(label: Text(team.name), selected: _selected == i, onSelected: (_) => setState(() => _selected = i)),
                  ChoiceChip(
                    avatar: const Icon(Icons.tune, size: 18),
                    label: const Text("Controller"),
                    selected: forController,
                    onSelected: (_) => setState(() => _selected = widget.teams.length),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: QrImageView(data: link.webLink, size: 260),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                forController
                    ? "Scan in Quiz Studio to control this session from another device. "
                        "That device must be signed in with an account that can open the game."
                    : "Scan in Quiz Studio to use a phone as the buzzer of ${widget.teams[_selected].name}.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.lanEndpoints.isEmpty ? Icons.cloud_outlined : Icons.wifi, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.lanEndpoints.isEmpty
                          ? "Devices connect through the internet."
                          : "Devices on this network connect directly; others through the internet.",
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link.webLink));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link copied")));
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text("Copy link instead"),
                ),
              ),
              if (widget.teams.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text("Add teams first to get a buzzer code for each.", textAlign: TextAlign.center),
                ),
            ],
          );
        },
      ),
    );
  }
}
