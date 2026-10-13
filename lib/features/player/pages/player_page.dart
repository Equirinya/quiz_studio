import 'dart:async';

import 'package:flutter/material.dart';

import 'package:quiz_show/features/companion/answer_inputs.dart';
import 'package:quiz_show/features/companion/answer_view.dart';
import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/features/player/widgets/buzzer_button.dart';
import 'package:quiz_show/features/session/session_client.dart';
import 'package:quiz_show/features/session/session_links.dart';
import 'package:quiz_show/game/game.dart';

/// A player's phone during the show: a buzzer, and a place to answer when the
/// gamemaster asks every team for one.
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.link});

  /// The code this device joined with.
  final SessionJoinLink link;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final SessionClient _client = SessionClient.firestore(
    sessionId: widget.link.sessionId,
    role: Role.player,
    teamId: widget.link.teamId,
    token: widget.link.token,
    endpoints: widget.link.lan,
    onSendError: (_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text("That did not get through.")));
    },
  );

  @override
  void initState() {
    super.initState();
    _client.start();
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void leave() => Navigator.of(context).pop();
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_client.view, _client.link, _client.cloudOk]),
          builder: (context, _) {
            final view = _client.view.value;
            final onLan = _client.link.value == LinkStatus.lan;
            if (view == null) {
              // Refused by the cloud and not on the presenter's network either.
              if (!_client.cloudOk.value && !onLan) return _Message("Could not reach this session.", onLeave: leave);
              return _Message("Waiting for the show to start…", onLeave: leave);
            }
            return PlayerView(view: view, teamId: widget.link.teamId!, send: _client.send, onLeave: leave, link: _client.link.value);
          },
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {required this.onLeave});

  final String text;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(onPressed: onLeave, child: const Text("Leave")),
          ],
        ),
      );
}

/// What the player sees, given the public state. Separate from the page so
/// it can be shown and tested without a connection.
class PlayerView extends StatefulWidget {
  const PlayerView({super.key, required this.view, required this.teamId, required this.send, this.onLeave, this.link});

  final PublicView view;
  final String teamId;
  final void Function(Command) send;
  final VoidCallback? onLeave;

  /// How the presenter is reached; shown as a small icon when given.
  final LinkStatus? link;

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  /// Set right after a buzz, until the host has answered, so a second tap
  /// does nothing while the first is on its way.
  Timer? _justBuzzed;

  @override
  void dispose() {
    _justBuzzed?.cancel();
    super.dispose();
  }

