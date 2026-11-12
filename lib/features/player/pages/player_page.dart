import 'dart:async';
import 'dart:typed_data';

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
import 'package:quiz_show/features/session/widgets/score_pop.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

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
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.l10n.didNotGetThrough)));
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
    // Playing along is left by closing the app, not by a stray back gesture;
    // the messages below (show not reachable, team removed) still offer "Leave".
    return PopScope(
      canPop: false,
      child: Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_client.view, _client.link, _client.cloudOk, _client.background, _client.pictures]),
          builder: (context, _) {
            final view = _client.view.value;
            final onLan = _client.link.value == LinkStatus.lan;
            if (view == null) {
              // Refused by the cloud and not on the presenter's network either.
              if (!_client.cloudOk.value && !onLan) return _Message(context.l10n.couldNotReachSession, onLeave: leave);
              return _Message(context.l10n.waitingForShow, onLeave: leave);
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
              pictures: _client.pictures.value,
            );
          },
        ),
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
            TextButton(onPressed: onLeave, child: Text(context.l10n.leave)),
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
    this.pictures = const {},
  });

  /// The pictures of the round (matching) that have arrived, by media name.
  final Map<String, Uint8List> pictures;

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
      return _Message(context.l10n.teamRemovedFromSession, onLeave: widget.onLeave ?? () {});
    }
    final needed = view.minAppVersion;
    if (needed != null && widget.appVersion != null && compareVersions(widget.appVersion!, needed) < 0) {
      // Rather than show half a screen it does not understand.
      return UpdateRequiredPage(installedVersion: widget.appVersion, requiredVersion: needed);
    }
    if (view.placingBets || view.betsShown) {
      return BetScreen(view: view, team: team, send: widget.send, link: widget.link, onLeave: widget.onLeave);
    }
    final position = view.buzzQueue.indexOf(team.id);
    final answeringTeam = view.buzzQueue.isEmpty ? null : view.teams.where((t) => t.id == view.buzzQueue.first).firstOrNull;
    final standing = view.standing;
    final l10n = context.l10n;
    String nameOf(String? id) => view.teams.where((t) => t.id == id).firstOrNull?.name ?? "";
    final status = standing != null && view.phase == Phase.question
        // Last team standing: no buzzing, only whose turn it is.
        ? (standing.winner == team.id
              ? l10n.youAreLastTeam
              : standing.winner != null
              ? l10n.teamWinsShort(nameOf(standing.winner))
              : standing.out.contains(team.id)
              ? l10n.youAreOut
              : standing.current == team.id
              ? "${l10n.yourTurn}${standing.prompt == null ? "" : "\n${standing.prompt}"}"
              : l10n.teamsTurn(nameOf(standing.current)))
        : switch (view.phase) {
      Phase.buzzerTest => l10n.buzzerTestPress,
      Phase.overview => l10n.waitingForNextQuestion,
      Phase.answerRevealed => l10n.statusAnswerRevealed,
      Phase.question =>
        view.betsOnAmount
            ? (view.betVerdict(team.id) == null
                  ? l10n.yourGoal(view.bets[team.id] ?? 0)
                  : view.betVerdict(team.id)!
                  ? l10n.goalReached
                  : l10n.goalMissed)
            : !view.phoneBuzzer
            ? l10n.buzzOnBox
            : view.canBuzz(team.id)
            ? l10n.buzzWhenYouKnow
            : l10n.noBuzzersForQuestion,
      Phase.buzzered =>
        position == 0
            ? l10n.yourTurn
            : position > 0
            ? l10n.numberInLine(position + 1)
            : l10n.statusAnswering(answeringTeam?.name ?? l10n.anotherTeam),
    };
    final canBuzz = view.canBuzz(team.id) && view.phoneBuzzer && _justBuzzed == null;
    final kind = view.answerKind;
    if (view.companion != null && kind == null) {
      // A screen from a newer app than this one.
      return _Message(l10n.needsNewerVersion, onLeave: widget.onLeave ?? () {});
    }
    // While answers are collected the buzzer is replaced by the answer area.
    final headline = kind == null
        ? status
        : view.answersOpen && !view.hasLocked(team.id)
            ? (kind == CompanionKind.connections ? l10n.findFourGroups : l10n.answerHere)
            : view.isRevealed(team.id)
                ? l10n.answerBeingShown
                : view.answersOpen
                    ? l10n.lockedInWaiting
                    : l10n.answersAreIn;
    // While answering, the question stays the big line and where the team
    // stands goes under it.
    final question = view.question?['text'] as String? ?? '';
    final questionFirst = kind != null && kind != CompanionKind.connections && question.trim().isNotEmpty;
    // A Fragenhagel's own question, above the item being asked.
    final lead = view.question?['lead'] as String?;
    final leadText = lead == null
        ? null
        : Text(
            lead,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(color: scheme.outline),
          );

    final teamLine = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(team.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                !view.hasBets
                    ? l10n.pointsCount(team.points)
                    : view.betsOnAmount
                    ? "${l10n.pointsCount(team.points)} · ${l10n.goal(view.bets[team.id] ?? 0)}"
                    : "${l10n.pointsCount(team.points)} · ${l10n.betShort(view.bets[team.id] ?? 0)}",
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        // What the team just got, for a moment.
        ScorePop(teamId: team.id, log: view.scoreLog, size: 20),
        if (widget.link != null) LinkStatusIcon(widget.link!),
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
      child: Column(
        children: [
          if (questionFirst && leadText != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: leadText),
          Text(
            questionFirst ? question : headline,
            textAlign: TextAlign.center,
            maxLines: questionFirst ? 4 : null,
            overflow: questionFirst ? TextOverflow.ellipsis : null,
            style: theme.textTheme.titleMedium?.copyWith(color: highlighted ? scheme.onPrimary : null),
          ),
        ],
      ),
    );
    // While answering the question says it all; afterwards a word on where things stand.
    final answering = view.answersOpen && !view.hasLocked(team.id);
    final questionText = questionFirst
        ? (answering ? null : Text(headline, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)))
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
                        ?_note(team),
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
                ?_note(team),
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
            // Its own key: the status box of an answer screen sits in the
            // same place, and animating from this fixed height to that one's
            // free height would fail when the question changes.
            AnimatedContainer(
              key: const ValueKey('buzzer-status'),
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
              child: Column(
                children: [
                  ?leadText,
                  Flexible(
                    child: Text(question, textAlign: TextAlign.center, maxLines: 6, overflow: TextOverflow.ellipsis, style: questionStyle),
                  ),
                ],
              ),
            ),
            ?_countdown(top: 0),
            // Teams that bet on an amount show it rather than buzz.
            if (!view.phoneBuzzer || view.betsOnAmount)
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
          ?_note(team),
        ],
      ),
    );
  }

  bool _editable(Team team) => widget.view.answersOpen && !widget.view.hasLocked(team.id);

  Widget? _countdown({required double top}) {
    final view = widget.view;
    final clock = view.questionTimer;
    if (view.answerKind == null && clock != null && clock.running) {
      return Padding(
        padding: EdgeInsets.only(top: top),
        child: RoundCountdown(openedAt: clock.openedAt, endsAt: clock.endsAt),
      );
    }
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
      pictures: widget.pictures,
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
        label: Text(verdict ? context.l10n.rightExclaim : context.l10n.notThisTime),
      );
    }
    final editable = _editable(team);
    if (!view.lockable && editable) {
      return Text(
        view.answersEndAt == null
            ? context.l10n.answerCountsWhenEnded
            : context.l10n.answerCountsWhenTimeUp,
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
              ? (took == null ? context.l10n.lockedIn : context.l10n.lockedInAfter(took.toStringAsFixed(1)))
              : !view.answersOpen
                  ? context.l10n.timeIsUp
                  : view.hasSubmitted(team.id)
                      ? context.l10n.lockInAnswer
                      : context.l10n.answerFirst,
        ),
      ),
    );
  }

  /// Only once the answer is on the big screen; until then nothing needs saying.
  Widget? _note(Team team) => !widget.view.isRevealed(team.id)
      ? null
      : Text(context.l10n.answerOnBigScreen, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall);
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
          Text(context.l10n.gettingPicture, style: Theme.of(context).textTheme.bodyMedium),
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
      message: lan ? context.l10n.connectedLan : context.l10n.connectedInternet,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(lan ? Icons.wifi : Icons.cloud_outlined, size: 20, color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

/// Placing a bet before a question played with bets. The bet can be changed
/// until the gamemaster starts the question; nobody else sees it until then.
class BetScreen extends StatefulWidget {
  const BetScreen({super.key, required this.view, required this.team, required this.send, this.link, this.onLeave});

  final PublicView view;
  final Team team;
  final void Function(Command) send;
  final LinkStatus? link;
  final VoidCallback? onLeave;

  @override
  State<BetScreen> createState() => _BetScreenState();
}

class _BetScreenState extends State<BetScreen> {
  /// What the team is about to bet; null until it touches anything.
  int? _amount;

  int get _max => widget.view.ownMaxBet;

  int get _value => (_amount ?? widget.view.ownBet ?? 0).clamp(0, _max);

  /// Slider steps: tens, or single points for small limits and amounts.
  int get _step => _max >= 100 && !widget.view.betsOnAmount ? 10 : 1;

  void _set(int amount) => setState(() => _amount = amount.clamp(0, _max));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final view = widget.view;
    final team = widget.team;
    final placed = view.ownBet;
    final category = view.betCategory;
    final points = (view.question?['pointsPlus'] as num?)?.toInt();
    final minus = (view.question?['pointsMinus'] as num?)?.toInt() ?? 0;
    final amount = view.betsOnAmount;
    final prompt = view.betPrompt?.trim() ?? '';
    final value = _value;
    final divisions = (_max / _step).floor();
    final title = amount && prompt.isNotEmpty
        ? prompt
        : category != null
        ? context.l10n.yourBetOn(category)
        : context.l10n.placeYourBet;
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
                    Text(team.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(context.l10n.pointsCount(team.points), style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              if (widget.link != null) LinkStatusIcon(widget.link!),

            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
            child: Text(
              view.betsShown ? (amount ? context.l10n.theGoals : context.l10n.theBets) : title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  child: view.betsShown
                      ? _allBets(context)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "$value",
                              style: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.primary),
                            ),
                            Text(
                              !amount
                                  ? context.l10n.betOutcome(value)
                                  : minus > 0
                                  ? context.l10n.amountOutcomeWithMinus((points ?? 0) * value, minus * value)
                                  : context.l10n.amountOutcome((points ?? 0) * value),
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            Slider(
                              value: value.toDouble(),
                              max: _max.toDouble(),
                              divisions: divisions > 0 ? divisions : null,
                              label: "$value",
                              onChanged: (v) => _set(v == _max ? _max : (v / _step).round() * _step),
                            ),
                            Row(
                              children: [
                                for (final (label, to)
                                    in amount
                                        ? [("− 1", value - 1), ("+ 1", value + 1)]
                                        : [(context.l10n.betNothing, 0), (context.l10n.betHalf, (_max / 2).round()), (context.l10n.allIn, _max)])
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: OutlinedButton(onPressed: () => _set(to), child: Text(label)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          if (view.betsShown)
            Text(context.l10n.questionStartsSoon, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline))
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              // Saying "Change" shows the bet can still be changed.
              child: FilledButton.icon(
                icon: Icon(placed == value ? Icons.check : Icons.casino_outlined),
                label: Text(
                  placed == value
                      ? context.l10n.betPlaced
                      : placed == null
                      ? context.l10n.betAction(value)
                      : context.l10n.changeTo(value),
                ),
                onPressed: placed == value ? null : () => widget.send(PlaceBet(team.id, value)),
              ),
            ),
        ],
      ),
    );
  }

  /// Once the bets are closed: every team's, this team's first.
  Widget _allBets(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final view = widget.view;
    final bets = view.bets;
    final teams = [widget.team, ...view.teams.where((t) => t.id != widget.team.id)];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final team in teams)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: team.id == widget.team.id ? scheme.primaryContainer : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(child: Text(team.name, style: theme.textTheme.titleMedium)),
                Text("${bets[team.id] ?? 0}", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}
