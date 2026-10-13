import 'dart:async';

import 'package:flutter/material.dart';

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
  final TextEditingController _answer = TextEditingController();

  /// Set right after a buzz, until the host has answered, so a second tap
  /// does nothing while the first is on its way.
  Timer? _justBuzzed;

  @override
  void dispose() {
    _answer.dispose();
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
        : view.answersOpen
            ? "Answer here"
            : "Answers are in";

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(team.name, style: theme.textTheme.titleMedium),
                    Text("${team.points} points", style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              if (widget.link != null) LinkStatusIcon(widget.link!),
              if (widget.onLeave != null) IconButton(icon: const Icon(Icons.logout), tooltip: "Leave", onPressed: widget.onLeave),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: position == 0 && view.phase == Phase.buzzered ? scheme.primary : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              headline,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: position == 0 && view.phase == Phase.buzzered ? scheme.onPrimary : null,
              ),
            ),
          ),
          if (view.question != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                view.question!['text'] as String? ?? '',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          Expanded(
            child: kind == null
                ? Center(
                    child: LayoutBuilder(
                      builder: (context, box) => BuzzerButton(
                        size: box.biggest.shortestSide * 0.8,
                        onPressed: canBuzz ? _buzz : null,
                      ),
                    ),
                  )
                : _answerArea(kind, team),
          ),
        ],
      ),
    );
  }

  Widget _answerArea(AnswerKind kind, Team team) {
    final theme = Theme.of(context);
    final view = widget.view;
    final submitted = view.hasSubmitted(team.id);
    if (!view.answersOpen) {
      return Center(
        child: Text(
          submitted ? "Your answer is in." : "Answers are closed.",
          style: theme.textTheme.titleMedium,
        ),
      );
    }
    final note = Text(
      submitted ? "Sent. You can still change it." : "Only the gamemaster sees this until it is shown.",
      style: theme.textTheme.bodySmall,
    );
    switch (kind) {
      case AnswerKind.text:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _answer,
              autofocus: true,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: "Your answer"),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  final text = _answer.text.trim();
                  if (text.isNotEmpty) widget.send(SubmitAnswer(team.id, PlayerAnswer(text: text)));
                },
                child: Text(submitted ? "Send again" : "Send"),
              ),
            ),
            const SizedBox(height: 8),
            note,
          ],
        );
      case AnswerKind.choice:
        final count = (view.question?['answerCount'] as num?)?.toInt() ?? 4;
        final shown = (view.question?['answers'] as List? ?? const []).cast<String>();
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.tonal(
                    onPressed: () => widget.send(SubmitAnswer(team.id, PlayerAnswer(choice: i))),
                    child: Text("${String.fromCharCode(0x41 + i)}${i < shown.length ? "   ${shown[i]}" : ""}"),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            note,
          ],
        );
      case AnswerKind.drawing:
        // The whiteboard comes with the player-input step.
        return Center(child: Text("Drawing answers are not available in this version yet.", style: theme.textTheme.titleMedium));
    }
  }
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