  void _buzz() {
    widget.send(Buzz(widget.teamId));
    setState(() => _justBuzzed = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _justBuzzed = null);
        }));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final view = widget.view;
    final team = view.teams.where((t) => t.id == widget.teamId).firstOrNull;
    if (team == null) {
      return _Message("Your team was removed from the session.", onLeave: widget.onLeave ?? () {});
    }
    final position = view.buzzQueue.indexOf(team.id);
    final answeringTeam = view.buzzQueue.isEmpty ? null : view.teams.where((t) => t.id == view.buzzQueue.first).firstOrNull;
    final status = switch (view.phase) {
      Phase.buzzerTest => "Buzzer test: press to check",
      Phase.overview => "Waiting for the next question",
      Phase.answerRevealed => "Answer revealed",
      Phase.question => view.canBuzz(team.id) ? "Buzz when you know it!" : "No buzzers for this question",
      Phase.buzzered => position == 0
          ? "Your turn!"
          : position > 0
              ? "You are number ${position + 1} in line"
              : "${answeringTeam?.name ?? "Another team"} is answering",
    };
    final canBuzz = view.canBuzz(team.id) && _justBuzzed == null;
    final kind = view.answerKind;
    // While answers are collected the buzzer is replaced by the answer area.
    final headline = kind == null
        ? status
        : view.answersOpen && !view.hasLocked(team.id)
            ? "Answer here"
            : view.isRevealed(team.id)
                ? "Your answer is being shown"
                : "Answers are in";

    final teamLine = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(team.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text("${team.points} points", style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        if (widget.link != null) LinkStatusIcon(widget.link!),
        if (widget.onLeave != null) IconButton(icon: const Icon(Icons.logout), tooltip: "Leave", onPressed: widget.onLeave),
      ],
    );
    final highlighted = position == 0 && view.phase == Phase.buzzered;
    final statusBox = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted ? scheme.primary : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        headline,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(color: highlighted ? scheme.onPrimary : null),
      ),
    );
    final questionText = view.question == null
        ? null
        : Text(
            view.question!['text'] as String? ?? '',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          );

    // A whiteboard gets every pixel that can be spared: on a tablet held
    // sideways everything else moves into a narrow column beside it, and on
    // a phone the header shrinks to one line.
    if (kind == CompanionKind.whiteboard) {
      return LayoutBuilder(
        builder: (context, box) {
          final sideways = box.maxWidth > box.maxHeight * 1.15;
          if (sideways) {
            return Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _input(team)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 228,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        teamLine,
                        const SizedBox(height: 8),
                        statusBox,
                        if (questionText != null) Padding(padding: const EdgeInsets.only(top: 12), child: questionText),
                        ?_countdown(top: 16),
                        const Spacer(),
                        _lockButton(team),
                        const SizedBox(height: 6),
                        _note(team),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              children: [
                teamLine,
                ?questionText,
                ?_countdown(top: 6),
                const SizedBox(height: 6),
                Expanded(child: _input(team)),
                const SizedBox(height: 6),
                _lockButton(team),
                const SizedBox(height: 4),
                _note(team),
              ],
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          teamLine,
          const SizedBox(height: 12),
          statusBox,
          if (questionText != null) Padding(padding: const EdgeInsets.only(top: 12), child: questionText),
          if (kind == null)
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, box) => BuzzerButton(
                    size: box.biggest.shortestSide * 0.8,
                    onPressed: canBuzz ? _buzz : null,
                  ),
                ),
              ),
            )
          else ...[
            ?_countdown(top: 12),
            Expanded(
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Center(child: _input(team))),
            ),
            _lockButton(team),
            const SizedBox(height: 4),
            _note(team),
          ],
        ],
      ),
    );
  }

  bool _editable(Team team) => widget.view.answersOpen && !widget.view.hasLocked(team.id);

  Widget? _countdown({required double top}) {
    final view = widget.view;
    final endsAt = view.answersEndAt;
    if (!view.answersOpen || endsAt == null) return null;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: RoundCountdown(openedAt: view.answersOpenedAt, endsAt: endsAt),
    );
  }

  /// Kept alive across the round, so the answer stays on screen after it is
  /// locked.
  Widget _input(Team team) {
    final view = widget.view;
    if (view.answerKind == CompanionKind.whiteboard) {
      // Shaped after the room there is; the board keeps that shape once made.
      return LayoutBuilder(
        builder: (context, box) => CompanionInput(
          key: ValueKey('${view.answersOpenedAt}/${view.question?['text']}'),
          spec: view.companion!,
          enabled: _editable(team),
          whiteboardAspect: whiteboardAspectFor(box.biggest),
          onChanged: (answer) => widget.send(SubmitAnswer(team.id, answer)),
        ),
      );
    }
    return CompanionInput(
      key: ValueKey('${view.answersOpenedAt}/${view.question?['text']}'),
      spec: view.companion!,
      enabled: _editable(team),
      onChanged: (answer) => widget.send(SubmitAnswer(team.id, answer)),
    );
  }

  Widget _lockButton(Team team) {
    final view = widget.view;
    final verdict = view.verdictOf(team.id);
    if (verdict != null) {
      return Chip(
        avatar: Icon(verdict ? Icons.check_circle : Icons.cancel, color: verdict ? Colors.green : Theme.of(context).colorScheme.error),
        label: Text(verdict ? "Right!" : "Not this time"),
      );
    }
    final editable = _editable(team);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: editable && view.hasSubmitted(team.id) ? () => widget.send(LockAnswer(team.id)) : null,
        icon: Icon(editable ? Icons.lock_open : Icons.lock),
        label: Text(
          view.hasLocked(team.id)
              ? "Locked in"
              : !view.answersOpen
                  ? "Time is up"
                  : view.hasSubmitted(team.id)
                      ? "Lock in answer"
                      : "Answer first",
        ),
      ),
    );
  }

  Widget _note(Team team) => Text(
        widget.view.isRevealed(team.id) ? "Your answer is on the big screen." : "Only the gamemaster sees this until it is shown.",
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      );
}

/// Wi-Fi when the presenter is reached directly, a cloud when not.
class LinkStatusIcon extends StatelessWidget {
  const LinkStatusIcon(this.status, {super.key});

  final LinkStatus status;

  @override
  Widget build(BuildContext context) {
    final lan = status == LinkStatus.lan;
    return Tooltip(
      message: lan ? "Connected over the local network" : "Connected through the internet",
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(lan ? Icons.wifi : Icons.cloud_outlined, size: 20, color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}
