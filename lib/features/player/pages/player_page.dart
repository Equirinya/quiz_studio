import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:quiz_show/core/version_gate.dart';
import 'package:quiz_show/features/companion/answer_inputs.dart';
import 'package:quiz_show/features/companion/connections.dart';
import 'package:quiz_show/features/companion/answer_view.dart';
import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/features/player/widgets/buzzer_button.dart';
import 'package:quiz_show/features/session/session_client.dart';
import 'package:quiz_show/features/session/session_links.dart';
import 'package:quiz_show/features/session/widgets/team_colors.dart';
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

  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _client.start();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    }, onError: (Object _) {});
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
          listenable: Listenable.merge([_client.view, _client.link, _client.cloudOk, _client.background]),
          builder: (context, _) {
            final view = _client.view.value;
            final onLan = _client.link.value == LinkStatus.lan;
            if (view == null) {
              // Refused by the cloud and not on the presenter's network either.
              if (!_client.cloudOk.value && !onLan) return _Message("Could not reach this session.", onLeave: leave);
              return _Message("Waiting for the show to start…", onLeave: leave);
            }
            // The picture to draw on, once it is here and if it is this round's.
            final picture = _client.background.value;
            final wanted = view.companion?['backgroundImage'];
            return PlayerView(
              view: view,
              teamId: widget.link.teamId!,
              send: _client.send,
              onLeave: leave,
              link: _client.link.value,
              appVersion: _appVersion,
              backgroundImage: picture != null && picture.$1 == wanted ? MemoryImage(picture.$2) : null,
            );
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
  const PlayerView({
    super.key,
    required this.view,
    required this.teamId,
    required this.send,
    this.onLeave,
    this.link,
    this.backgroundImage,
    this.appVersion,
  });

  /// This app's version, to compare with what the session needs; unknown
  /// versions are let through.
  final String? appVersion;

  /// The picture of a whiteboard round, when it has one and it has arrived.
  final ImageProvider? backgroundImage;

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
    final needed = view.minAppVersion;
    if (needed != null && widget.appVersion != null && compareVersions(widget.appVersion!, needed) < 0) {
      // Rather than show half a screen it does not understand.
      return UpdateRequiredPage(installedVersion: widget.appVersion, requiredVersion: needed);
    }
    final position = view.buzzQueue.indexOf(team.id);
    final answeringTeam = view.buzzQueue.isEmpty ? null : view.teams.where((t) => t.id == view.buzzQueue.first).firstOrNull;
    final status = switch (view.phase) {
      Phase.buzzerTest => "Buzzer test: press to check",
      Phase.overview => "Waiting for the next question",
      Phase.answerRevealed => "Answer revealed",
      Phase.question => !view.phoneBuzzer
          ? "Buzz on the buzzer box"
          : view.canBuzz(team.id)
          ? "Buzz when you know it!"
          : "No buzzers for this question",
      Phase.buzzered => position == 0
          ? "Your turn!"
          : position > 0
              ? "You are number ${position + 1} in line"
              : "${answeringTeam?.name ?? "Another team"} is answering",
    };
    final canBuzz = view.canBuzz(team.id) && view.phoneBuzzer && _justBuzzed == null;
    final kind = view.answerKind;
    if (view.companion != null && kind == null) {
      // A screen from a newer app than this one.
      return _Message("This question needs a newer version of Quiz Studio. Please update the app.", onLeave: widget.onLeave ?? () {});
    }
    // While answers are collected the buzzer is replaced by the answer area.
    final headline = kind == null
        ? status
        : view.answersOpen && !view.hasLocked(team.id)
            ? (kind == CompanionKind.connections ? "Find four groups of four" : "Answer here")
            : view.isRevealed(team.id)
                ? "Your answer is being shown"
                : view.answersOpen
                    ? "Locked in, waiting for the others"
                    : "Answers are in";
    // While answering, the question stays the big line and where the team
    // stands goes under it.
    final question = view.question?['text'] as String? ?? '';
    final questionFirst = kind != null && kind != CompanionKind.connections && question.trim().isNotEmpty;

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
        questionFirst ? question : headline,
        textAlign: TextAlign.center,
        maxLines: questionFirst ? 4 : null,
        overflow: questionFirst ? TextOverflow.ellipsis : null,
        style: theme.textTheme.titleMedium?.copyWith(color: highlighted ? scheme.onPrimary : null),
      ),
    );
    final questionText = questionFirst
        ? Text(headline, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline))
        : view.question == null
            ? null
            : Text(
                question,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              );

    if (kind == CompanionKind.connections) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: [
            teamLine,
            const SizedBox(height: 8),
            statusBox,
            ?_countdown(top: 10),
            const SizedBox(height: 8),
            Expanded(
              child: ConnectionsPlay(
                key: ValueKey('connections-${view.answersOpenedAt}'),
                view: view,
                teamId: team.id,
                send: widget.send,
              ),
            ),
          ],
        ),
      );
    }

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
                if (questionFirst)
                  Text(question, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
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

    if (kind == null) {
      // The buzzer keeps its place while the lines above change, as they do
      // with every Fragenhagel item: the status and the question each get
      // room for as many lines as they may take, the question rather too
      // much than too little.
      final scaler = MediaQuery.textScalerOf(context);
      double lines(TextStyle? style, int count) => scaler.scale(style?.fontSize ?? 16) * (style?.height ?? 1.2) * count;
      final statusStyle = theme.textTheme.titleMedium;
      final questionStyle = theme.textTheme.bodyLarge;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            teamLine,
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: lines(statusStyle, 2) + 24,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: highlighted ? scheme.primary : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                headline,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: statusStyle?.copyWith(color: highlighted ? scheme.onPrimary : null),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: lines(questionStyle, 6),
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(question, textAlign: TextAlign.center, maxLines: 6, overflow: TextOverflow.ellipsis, style: questionStyle),
              ),
            ),
            if (!view.phoneBuzzer)
              const Spacer()
            else
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, box) => BuzzerButton(
                      size: box.biggest.shortestSide * 0.8,
                      onPressed: canBuzz ? _buzz : null,
                      color: teamColor(team),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
          ?_countdown(top: 12),
          Expanded(
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Center(child: _input(team))),
          ),
          _lockButton(team),
          const SizedBox(height: 4),
          _note(team),
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
    if (view.answerKind == CompanionKind.whiteboard && view.companion?['background'] == 'image') {
      // The board takes the picture's own shape, so it has to wait for it.
      return _PictureBoard(
        key: ValueKey('${view.answersOpenedAt}/${view.companion?['backgroundImage']}'),
        image: widget.backgroundImage,
        builder: (aspect) => CompanionInput(
          key: ValueKey('${view.answersOpenedAt}/${view.question?['text']}'),
          spec: view.companion!,
          enabled: _editable(team),
          whiteboardAspect: aspect,
          backgroundImage: widget.backgroundImage,
          onChanged: (answer) => widget.send(SubmitAnswer(team.id, answer)),
        ),
      );
    }
    if (view.answerKind == CompanionKind.whiteboard) {
      // Shaped after the room there is; the board keeps that shape once made.
      return LayoutBuilder(
        builder: (context, box) => CompanionInput(
          key: ValueKey('${view.answersOpenedAt}/${view.question?['text']}'),
          spec: view.companion!,
          enabled: _editable(team),
          whiteboardAspect: whiteboardAspectFor(box.biggest),
          backgroundImage: widget.backgroundImage,
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
    if (!view.lockable && editable) {
      return Text(
        view.answersEndAt == null
            ? "Your answer counts as it stands when the gamemaster ends the round."
            : "Your answer counts as it stands when the time is up.",
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    final lockedAt = view.ownLockedAt;
    final openedAt = view.answersOpenedAt;
    final took = lockedAt == null || openedAt == null ? null : (lockedAt - openedAt) / 1000;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: editable && view.hasSubmitted(team.id) ? () => widget.send(LockAnswer(team.id)) : null,
        icon: Icon(editable ? Icons.lock_open : Icons.lock),
        label: Text(
          view.hasLocked(team.id)
              ? (took == null ? "Locked in" : "Locked in after ${took.toStringAsFixed(1)} s")
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

/// Holds a whiteboard back until its picture is here and its proportions
/// are known, then builds it in exactly that shape. If the picture does not
/// come, the teams get a plain board after a few seconds rather than nothing.
class _PictureBoard extends StatefulWidget {
  const _PictureBoard({super.key, required this.image, required this.builder});

  final ImageProvider? image;
  final Widget Function(double aspect) builder;

  @override
  State<_PictureBoard> createState() => _PictureBoardState();
}

class _PictureBoardState extends State<_PictureBoard> {
  double? _aspect;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) {
      if (!mounted || _aspect != null) return;
      // Kept within what still fits a tile on the big screen.
      setState(() => _aspect = (info.image.width / info.image.height).clamp(0.5, 2.0).toDouble());
    },
    onError: (_, _) => _giveUp(),
  );
  Timer? _patience;

  @override
  void initState() {
    super.initState();
    _patience = Timer(const Duration(seconds: 8), _giveUp);
  }

  void _giveUp() {
    if (mounted && _aspect == null) setState(() => _aspect = kWhiteboardAspect);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_PictureBoard old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) _resolve();
  }

  void _resolve() {
    if (_aspect != null || widget.image == null) return;
    _stream?.removeListener(_listener);
    _stream = widget.image!.resolve(createLocalImageConfiguration(context))..addListener(_listener);
  }

  @override
  void dispose() {
    _patience?.cancel();
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _aspect;
    if (aspect != null) return widget.builder(aspect);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: 12),
          Text("Getting the picture…", style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
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
