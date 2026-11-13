import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/player/pages/player_page.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// Every team's phone on this computer, side by side, to try a show out
/// without devices. Each runs the real phone screen against the session
/// here, no network in between. A team switched to "Bot" plays by itself.
///
/// Only for the presenting device, which holds the session.
class TestDevicesPage extends StatefulWidget {
  const TestDevicesPage({super.key, required this.connection});

  final SessionConnection connection;

  @override
  State<TestDevicesPage> createState() => _TestDevicesPageState();
}

class _TestDevicesPageState extends State<TestDevicesPage> {
  SessionHost get _host => widget.connection.host!;

  /// Teams played by a bot.
  final Set<String> _bots = {};
  final Random _random = Random();
  late final Timer _tick = Timer.periodic(const Duration(milliseconds: 700), (_) => _playBots());

  /// Round pictures read from the media folder, by name.
  final Map<String, Uint8List> _pictures = {};

  @override
  void initState() {
    super.initState();
    _tick;
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  void _send(String teamId, Command command) => _host.dispatch(command, sender: Sender(Role.player, teamId: teamId));

  /// Each bot moves now and then, so they don't all answer at once.
  void _playBots() {
    for (final teamId in _bots) {
      if (_random.nextDouble() < 0.6) continue;
      final move = botMove(_host.state, _host.game, teamId, _random);
      if (move != null) _send(teamId, move);
    }
  }

  Map<String, Uint8List> _roundPictures(SessionState state) {
    final gameId = state.gameId;
    if (gameId == null || !MediaService.instance.ready) return _pictures;
    for (final name in state.answerRound?.spec.pictures ?? const <String>[]) {
      if (_pictures.containsKey(name)) continue;
      final file = MediaService.instance.localFile(gameId, name);
      if (file.existsSync()) _pictures[name] = file.readAsBytesSync();
    }
    return _pictures;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ValueListenableBuilder<SessionState?>(
      valueListenable: widget.connection.state,
      builder: (context, state, _) {
        final teams = state?.teams ?? const <Team>[];
        final allBots = teams.isNotEmpty && teams.every((team) => _bots.contains(team.id));
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.testDevices),
            actions: [
              TextButton.icon(
                onPressed: () => setState(() => allBots ? _bots.clear() : _bots.addAll(teams.map((team) => team.id))),
                icon: Icon(allBots ? Icons.smart_toy : Icons.smart_toy_outlined),
                label: Text(allBots ? l10n.noBots : l10n.allBots),
              ),
            ],
          ),
          body: state == null
              ? const SizedBox()
              : ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final team in teams)
                      Container(
                        width: 340,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(team.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                                Text(l10n.bot),
                                Switch(
                                  value: _bots.contains(team.id),
                                  onChanged: (on) => setState(() => on ? _bots.add(team.id) : _bots.remove(team.id)),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Container(
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: theme.colorScheme.outlineVariant, width: 3),
                                ),
                                // A bot's phone shows what it does but can't be touched.
                                child: IgnorePointer(
                                  ignoring: _bots.contains(team.id),
                                  child: PlayerView(
                                    key: ValueKey(team.id),
                                    view: PublicView(_host.publicStateFor(team.id)),
                                    teamId: team.id,
                                    send: (command) => _send(team.id, command),
                                    pictures: _roundPictures(state),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
