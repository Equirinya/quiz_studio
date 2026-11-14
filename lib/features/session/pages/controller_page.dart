import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/companion/answer_view.dart';
import 'package:quiz_show/features/games/pages/game_editor_page.dart' show BoardTypeIcon;
import 'package:quiz_show/features/games/widgets/cards_dialog.dart' show CardThumbnail;
import 'package:quiz_show/features/session/pages/session_setup_page.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/features/session/widgets/script_sheet.dart';
import 'package:quiz_show/features/session/widgets/team_colors.dart';
import 'package:quiz_show/features/session/widgets/score_pop.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// The gamemaster's remote.
///
/// The layout never moves: teams on top, the open question in the middle, and
/// at the bottom a pad whose buttons are always in the same place and merely
/// switch off when they do not apply. Everything that is needed less often,
/// including picking the next question, opens as a sheet from the bottom row.
///
/// It only ever sends commands. What it shows comes back from the presenting
/// device, so two controllers can never disagree about the state.
class ControllerView extends StatefulWidget {
  const ControllerView({super.key, required this.connection, this.onConnectDevices, this.onBuzzerSetup});

  final SessionConnection connection;

  /// Opens the screen with the join codes; hidden when null.
  final VoidCallback? onConnectDevices;

  /// Opens the setup of the USB buzzer box; hidden when null.
  final VoidCallback? onBuzzerSetup;

  @override
  State<ControllerView> createState() => _ControllerViewState();
}

class _ControllerViewState extends State<ControllerView> {
  SessionConnection get _c => widget.connection;

  void _send(Command command) => _c.send(command);

  /// A sheet that keeps following the live session while it is open.
  Future<void> _sheet(Widget Function(BuildContext context, SessionState state, GameContent? game) builder) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ListenableBuilder(
        listenable: Listenable.merge([_c.state, _c.game]),
        builder: (context, _) {
          final state = _c.state.value;
          if (state == null) return const SizedBox(height: 120);
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: builder(context, state, _c.game.value),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_c.state, _c.game]),
      builder: (context, _) {
        final state = _c.state.value;
        if (state == null) return const Center(child: CupertinoActivityIndicator());
        final game = _c.game.value;
        final question = state.current == null ? null : game?.question(state.current!);
        return Column(
          children: [
            _TeamStrip(state: state, game: game, onTeam: _openTeam, onAdd: _addTeam),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: _NowPanel(
                  state: state,
                  game: game,
                  question: question,
                  send: _send,
                  hostClock: _c.isPresenting,
                  backgroundImage: _c.backgroundImage(state.answerRound?.spec.backgroundImage),
                ),
              ),
            ),
            const Divider(height: 1),
            _ActionPad(state: state, game: game, question: question, send: _send),
            _SheetRow(
              boardSuggested: game != null && state.current == null && state.phase != Phase.buzzerTest,
              answersActive: state.answerRound != null,
              effectsActive: state.music != null || state.overlay != null,
              onBoard: _openBoard,
              onEffects: _openEffects,
              onAnswers: _openAnswers,
              onScript: _openScript,
              onSetup: _openSetup,
            ),
          ],
        );
      },
    );
  }

  // ── teams ──────────────────────────────────────────────────────────────────

  Future<void> _addTeam() async {
    final name = await promptText(context, title: context.l10n.newTeam, label: context.l10n.name);
    if (name != null) _send(AddTeam(newTeamId(), name));
  }

  void _openTeam(String teamId) {
    _sheet((context, state, game) {
      final team = state.team(teamId);
      if (team == null) return SizedBox(height: 80, child: Center(child: Text(context.l10n.teamRemoved)));
      final theme = Theme.of(context);
      Widget step(int delta) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FilledButton.tonal(
            onPressed: () => _send(AdjustPoints(team.id, delta)),
            child: Text(delta > 0 ? "+$delta" : "−${-delta}"),
          ),
        ),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(team.name, style: theme.textTheme.titleMedium),
            Text(team.points.toString(), style: theme.textTheme.displaySmall),
            const SizedBox(height: 12),
            Row(children: [step(-100), step(-10), step(10), step(100)]),
            const SizedBox(height: 8),
            TeamColorPicker(selected: team.color, onChanged: (color) => _send(SetTeamColor(team.id, color))),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: canBuzz(state, game, team.id)
                    ? () {
                        _send(Buzz(team.id));
                        Navigator.of(context).pop();
                      }
                    : null,
                icon: const Icon(Icons.touch_app_outlined),
                label: Text(context.l10n.buzzForTeam),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () async {
                    final name = await promptText(context, title: context.l10n.renameTeam, initial: team.name, label: context.l10n.name);
                    if (name != null) _send(RenameTeam(team.id, name));
                  },
                  child: Text(context.l10n.rename),
                ),
                TextButton(
                  onPressed: () async {
                    final text = await promptText(context, title: context.l10n.setPoints, initial: team.points.toString(), label: context.l10n.points);
                    final points = text == null ? null : int.tryParse(text);
                    if (points != null) _send(SetPoints(team.id, points));
                  },
                  child: Text(context.l10n.setPoints),
                ),
                TextButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final sure = await confirm(
                      context,
                      title: context.l10n.removeTeam,
                      message: context.l10n.removeTeamText(team.name),
                      action: context.l10n.remove,
                    );
                    if (!sure) return;
                    _send(RemoveTeam(team.id));
                    navigator.pop();
                  },
                  child: Text(context.l10n.remove),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  // ── sheets ─────────────────────────────────────────────────────────────────

  void _openBoard() => _sheet(
    (context, state, game) => game == null
        ? SizedBox(height: 120, child: Center(child: Text(context.l10n.sessionHasNoGame)))
        : _BoardSheet(state: state, game: game, send: _send),
  );

  void _openEffects() => _sheet((context, state, game) => _EffectsSheet(state: state, game: game, send: _send));

  void _openAnswers() => _sheet((context, state, game) => _AnswersSheet(state: state, game: game, send: _send));

  /// Where the script was left, per game, for [ScriptSheet.lastOffset].
  final _scriptOffsets = <String, double>{};

  void _openScript() => _sheet(
    (context, state, game) => game == null
        ? SizedBox(height: 120, child: Center(child: Text(context.l10n.sessionHasNoGame)))
        : ScriptSheet(
            key: ValueKey(game.id),
            game: game,
            current: state.current,
            groupId: state.groupId,
            lastOffset: _scriptOffsets[game.id],
            onScrolled: (offset) => _scriptOffsets[game.id] = offset,
          ),
  );

  // The same setup as before the show, from the session list.
  void _openSetup() => _sheet((context, state, game) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SessionSetupView(
          state: _c.state,
          send: _send,
          onConnectDevices: widget.onConnectDevices == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onConnectDevices!();
                },
          onBuzzerSetup: widget.onBuzzerSetup == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onBuzzerSetup!();
                },
        ),
      ),
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Top: teams
// ─────────────────────────────────────────────────────────────────────────────

class _TeamStrip extends StatelessWidget {
  const _TeamStrip({required this.state, required this.game, required this.onTeam, required this.onAdd});

  final SessionState state;
  final GameContent? game;
  final ValueChanged<String> onTeam;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: 68,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          for (final team in state.teams)
            Builder(
              builder: (context) {
                final position = state.buzzQueue.indexOf(team.id);
                final answering = position == 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: answering
                        ? scheme.primary
                        : position > 0
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onTeam(team.id),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 84),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        // The team's own colour as a stripe along the bottom.
                        decoration: teamColor(team) == null
                            ? null
                            : BoxDecoration(
                                border: Border(bottom: BorderSide(color: teamColor(team)!, width: 5)),
                              ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              position > 0 ? "${position + 1}. ${team.name}" : team.name,
                              style: theme.textTheme.labelMedium?.copyWith(color: answering ? scheme.onPrimary : null),
                            ),
                            Text(
                              team.points.toString(),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: answering ? scheme.onPrimary : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          IconButton.outlined(onPressed: onAdd, icon: const Icon(Icons.add), tooltip: context.l10n.addTeam),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Middle: what is happening now
// ─────────────────────────────────────────────────────────────────────────────

String _status(AppLocalizations l10n, SessionState state, Question? question) {
  String name(String id) => state.team(id)?.name ?? "?";
  switch (state.phase) {
    case Phase.buzzerTest:
      return state.buzzQueue.isEmpty ? l10n.buzzerTest : "${l10n.buzzerTest} · ${name(state.buzzQueue.first)}";
    case Phase.overview:
      return l10n.statusBoard;
    case Phase.question:
      if (state.betsShown) return l10n.statusBetsShown;
      if (state.placingBets) {
        final placed = state.teams.where((team) => state.betting!.bets.containsKey(team.id)).length;
        return l10n.statusBetting(placed, state.teams.length);
      }
      if (question?.type == QuestionType.rapidFire && state.revealed < 0) return l10n.statusRapidIntro;
      if (question?.rapidFire?.mode == RapidMode.devices) return l10n.statusRapidDevices;
      if (question?.rapidFire?.mode == RapidMode.whiteboard) return l10n.statusRapidWhiteboard;
      if (question?.amountBet != null) return l10n.statusAmountBet;
      return question?.buzzerable == false ? l10n.statusOpenNoBuzzers : l10n.statusOpenWaiting;
    case Phase.buzzered:
      final next = state.buzzQueue.skip(1).map(name).join(", ");
      return next.isEmpty ? l10n.statusAnswering(name(state.buzzQueue.first)) : l10n.statusAnsweringThen(name(state.buzzQueue.first), next);
    case Phase.answerRevealed:
      return l10n.statusAnswerRevealed;
  }
}

class _NowPanel extends StatelessWidget {
  const _NowPanel({
    required this.state,
    required this.game,
    required this.question,
    required this.send,
    required this.hostClock,
    this.backgroundImage,
  });

  /// The picture a whiteboard round is drawn on, if this device has it.
  final ImageProvider? backgroundImage;

  final SessionState state;
  final GameContent? game;
  final Question? question;
  final void Function(Command) send;

  /// This device runs the show, so its clock is the one deadlines are on.
  final bool hostClock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final q = question;
    final l10n = context.l10n;
    final status = Text(_status(l10n, state, q), style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary));
    if (game == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          status,
          const SizedBox(height: 24),
          Center(child: Text(l10n.noGamePicked, textAlign: TextAlign.center)),
        ],
      );
    }
    if (q == null) {
      final group = game!.group(state.groupId) ?? game!.groups.firstOrNull;
      final all = [
        for (final c in group?.categories ?? const <Category>[])
          for (final q in c.questions) QuestionRef(c.id, q.id),
      ];
      final played = all.where((ref) => state.played.contains(ref.key)).length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          status,
          const SizedBox(height: 24),
          Center(
            child: Text(
              all.isEmpty ? l10n.groupHasNoQuestions : l10n.questionsPlayed(played, all.length),
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      );
    }

    final muted = theme.textTheme.bodyLarge?.copyWith(color: scheme.outline);
    final round = state.answerRound;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        status,
        const SizedBox(height: 4),
        Text(
          q.betting
              ? "${l10n.questionType(q.type)} · ${l10n.teamsBetTheirPoints}"
              : q.amountBet != null
              ? "${l10n.questionType(q.type)} · ${l10n.teamsBetHowManyShort} · ${l10n.plusMinusEach(q.pointsPlus, q.pointsMinus)}"
              : "${l10n.questionType(q.type)} · +${q.pointsPlus} / −${q.pointsMinus}",
          style: theme.textTheme.labelMedium,
        ),
        if (q.amountBet != null && q.amountBet!.prompt.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.betQuestionShown(q.amountBet!.prompt), style: theme.textTheme.bodyMedium),
          ),
        if (state.betting != null) _BetsPanel(state: state, question: q, send: send),
        // The question's own clock, when the devices have none.
        if (state.timer case final timer? when timer.running && round == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: RoundCountdown(openedAt: timer.openedAtMillis, endsAt: timer.endsAtMillis, hostClock: hostClock),
          ),
        // A clock for any question, set up with one or not; the devices'
        // rounds have their own buttons for more time.
        if (round == null && !state.waitingForBets)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ActionChip(avatar: const Icon(Icons.more_time, size: 18), label: const Text("+30 s"), onPressed: () => send(const SetTimer(30))),
                ActionChip(avatar: const Icon(Icons.more_time, size: 18), label: const Text("+1 min"), onPressed: () => send(const SetTimer(60))),
                if (state.timer != null)
                  ActionChip(avatar: const Icon(Icons.timer_off_outlined, size: 18), label: Text(l10n.stopTimer), onPressed: () => send(const SetTimer(null))),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(q.text, style: theme.textTheme.titleMedium),
        if (q.answerHint != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Text(q.answerHint!, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onTertiaryContainer)),
          ),
        const SizedBox(height: 8),
        if (q.type == QuestionType.rapidFire) _RapidPanel(state: state, question: q, send: send),
        if (q.type == QuestionType.lastStanding) _StandingPanel(state: state, question: q, send: send),
        // Matching: the solution, as the big screen names the pieces.
        if (q.type == QuestionType.matching)
          Builder(
            builder: (context) {
              final matching = q.matching ?? const Matching();
              final numbers = matching.rightNumbers(q.id);
              // Ticked as the big screen puts each pair together.
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < matching.pairs.length; i++)
                      Row(
                        children: [
                          Icon(
                            i < state.revealed ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 18,
                            color: i < state.revealed ? scheme.primary : scheme.outline,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${l10n.deviceLabel(matching.leftLabel(i))}  →  ${l10n.deviceLabel(matching.rightLabel(i, numbers))}",
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        // Put in order: the solution, ticked off as the big screen places it.
        if (q.type == QuestionType.ordering) _OrderingPanel(state: state, question: q),
        if (q.type == QuestionType.topAnswers) _TopAnswersPanel(state: state, question: q, send: send),
        // Nothing on the devices: the gamemaster rates each team here.
        if (round == null && !state.waitingForBets && (q.ranked || q.amountBet != null || (q.noBuzzer && q.companion == null)))
          _ResultsPanel(state: state, question: q, send: send),
        // Notes of the teams given a notes field, as they write.
        if (state.notesTeams.isNotEmpty) _NotesPanel(state: state),
        if (round != null && q.type != QuestionType.rapidFire)
          _AnswersPanel(state: state, round: round, question: q, send: send, hostClock: hostClock, backgroundImage: backgroundImage),
        if (q.type == QuestionType.abcd)
          for (final (i, answer) in q.answers.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    q.answersCorrect.elementAtOrNull(i) == true ? Icons.check_circle : Icons.cancel_outlined,
                    size: 18,
                    color: q.answersCorrect.elementAtOrNull(i) == true ? Colors.green : scheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("${String.fromCharCode(0x41 + i)}  $answer", style: i < state.revealed ? theme.textTheme.bodyLarge : muted),
                  ),
                  if (i < state.revealed) Icon(Icons.visibility, size: 16, color: scheme.outline),
                ],
              ),
            ),
        if (q.type == QuestionType.progressingReveal) ...[
          for (final (i, information) in q.information.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text("${i + 1}. $information", style: i < state.revealed ? theme.textTheme.bodyLarge : muted)),
                  if (state.imageFocus == i + 1) Icon(Icons.zoom_in, size: 18, color: scheme.primary),
                  if (i < state.revealed) Icon(Icons.visibility, size: 16, color: scheme.outline),
                ],
              ),
            ),
          if (q.hasInformationImages)
            Row(
              children: [
                Text(l10n.enlargedImage),
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: state.imageFocus > 0 ? () => send(const ImageFocus(-1)) : null),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: state.imageFocus < state.revealed ? () => send(const ImageFocus(1)) : null,
                ),
              ],
            ),
        ],
        if (q.type == QuestionType.feud) ...[
          Row(
            children: [
              Text(state.wrongAttempts == 0 ? l10n.noStrikes : l10n.strikes, style: theme.textTheme.labelLarge),
              for (var i = 0; i < state.wrongAttempts; i++) Icon(Icons.close, color: scheme.error, size: 22),
              const Spacer(),
              TextButton(
                onPressed: state.phase == Phase.buzzered && state.wrongAttempts > 0 ? () => send(const FeudResetWrong()) : null,
                child: Text(l10n.resetStrikes),
              ),
            ],
          ),
          if (state.phase == Phase.question) Text(l10n.buzzBeforeUncover, style: muted),
          for (final (i, answer) in q.information.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Material(
                color: state.feudRevealed.contains(i) ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: state.phase == Phase.buzzered ? () => send(FeudToggle(i)) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(width: 56, child: Text(feudValueLabel(q, i), style: theme.textTheme.labelLarge)),
                        Expanded(child: Text(answer, style: theme.textTheme.bodyLarge)),
                        Icon(state.feudRevealed.contains(i) ? Icons.visibility : Icons.visibility_off_outlined, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// The bets of a question played with bets. While they are open the
/// gamemaster can enter or change any team's bet, for teams without a
/// device; afterwards they are only shown.
class _BetsPanel extends StatelessWidget {
  const _BetsPanel({required this.state, required this.question, required this.send});

  final SessionState state;
  final Question question;
  final void Function(Command) send;

  Future<void> _enter(BuildContext context, Team team) async {
    final limit = maxBet(team, question);
    final text = await promptText(
      context,
      title: context.l10n.betFor(team.name),
      initial: state.betting!.bets[team.id]?.toString() ?? '',
      label: context.l10n.betRange(limit),
    );
    final amount = text == null ? null : int.tryParse(text);
    if (amount != null) send(PlaceBet(team.id, amount));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final betting = state.betting!;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(betting.open ? context.l10n.betsTapTeam : context.l10n.bets, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final team in state.teams)
                if (betting.open)
                  ActionChip(
                    avatar: Icon(betting.bets.containsKey(team.id) ? Icons.check_circle : Icons.hourglass_empty, size: 18),
                    label: Text(
                      betting.bets.containsKey(team.id)
                          ? "${team.name} · ${betting.bets[team.id]}"
                          : "${team.name} · ${context.l10n.upTo(maxBet(team, question))}",
                    ),
                    onPressed: () => _enter(context, team),
                  )
                else
                  Chip(label: Text("${team.name} · ${betting.bets.containsKey(team.id) ? betting.bets[team.id] : context.l10n.noBet}")),
            ],
          ),
        ],
      ),
    );
  }
}



/// What the ratings so far are worth and the button that puts them on the
/// scoreboard. The same for every kind of question rated team by team.
class _GiveBar extends StatelessWidget {
  const _GiveBar({required this.state, required this.question, required this.send});

  final SessionState state;
  final Question question;
  final void Function(Command) send;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = pointsToGive(state, question);
    final rated =
        state.results.verdicts.isNotEmpty ||
        state.results.points.isNotEmpty ||
        state.results.order.isNotEmpty ||
        (question.byCloseness && closenessPlaces(state).isNotEmpty);
    if (!rated && state.results.given.isEmpty) return const SizedBox.shrink();
    final summary = [
      for (final team in state.teams)
        if (pending[team.id] case final delta?) "${team.name} ${signedPoints(delta)}",
    ].join(" · ");
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: pending.isEmpty
            ? OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.check),
                label: Text(context.l10n.allPointsGiven, style: theme.textTheme.labelLarge),
              )
            : FilledButton.icon(
                onPressed: () => send(const GivePoints()),
                icon: const Icon(Icons.emoji_events_outlined),
                // Named while it fits; with many teams the cards show who gets what.
                label: Text(
                  pending.length <= 4 ? "${context.l10n.givePoints} · $summary" : context.l10n.givePointsToTeams(pending.length),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
      ),
    );
  }
}

/// What a team is due for the open question: outlined while it still has to
/// be given, filled once it is on the scoreboard.
class _PointsChip extends StatelessWidget {
  const _PointsChip({required this.state, required this.question, required this.teamId});

  final SessionState state;
  final Question question;
  final String teamId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final due = pointsDue(state, question, teamId);
    final given = state.results.given[teamId] ?? 0;
    if (due == null && given == 0) return const SizedBox.shrink();
    final value = due ?? 0;
    final done = value == given;
    final color = value < 0 ? scheme.error : (value > 0 ? Colors.green.shade700 : scheme.outline);
    return Tooltip(
      message: done ? context.l10n.given : (given == 0 ? context.l10n.notGivenYet : context.l10n.givenSoFar(signedPoints(given))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: done ? color.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: done ? 1 : 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (done) ...[Icon(Icons.check, size: 14, color: color), const SizedBox(width: 2)],
            Text(
              signedPoints(value),
              style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// "By order": the team's place; tapping puts it next in order, or takes it
/// out again.
class _PlaceButton extends StatelessWidget {
  const _PlaceButton({required this.state, required this.question, required this.teamId, required this.send});

  final SessionState state;
  final Question question;
  final String teamId;
  final void Function(Command) send;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final set = state.results.order.contains(teamId);
    final place = rightInOrder(state).indexOf(teamId);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: set ? context.l10n.takeOutOfOrder : context.l10n.putNextInOrder,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => send(PlaceTeam(teamId)),
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 28),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: set ? scheme.primary : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: place >= 0 ? scheme.primary : scheme.outlineVariant, width: 1.5),
            ),
            child: place >= 0
                ? Text(
                    context.l10n.ordinal(place + 1),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: set ? scheme.onPrimary : scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Icon(Icons.format_list_numbered, size: 16, color: scheme.outline),
          ),
        ),
      ),
    );
  }
}

/// Rating team by team when nothing is on the devices: charades on stage,
/// push-ups for a bet, an answer called out. Each team has its place ("by
/// order"), right and wrong, and what that is worth; "Give points" puts it
/// on the scoreboard.
class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({required this.state, required this.question, required this.send});

  final SessionState state;
  final Question question;
  final void Function(Command) send;

  Future<void> _otherPoints(BuildContext context, Team team) async {
    final text = await promptText(
      context,
      title: context.l10n.pointsFor(team.name),
      initial: (pointsDue(state, question, team.id) ?? pointsIfRight(state, question, team.id)).toString(),
      label: context.l10n.pointsForQuestion,
    );
    final points = text == null ? null : int.tryParse(text);
    if (points != null) send(AwardAnswer(team.id, points));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final amount = question.amountBet != null;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            amount
                ? context.l10n.didTeamsReach
                : question.ranked
                ? context.l10n.tapInOrder(signedPoints(question.pointsPlus), question.rankStep ?? 0)
                : context.l10n.rateEachTeam,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          _GiveBar(state: state, question: question, send: send),
          for (final team in state.teams)
            Builder(
              builder: (context) {
                final verdict = state.results.verdicts[team.id];
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  color: scheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 2, 2),
                    child: Row(
                      children: [
                        if (question.ranked && state.results.verdicts[team.id] != false)
                          _PlaceButton(state: state, question: question, teamId: team.id, send: send),
                        Expanded(
                          child: Text(
                            amount ? "${team.name} · ${context.l10n.goal(state.betting?.betOf(team.id) ?? 0)}" : team.name,
                            style: theme.textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _PointsChip(state: state, question: question, teamId: team.id),
                        PopupMenuButton<String>(
                          tooltip: context.l10n.otherPoints,
                          icon: const Icon(Icons.exposure_outlined),
                          onSelected: (_) => _otherPoints(context, team),
                          itemBuilder: (context) => [PopupMenuItem(value: 'other', child: Text(context.l10n.otherPointsMenu))],
                        ),
                        // Tapping the chosen rating again takes it back.
                        IconButton(
                          tooltip: amount ? context.l10n.reached : context.l10n.rapidRight,
                          icon: Icon(verdict == true ? Icons.check_circle : Icons.check_circle_outline),
                          color: verdict == true ? Colors.green.shade700 : null,
                          onPressed: () => send(RateAnswer(team.id, correct: verdict == true ? null : true)),
                        ),
                        IconButton(
                          tooltip: amount ? context.l10n.missed : context.l10n.rapidWrong,
                          icon: Icon(verdict == false ? Icons.cancel : Icons.cancel_outlined),
                          color: verdict == false ? scheme.error : null,
                          onPressed: () => send(RateAnswer(team.id, correct: verdict == false ? null : false)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Last team standing: whose turn it is, the prompt with its answer, and
/// every team in turn order. Right and Wrong (out) are on the pad; the
/// free miss and taking a turn back are here.
class _StandingPanel extends StatelessWidget {
  const _StandingPanel({required this.state, required this.question, required this.send});

  final SessionState state;
  final Question question;
  final void Function(Command) send;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final play = state.standing;
    if (play == null) return const SizedBox.shrink();
    final setup = question.lastStanding ?? const LastStanding();
    final item = setup.itemAt(play.item);
    final current = play.current == null ? null : state.team(play.current!);
    final winner = play.winner == null ? null : state.team(play.winner!);
    final out = play.out;
    if (!play.started) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.standingIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => send(const StartTurns()),
              icon: const Icon(Icons.play_arrow),
              label: Text(context.l10n.startTurns),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: winner != null ? Colors.green.withValues(alpha: 0.15) : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                winner != null ? context.l10n.teamWins(winner.name, question.pointsPlus) : current != null ? context.l10n.teamsTurn(current.name) : context.l10n.nobodyLeft,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (winner == null && item != null) ...[
                const SizedBox(height: 6),
                Text("${play.item + 1}. ${item.question}", style: theme.textTheme.titleMedium),
                if (item.answer.isNotEmpty) Text(item.answer, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.primary)),
              ] else if (winner == null && setup.items.isNotEmpty)
                Text(context.l10n.noPromptsLeft, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: play.current == null ? null : () => send(const TakeTurn(StandingResult.miss)),
                icon: const Icon(Icons.replay),
                label: Text(context.l10n.standingResult(StandingResult.miss)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: play.turns.isEmpty ? null : () => send(const UndoTurn()),
              icon: const Icon(Icons.undo),
              label: Text(context.l10n.undo),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final id in play.order)
              if (state.team(id) case final team?)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    out.contains(id) ? Icons.close : (id == play.current ? Icons.play_arrow : (id == play.winner ? Icons.emoji_events : Icons.person_outline)),
                    size: 18,
                    color: out.contains(id) ? scheme.error : scheme.primary,
                  ),
                  label: Text(
                    out.contains(id) ? "${team.name} · ${context.l10n.outPlace(out.indexOf(id) + 1)}" : team.name,
                    style: out.contains(id) ? TextStyle(color: scheme.outline, decoration: TextDecoration.lineThrough) : null,
                  ),
                  backgroundColor: id == play.current ? scheme.primaryContainer : null,
                ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Fragenhagel: every item with its answer for the gamemaster, the one being
/// asked highlighted; in devices mode what each team has picked for it.
class _RapidPanel extends StatelessWidget {
  const _RapidPanel({required this.state, required this.question, required this.send});

  final SessionState state;
  final Question question;
  final void Function(Command) send;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rapid = question.rapidFire ?? const RapidFire();
    final devices = rapid.mode == RapidMode.devices;
    final whiteboard = rapid.mode == RapidMode.whiteboard;
    final round = state.answerRound;
    if (rapid.items.isEmpty) return Text(context.l10n.rapidNoItems, style: TextStyle(color: scheme.outline));
    final answering = state.phase == Phase.buzzered && state.buzzQueue.isNotEmpty ? state.team(state.buzzQueue.first) : null;
    final current = rapid.itemAt(state.revealed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Who buzzed, big, with the answer to check right next to it.
        if (answering != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Icon(Icons.notifications_active, color: scheme.onPrimary, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        answering.name,
                        style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w800),
                      ),
                      if (current != null && current.answer.isNotEmpty)
                        Text(context.l10n.answerShown(current.answer), style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onPrimary)),
                      if (current != null && current.hint.isNotEmpty)
                        Text(context.l10n.hintShown(current.hint), style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Text(
          state.revealed < 0
              ? context.l10n.rapidIntro
              : state.revealed >= rapid.items.length
              ? context.l10n.allDone(rapid.items.length)
              : context.l10n.itemOf(state.revealed + 1, rapid.items.length),
          style: theme.textTheme.labelLarge,
        ),
        for (final (i, item) in rapid.items.indexed)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: i == state.revealed ? scheme.primaryContainer : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(width: 28, child: Text("${i + 1}.", style: theme.textTheme.labelLarge)),
                    Expanded(
                      child: Text(
                        item.question,
                        style: i < state.revealed ? theme.textTheme.bodyMedium?.copyWith(color: scheme.outline) : theme.textTheme.bodyLarge,
                      ),
                    ),
                    if (item.image != null) Icon(Icons.image_outlined, size: 16, color: scheme.outline),
                    if (item.music != null) Icon(Icons.music_note, size: 16, color: scheme.outline),
                    if (i < state.revealed) Icon(Icons.check, size: 16, color: scheme.outline),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    devices ? (item.isTrue ? context.l10n.rapidRight : context.l10n.rapidWrong) : item.answer,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: devices ? (item.isTrue ? Colors.green.shade700 : scheme.error) : null,
                    ),
                  ),
                ),
                if (item.hint.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Text(
                      context.l10n.hintShown(item.hint),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                if (devices && i == state.revealed && round != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 28, top: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final team in state.teams)
                          Builder(
                            builder: (context) {
                              final answer = round.answers[team.id];
                              final choice = answer?.choice;
                              return Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(answer?.locked == true ? Icons.lock : Icons.lock_open, size: 16),
                                label: Text("${team.name}: ${choice == null ? "–" : context.l10n.rapidChoice(rapidChoices.elementAtOrNull(choice) ?? "?")}"),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                if (whiteboard && i == state.revealed && round != null)
                  _RapidBoards(state: state, round: round, send: send),
              ],
            ),
          ),
      ],
    );
  }
}

/// Whiteboard Fragenhagel: each team's drawing for the item being asked, to
/// rate right or wrong and to put on the big screen.
class _RapidBoards extends StatelessWidget {
  const _RapidBoards({required this.state, required this.round, required this.send});

  final SessionState state;
  final AnswerRound round;
  final void Function(Command) send;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (round.open)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.lock_outline, size: 18),
                label: Text(context.l10n.lockAll),
                onPressed: () => send(const LockAnswers()),
              ),
            ),
          for (final team in state.roundTeams)
            Builder(
              builder: (context) {
                final answer = round.answers[team.id];
                final shown = round.revealed.contains(team.id);
                final verdict = state.results.verdicts[team.id];
                return Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
                  decoration: BoxDecoration(
                    color: shown ? scheme.secondaryContainer : scheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Row(
                          children: [
                            Icon(answer?.locked == true || !round.open ? Icons.lock : Icons.lock_open, size: 14, color: scheme.outline),
                            const SizedBox(width: 4),
                            Expanded(child: Text(team.name, style: theme.textTheme.labelLarge, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 96),
                            child: AnswerView(spec: round.spec, answer: answer, fontSize: 14),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: shown ? context.l10n.takeOffScreen : context.l10n.showOnScreen,
                        icon: Icon(shown ? Icons.visibility : Icons.visibility_outlined),
                        color: shown ? scheme.primary : null,
                        onPressed: () => send(RevealAnswer(team.id, show: !shown)),
                      ),
                      IconButton(
                        tooltip: context.l10n.rapidRight,
                        icon: Icon(verdict == true ? Icons.check_circle : Icons.check_circle_outline),
                        color: verdict == true ? Colors.green : null,
                        onPressed: () => send(RateAnswer(team.id, correct: verdict == true ? null : true)),
                      ),
                      IconButton(
                        tooltip: context.l10n.rapidWrong,
                        icon: Icon(verdict == false ? Icons.cancel : Icons.cancel_outlined),
                        color: verdict == false ? scheme.error : null,
                        onPressed: () => send(RateAnswer(team.id, correct: verdict == false ? null : false)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Top answers: the list, to uncover answers on the big screen. With
/// buzzers, tapping the answer the team named gives it the points; on the
/// devices, who found what is ticked per team further down.
class _TopAnswersPanel extends StatelessWidget {
  const _TopAnswersPanel({required this.state, required this.question, required this.send});

  final SessionState state;
  final Question question;
  final void Function(Command) send;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = question.topAnswers ?? const TopAnswers();
    if (top.items.isEmpty) return Text(context.l10n.topAnswersEmpty, style: TextStyle(color: scheme.outline));
    final answering = !top.onDevices && state.phase == Phase.buzzered && state.buzzQueue.isNotEmpty
        ? state.team(state.buzzQueue.first)
        : null;
    final round = state.answerRound;
    final hint = top.onDevices
        ? context.l10n.topTapToUncover
        : answering != null
        ? context.l10n.topTapNamed(answering.name)
        : context.l10n.topWhenBuzz;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(hint, style: theme.textTheme.bodyMedium?.copyWith(color: answering != null ? scheme.primary : scheme.outline)),
          const SizedBox(height: 4),
          for (final (i, item) in top.items.indexed)
            Builder(
              builder: (context) {
                final shown = state.feudRevealed.contains(i);
                final finder = state.foundBy[i] == null ? null : state.team(state.foundBy[i]!);
                final finders = [
                  for (final team in state.teams)
                    if (round?.found[team.id]?.contains(i) == true) team.name,
                ];
                final who = finder?.name ?? (finders.isEmpty ? null : finders.join(", "));
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Material(
                    color: shown ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => send(TopAnswerToggle(i)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(width: 28, child: Text("${i + 1}.", style: theme.textTheme.labelLarge)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.answer, style: theme.textTheme.bodyLarge),
                                  if (who != null) Text(who, style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary)),
                                ],
                              ),
                            ),
                            Text("+${top.pointsOf(i, question.pointsPlus)}", style: theme.textTheme.labelLarge),
                            const SizedBox(width: 8),
                            Icon(shown ? Icons.visibility : Icons.visibility_off_outlined, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

String feudValueLabel(Question question, int index) {
  final value = question.percentages.elementAtOrNull(index) ?? 0;
  final text = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  return question.absoluteValues ? text : "$text%";
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom: the action pad. Seven buttons, always in the same place.
// ─────────────────────────────────────────────────────────────────────────────

class _ActionPad extends StatelessWidget {
  const _ActionPad({required this.state, required this.game, required this.question, required this.send});

  final SessionState state;
  final GameContent? game;
  final Question? question;
  final void Function(Command) send;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = question;
    final answering = state.phase == Phase.buzzered && state.buzzQueue.isNotEmpty;
    final listening = state.phase == Phase.question || state.phase == Phase.buzzered;
    final feud = q?.type == QuestionType.feud;
    final steal = feud && answering && state.wrongAttempts >= 3;
    // Last team standing: Right and Wrong rate the turn; Wrong puts the team out.
    final turn = q?.type == QuestionType.lastStanding && state.standing?.current != null;

    // Top row: the verdict, and closing the question.
    // Top answers: a right answer is the one tapped on the list.
    final Command? right = turn
        ? const TakeTurn(StandingResult.right)
        : !answering || q == null || q.type == QuestionType.topAnswers
        ? null
        : feud
        ? (steal ? const FeudSteal(success: true) : null)
        : const Judge(correct: true);
    final Command? wrong = turn
        ? const TakeTurn(StandingResult.out)
        : !answering || q == null
        ? null
        : feud
        ? (steal ? const FeudSteal(success: false) : const FeudWrong())
        : const Judge(correct: false);
    final Command? close = state.current == null ? null : const CloseQuestion();

    // Second row: stepping through the question.
    // For a question with steps of its own these walk through them;
    // otherwise they show the teams' answers one by one.
    final canReveal = q != null && q.maxReveal > 0 && state.current != null;
    final round = state.answerRound;
    // Put in order and matching: answering closes first, then the entries
    // go in place (the pairs together) one by one, then the teams' answers
    // come up.
    final ordering = q?.type == QuestionType.ordering || q?.type == QuestionType.matching;
    final placing = ordering && canReveal && state.revealed < q.maxReveal;
    final answerSteps = round != null && (!canReveal || (ordering && !placing));
    final rapid = q?.type == QuestionType.rapidFire;
    // A Fragenhagel goes back as far as its question alone (-1), taking back
    // what was scored on the way.
    final Command? back = answerSteps && round.revealed.isNotEmpty
        ? RevealAnswer(round.revealed.last, show: false)
        : answerSteps && !ordering
        ? null
        : canReveal && state.revealed > (rapid ? -1 : 0)
        ? const Reveal(-1)
        : null;
    // Showing answers starts by closing the answering on every device, so
    // the gamemaster can then show them in any order.
    final closeFirst = (answerSteps && round.open && round.revealed.isEmpty) || (placing && round != null && round.open);
    // While bets are placed this button ends the betting, then starts the
    // question once the bets have been shown.
    final betting = state.waitingForBets;
    // Last team standing: the question is read out first, then Next starts the turns.
    final startTurns = q?.type == QuestionType.lastStanding && state.standing?.started == false;
    final Command? next = betting
        ? (state.placingBets ? const CloseBets() : const StartQuestion())
        : startTurns
        ? const StartTurns()
        : closeFirst
        ? const LockAnswers()
        : answerSteps
        ? (state.roundTeams.any((team) => !round.revealed.contains(team.id)) ? const RevealNextAnswer() : null)
        : canReveal && state.revealed < q.maxReveal
        ? const Reveal(1)
        : null;
    final playing = state.media == MediaPlayback.playing;
    final Command? sound = q != null && q.musicAt(state.revealed) != null && listening
        ? SetMedia(playing ? MediaPlayback.paused : MediaPlayback.playing)
        : null;
    final queued = state.buzzQueue.length > 1;
    final Command? pass = !answering ? null : (queued ? const SkipBuzzer() : const ReopenQuestion());

    Widget big(String label, IconData icon, Command? command, Color color, Color onColor) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          height: 60,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: onColor,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: command == null ? null : () => send(command),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
    // Revealing a Connections group while teams still play gives it away to
    // them, so that one asks first.
    final revealEarly = q?.type == QuestionType.connections && next is Reveal && round != null && round.open;
    Future<bool> askReveal() => confirm(
      context,
      title: context.l10n.revealGroupNow,
      message: context.l10n.revealGroupNowText,
      action: context.l10n.reveal,
    );
    Widget small(String label, IconData icon, Command? command, {Future<bool> Function()? ask}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          height: 52,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: command == null
                ? null
                : () async {
                    if (ask != null && !await ask()) return;
                    send(command);
                  },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              big(steal ? context.l10n.stealWorked : context.l10n.rapidRight, Icons.check, right, Colors.green.shade700, Colors.white),
              big(steal ? context.l10n.stealFailed : (feud ? context.l10n.strike : context.l10n.rapidWrong), Icons.close, wrong, scheme.error, scheme.onError),
              big(context.l10n.close, Icons.close_fullscreen, close, scheme.secondaryContainer, scheme.onSecondaryContainer),
            ],
          ),
          Row(
            children: [
              small(rapid ? context.l10n.back : context.l10n.hide, Icons.navigate_before, back),
              small(
                betting
                    ? (state.placingBets ? context.l10n.betsAreIn : context.l10n.startQuestion)
                    : closeFirst
                    ? context.l10n.lockAll
                    : answerSteps
                    ? context.l10n.showAnswer
                    : rapid
                    ? (state.revealed < 0
                          ? context.l10n.firstItem
                          : state.revealed >= q!.maxReveal - 1
                          ? context.l10n.finish
                          : context.l10n.nextItem)
                    : q?.type == QuestionType.abcd && state.revealed == q!.answers.length
                    ? context.l10n.solution
                    : q?.type == QuestionType.connections
                    ? context.l10n.revealGroup
                    : placing
                    ? (q.type == QuestionType.matching ? context.l10n.nextPair : context.l10n.placeNext)
                    : context.l10n.reveal,
                Icons.navigate_next,
                next,
                ask: revealEarly ? askReveal : null,
              ),
              small(playing ? context.l10n.pause : context.l10n.play, playing ? Icons.pause : Icons.play_arrow, sound),
              small(queued ? context.l10n.nextTeam : context.l10n.reopen, queued ? Icons.skip_next : Icons.undo, pass),
            ],
          ),
        ],
      ),
    );
  }
}

/// Put in order on the controller: the right order with what each entry is
/// sorted by, the ones on the big screen already ticked.
class _OrderingPanel extends StatelessWidget {
  const _OrderingPanel({required this.state, required this.question});

  final SessionState state;
  final Question question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = (question.ordering ?? const Ordering()).items;
    final spec = question.companion;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.rightOrder, style: theme.textTheme.labelLarge),
          for (final (i, item) in items.indexed)
            Row(
              children: [
                Icon(
                  i < state.revealed ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: i < state.revealed ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${i + 1}. ${context.l10n.deviceLabel(spec?.options.elementAtOrNull(i) ?? item.text)}"
                    "${item.value.trim().isEmpty ? '' : '  ·  ${item.value.trim()}'}",
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.boardSuggested,
    required this.answersActive,
    required this.effectsActive,
    required this.onBoard,
    required this.onEffects,
    required this.onAnswers,
    required this.onScript,
    required this.onSetup,
  });

  /// Nothing is open: picking a question is the next thing to do.
  final bool boardSuggested;
  final bool answersActive;

  /// Music is playing or a card is on screen.
  final bool effectsActive;
  final VoidCallback onBoard;
  final VoidCallback onEffects;
  final VoidCallback onAnswers;
  final VoidCallback onScript;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tab(String label, IconData icon, VoidCallback onTap, {bool highlight = false, bool dot = false}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          height: 48,
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: highlight ? scheme.primary : null,
              foregroundColor: highlight ? scheme.onPrimary : null,
              padding: EdgeInsets.zero,
            ),
            onPressed: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(isLabelVisible: dot, smallSize: 8, child: Icon(icon, size: 20)),
                // One line, smaller if need be: five tabs share a phone's width.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 12))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        children: [
          tab(context.l10n.tabBoard, Icons.grid_view_rounded, onBoard, highlight: boardSuggested),
          tab(context.l10n.tabEffects, Icons.auto_awesome_outlined, onEffects, dot: effectsActive),
          tab(context.l10n.tabAnswers, Icons.draw_outlined, onAnswers, dot: answersActive),
          tab(context.l10n.script, Icons.description_outlined, onScript),
          tab(context.l10n.tabSetup, Icons.settings_outlined, onSetup),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheets
// ─────────────────────────────────────────────────────────────────────────────

/// The board: tap a field to read the question, then open it.
class _BoardSheet extends StatefulWidget {
  const _BoardSheet({required this.state, required this.game, required this.send});

  final SessionState state;
  final GameContent game;
  final void Function(Command) send;

  @override
  State<_BoardSheet> createState() => _BoardSheetState();
}

class _BoardSheetState extends State<_BoardSheet> {
  QuestionRef? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = widget.state;
    final game = widget.game;
    final group = game.group(state.groupId) ?? game.groups.firstOrNull;
    final selected = _selected;
    final question = selected == null ? null : game.question(selected);
    final played = selected != null && state.played.contains(selected.key);
    final open = selected != null && state.current == selected;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (game.groups.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: [
                  for (final g in game.groups)
                    ButtonSegment(value: g.id, icon: Icon(g.type.icon), label: Text(g.isUngrouped ? context.l10n.ungrouped : g.name)),
                ],
                selected: {?group?.id},
                emptySelectionAllowed: true,
                // The board cannot change under an open question.
                onSelectionChanged: state.current != null
                    ? null
                    : (ids) {
                        setState(() => _selected = null);
                        if (ids.isNotEmpty) widget.send(SelectGroup(ids.first));
                      },
              ),
            ),
          const SizedBox(height: 8),
          if (group == null || group.categories.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text(context.l10n.groupHasNoCategories)),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.42),
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final category in group.categories)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // On a map wider than the screen a tap brings the
                              // category to the middle; a question in play
                              // keeps its own there.
                              Builder(
                                builder: (context) {
                                  final turnable = group.type == BoardType.map && state.current == null;
                                  final focused = group.type == BoardType.map && state.boardFocus == category.id;
                                  final label = Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Text(
                                      category.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: focused ? scheme.primary : null,
                                        fontWeight: focused ? FontWeight.w700 : null,
                                      ),
                                    ),
                                  );
                                  if (!turnable) return label;
                                  return Tooltip(
                                    message: context.l10n.showCategoryInMiddle,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => widget.send(FocusCategory(category.id)),
                                      child: label,
                                    ),
                                  );
                                },
                              ),
                              for (final q in category.questions)
                                Builder(
                                  builder: (context) {
                                    final ref = QuestionRef(category.id, q.id);
                                    final isOpen = state.current == ref;
                                    final isPlayed = state.played.contains(ref.key);
                                    final isSelected = _selected == ref;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.all(4),
                                          minimumSize: const Size(0, 40),
                                          side: isSelected ? BorderSide(color: scheme.primary, width: 2) : null,
                                          backgroundColor: isOpen
                                              ? scheme.primary
                                              : isPlayed
                                              ? scheme.surfaceContainerLow
                                              : scheme.surfaceContainerHighest,
                                          foregroundColor: isOpen
                                              ? scheme.onPrimary
                                              : isPlayed
                                              ? scheme.outline
                                              : scheme.onSurface,
                                        ),
                                        onPressed: () => setState(() => _selected = ref),
                                        child: Text(q.boardPoints.toString()),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          // The preview keeps its height, so the button below never jumps. It
          // takes a good part of the screen: a question with a hint is long.
          Container(
            height: (MediaQuery.sizeOf(context).height * 0.24).clamp(140.0, 260.0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
            child: question == null
                ? Center(
                    child: Text(context.l10n.tapFieldToRead, style: TextStyle(color: scheme.outline)),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${context.l10n.questionType(question.type)} · +${question.pointsPlus} / −${question.pointsMinus}"
                          "${open
                              ? " · ${context.l10n.onScreen}"
                              : played
                              ? " · ${context.l10n.played}"
                              : ""}",
                          style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary),
                        ),
                        const SizedBox(height: 4),
                        Text(question.text, style: theme.textTheme.bodyLarge),
                        if (question.answerHint != null)
                          Text(question.answerHint!, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: selected == null || question == null
                  ? null
                  : () {
                      if (open) {
                        // Opened by mistake: back to the board, still playable.
                        widget.send(const CloseQuestion(markPlayed: false));
                      } else if (played) {
                        widget.send(UnmarkPlayed(selected));
                      } else {
                        widget.send(OpenQuestion(selected));
                        Navigator.of(context).pop();
                      }
                    },
              icon: Icon(
                open
                    ? Icons.undo
                    : played
                    ? Icons.replay
                    : Icons.play_arrow,
              ),
              label: Text(
                open
                    ? context.l10n.takeOffKeepPlayable
                    : played
                    ? context.l10n.markNotPlayed
                    : context.l10n.openQuestion,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _slotName(AppLocalizations l10n, String slot) => switch (slot) {
  musicBackground => l10n.slotBoard,
  musicCalm => l10n.slotCalm,
  _ => l10n.slotThrilling,
};

String? _effectName(AppLocalizations l10n, String key) => switch (key) {
  effectAnswerCorrect => l10n.rapidRight,
  effectAnswerWrong => l10n.rapidWrong,
  effectAnswerClosed => l10n.effectClosed,
  effectReveal => l10n.reveal,
  effectQuestionOpen => l10n.question,
  effectLockIn => l10n.effectLockedIn,
  effectNextItem => l10n.nextItem,
  effectCountdown => l10n.effectCountdown,
  effectTimesUp => l10n.effectTimesUp,
  effectSteal => l10n.effectSteal,
  effectFanfare => l10n.effectFanfare,
  _ => null,
};

/// Everything for the eyes and ears that is not part of a question: cards
/// and animations over the screen, music, sound effects.
class _EffectsSheet extends StatefulWidget {
  const _EffectsSheet({required this.state, required this.game, required this.send});

  final SessionState state;
  final GameContent? game;
  final void Function(Command) send;

  @override
  State<_EffectsSheet> createState() => _EffectsSheetState();
}

class _EffectsSheetState extends State<_EffectsSheet> {
  final TextEditingController _text = TextEditingController();

  /// The music volume while the slider is being dragged.
  int? _volume;

  bool _awakeDetails = false;

  /// The noise picked last, for switching back on.
  String? _lastAmbience;

  /// The noise's volume while its slider is being dragged.
  int? _ambienceVolume;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final game = widget.game;
    final send = widget.send;
    final sounds = game?.soundsFor(ref: state.current, groupId: state.groupId) ?? MusicConfig.empty;
    final question = state.current == null ? null : game?.question(state.current!);
    final listening = state.phase == Phase.question || state.phase == Phase.buzzered;
    final cards = game?.cardsFor(ref: state.current, groupId: state.groupId) ?? const <CueCard>[];
    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: header(context.l10n.onScreenHeader)),
              // Kept with the session: every card comes on this way until it is changed.
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DropdownMenu<CardAnimation>(
                  key: const ValueKey('card-animation'),
                  label: Text(context.l10n.animation),
                  width: 210,
                  initialSelection: state.cardAnimation,
                  dropdownMenuEntries: [
                    for (final animation in CardAnimation.values) DropdownMenuEntry(value: animation, label: context.l10n.cardAnimation(animation)),
                  ],
                  onSelected: (animation) {
                    if (animation != null) send(SetCardAnimation(animation));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Every card the editor prepared, pictures that come with the app
          // included: those of the open question's category and board first.
          if (cards.isEmpty)
            Text(context.l10n.noCardsPrepare)
          else
            SizedBox(
              height: 76,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final card in cards)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _CardTile(
                        gameId: game!.id,
                        card: card,
                        onScreen: _isOnScreen(state.overlay, card),
                        onTap: () => send(
                          ShowCard(
                            OverlayCard(
                              title: card.title.isEmpty ? null : card.title,
                              text: card.text.isEmpty ? null : card.text,
                              image: card.image,
                              video: card.video,
                              style: card.style,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.celebration_outlined, size: 18),
                label: Text(context.l10n.confetti),
                onPressed: () => send(const ScreenEffect(screenEffectConfetti)),
              ),
              ActionChip(
                avatar: const Icon(Icons.flash_on_outlined, size: 18),
                label: Text(context.l10n.flash),
                onPressed: () => send(const ScreenEffect(screenEffectFlash)),
              ),
              ActionChip(
                avatar: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(context.l10n.fireworks),
                onPressed: () => send(const ScreenEffect(screenEffectFireworks)),
              ),
              ActionChip(
                avatar: const Icon(Icons.bubble_chart_outlined, size: 18),
                label: Text(context.l10n.balloons),
                onPressed: () => send(const ScreenEffect(screenEffectBalloons)),
              ),
              ActionChip(
                avatar: const Icon(Icons.star_outline, size: 18),
                label: Text(context.l10n.stars),
                onPressed: () => send(const ScreenEffect(screenEffectStars)),
              ),
              ActionChip(
                avatar: const Icon(Icons.highlight_outlined, size: 18),
                label: Text(context.l10n.spotlight),
                onPressed: () => send(const ScreenEffect(screenEffectSpotlight)),
              ),
              ActionChip(
                avatar: const Icon(Icons.fast_forward_outlined, size: 18),
                label: Text(context.l10n.fastForward),
                onPressed: () => send(const ScreenEffect(screenEffectFastForward)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  decoration: InputDecoration(labelText: context.l10n.textToShow, isDense: true),
                  onSubmitted: (text) => send(ShowCard(OverlayCard(text: text.trim()))),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => send(ShowCard(OverlayCard(text: _text.text.trim()))),
                child: Text(context.l10n.show),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.overlay == null ? null : () => send(const HideCard()),
              icon: const Icon(Icons.visibility_off_outlined),
              label: Text(state.overlay == null ? context.l10n.noCardOnScreen : context.l10n.takeCardOff),
            ),
          ),
          header(context.l10n.music),

          Wrap(
            spacing: 8,
            children: [
              for (final slot in musicSlots)
                FilterChip(
                  label: Text(_slotName(context.l10n, slot)),
                  selected: state.music == slot,
                  onSelected: (on) => send(SetMusic(on ? slot : null)),
                ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.volume_down, color: theme.colorScheme.onSurfaceVariant),
              Expanded(
                child: Slider(
                  value: (_volume ?? state.musicVolume).toDouble(),
                  max: 100,
                  divisions: 20,
                  label: "${(_volume ?? state.musicVolume).round()} %",
                  // Follows the finger here; the big screen gets the value when let go.
                  onChanged: (value) => setState(() => _volume = value.round()),
                  onChangeEnd: (value) {
                    send(SetMusicVolume(value.round()));
                    setState(() => _volume = null);
                  },
                ),
              ),
              Icon(Icons.volume_up, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 8),
          // On by default; the details are a tap away for whoever wonders.
          Material(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(context.l10n.keepSpeakersAwake),
                  secondary: IconButton(
                    icon: Icon(_awakeDetails ? Icons.expand_less : Icons.expand_more),
                    tooltip: _awakeDetails ? context.l10n.fewerDetails : context.l10n.whatIsThis,
                    onPressed: () => setState(() => _awakeDetails = !_awakeDetails),
                  ),
                  value: state.ambience != null,
                  onChanged: (on) => send(SetAmbience(on ? (_lastAmbience ?? ambienceSoftNoise) : null)),
                ),
                if (_awakeDetails)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.keepSpeakersAwakeText,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(value: ambienceSoftNoise, label: Text(context.l10n.softNoise)),
                            ButtonSegment(value: ambienceWhiteNoise, label: Text(context.l10n.whiteNoise)),
                          ],
                          selected: {state.ambience ?? _lastAmbience ?? ambienceSoftNoise},
                          onSelectionChanged: (selected) {
                            setState(() => _lastAmbience = selected.first);
                            send(SetAmbience(selected.first));
                          },
                        ),
                        Row(
                          children: [
                            Icon(Icons.volume_down, color: theme.colorScheme.onSurfaceVariant),
                            Expanded(
                              child: Slider(
                                value: (_ambienceVolume ?? state.ambienceVolume).toDouble(),
                                max: 100,
                                divisions: 20,
                                label: context.l10n.noiseVolume((_ambienceVolume ?? state.ambienceVolume).round()),
                                // Follows the finger here; the big screen gets the value when let go.
                                onChanged: (value) => setState(() => _ambienceVolume = value.round()),
                                onChangeEnd: (value) {
                                  send(SetAmbienceVolume(value.round()));
                                  setState(() => _ambienceVolume = null);
                                },
                              ),
                            ),
                            Icon(Icons.volume_up, color: theme.colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          header(context.l10n.soundEffects),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Come with the app, in every game.
              for (final sound in handSounds)
                ActionChip(
                  avatar: const Icon(Icons.graphic_eq, size: 18),
                  label: Text(sound.label),
                  onPressed: () => send(PlayEffect(sound.key)),
                ),
              for (final key in sounds.effects.keys)
                ActionChip(
                  avatar: const Icon(Icons.volume_up_outlined, size: 18),
                  label: Text(_effectName(context.l10n, key) ?? key),
                  onPressed: () => send(PlayEffect(key)),
                ),
            ],
          ),
          if (question != null && question.hasMusic) ...[
            header(context.l10n.questionSound),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.play_arrow, size: 18),
                  label: Text(context.l10n.play),
                  onPressed: listening && state.media != MediaPlayback.playing ? () => send(const SetMedia(MediaPlayback.playing)) : null,
                ),
                ActionChip(
                  avatar: const Icon(Icons.pause, size: 18),
                  label: Text(context.l10n.pause),
                  onPressed: state.media == MediaPlayback.playing ? () => send(const SetMedia(MediaPlayback.paused)) : null,
                ),
                ActionChip(
                  avatar: const Icon(Icons.stop, size: 18),
                  label: Text(context.l10n.stop),
                  onPressed: state.media != MediaPlayback.stopped ? () => send(const SetMedia(MediaPlayback.stopped)) : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

bool _isOnScreen(OverlayCard? overlay, CueCard card) =>
    overlay != null &&
    (overlay.title ?? '') == card.title &&
    (overlay.text ?? '') == card.text &&
    overlay.image == card.image &&
    overlay.video == card.video &&
    overlay.style == card.style;

/// One card to put on screen: its picture, or an icon for text and video,
/// with its title over it.
class _CardTile extends StatelessWidget {
  const _CardTile({required this.gameId, required this.card, required this.onScreen, required this.onTap});

  final String gameId;
  final CueCard card;
  final bool onScreen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final builtin = builtinImage(card.image);
    final label = card.title.isNotEmpty ? card.title : (card.text.isNotEmpty ? card.text : null);
    return Tooltip(
      message: label ?? (builtin == null ? null : context.l10n.builtinImage(builtin)) ?? (card.video != null ? context.l10n.video : context.l10n.picture),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 128,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(width: 3, color: onScreen ? scheme.primary : Colors.transparent),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CardThumbnail(gameId: gameId, image: card.image, video: card.video, width: 128),
              if (label != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Starting and steering an answer round. The answers themselves are in
/// the middle of the controller, where they can be read and rated.
class _AnswersSheet extends StatefulWidget {
  const _AnswersSheet({required this.state, required this.game, required this.send});

  final SessionState state;
  final GameContent? game;
  final void Function(Command) send;

  @override
  State<_AnswersSheet> createState() => _AnswersSheetState();
}

class _AnswersSheetState extends State<_AnswersSheet> {
  int? _timer;

  /// Teams left out of the next round, e.g. all but the two last-placed.
  final Set<String> _left = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final state = widget.state;
    final send = widget.send;
    final round = state.answerRound;
    final question = state.current == null ? null : widget.game?.question(state.current!);
    Widget action(String label, IconData icon, VoidCallback? onPressed) => Padding(
      padding: const EdgeInsets.only(right: 8, top: 8),
      child: FilledButton.tonalIcon(onPressed: onPressed, icon: Icon(icon), label: Text(label)),
    );
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );
    // A chip per team with its points, so the last-placed are easy to find.
    Widget teamChips(bool Function(Team team) selected, void Function(Team team, bool on) onSelected) => Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final team in state.teams)
          FilterChip(
            label: Text("${team.name} · ${team.points}"),
            selected: selected(team),
            onSelected: (on) => onSelected(team, on),
          ),
      ],
    );

    final chosen = [for (final team in state.teams) if (!_left.contains(team.id)) team.id];
    void open(CompanionKind kind) {
      send(OpenAnswers(CompanionSpec(kind: kind, timerSeconds: _timer), teams: chosen.length == state.teams.length ? const [] : chosen));
      Navigator.of(context).pop();
    }

    final canOpen = chosen.isNotEmpty;
    final automatic = round == null || question == null ? const <Command>[] : autoRating(state, round, question);
    final estimates = round == null || question == null || round.spec.solution == null ? const <EstimateScoring>[] : EstimateScoring.values;
    final answering = state.roundTeams;
    final unlimited = round != null && round.open && round.endsAtMillis == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.answersOnDevices, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          if (state.current == null)
            Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(l10n.openAQuestionFirst))
          else if (round == null) ...[
            Text(l10n.answersOnDevicesText),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.timer),
                for (final seconds in [null, 20, 30, 60, 120])
                  ChoiceChip(
                    label: Text(seconds == null ? l10n.none : "$seconds s"),
                    selected: _timer == seconds,
                    onSelected: (_) => setState(() => _timer = seconds),
                  ),
              ],
            ),
            heading(l10n.whoAnswers),
            teamChips((team) => !_left.contains(team.id), (team, on) => setState(() => on ? _left.remove(team.id) : _left.add(team.id))),
            Wrap(
              children: [
                action(l10n.companionKind(CompanionKind.whiteboard), Icons.draw_outlined, canOpen ? () => open(CompanionKind.whiteboard) : null),
                action(l10n.companionKind(CompanionKind.text), Icons.short_text, canOpen ? () => open(CompanionKind.text) : null),
                action(l10n.companionKind(CompanionKind.number), Icons.pin_outlined, canOpen ? () => open(CompanionKind.number) : null),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.preparedScreensText, style: theme.textTheme.bodySmall),
          ] else ...[
            Text(
              "${l10n.companionKind(round.kind)} · ${round.open ? l10n.roundOpen : l10n.roundLocked} · "
              "${l10n.answersIn(round.answers.entries.where((a) => !a.value.isEmpty && round.takesPart(a.key)).length, answering.length)}",
            ),
            Wrap(
              children: [
                if (round.open)
                  action(l10n.lockAll, Icons.lock_outline, () => send(const LockAnswers()))
                else
                  action(l10n.letThemEditAgain, Icons.lock_open, () => send(const UnlockAnswers())),
                action(
                  l10n.showAll,
                  Icons.tv,
                  answering.every((team) => round.revealed.contains(team.id)) ? null : () => send(const RevealAnswers()),
                ),
                if (automatic.isNotEmpty) action(l10n.rateAutomatically, Icons.auto_fix_high, () => automatic.forEach(send)),
                for (final scoring in estimates)
                  action(l10n.estimateScoring(scoring), Icons.adjust, () => estimateRating(state, round, question!, scoring).forEach(send)),
                if (round.kind == CompanionKind.connections)
                  action(l10n.givePointsForGroups, Icons.emoji_events_outlined, () => send(const AwardConnections())),
                action(l10n.discard, Icons.delete_outline, () => send(const ClearAnswers())),
              ],
            ),
            // More time, also after it ran out: that opens the round again.
            heading(l10n.moreTime),
            Wrap(
              children: [
                // A round running without a limit has all the time already;
                // +30 s would put a limit on it instead.
                action("+30 s", Icons.more_time, unlimited ? null : () => send(const ExtendAnswers(30))),
                action("+1 min", Icons.more_time, unlimited ? null : () => send(const ExtendAnswers(60))),
                action(
                  l10n.noTimeLimit,
                  Icons.all_inclusive,
                  unlimited ? null : () => send(const ExtendAnswers(null)),
                ),
              ],
            ),
            heading(l10n.whoAnswers),
            teamChips(
              (team) => round.takesPart(team.id),
              (team, on) => send(
                SetRoundTeams([
                  for (final other in answering)
                    if (other.id != team.id) other.id,
                  if (on) team.id,
                ]),
              ),
            ),
          ],
          // Notes: a field of their own on chosen teams' devices, whatever
          // else they answer, e.g. estimates for a bonus.
          if (state.current != null) ...[
            heading(l10n.notes),
            Text(l10n.notesText, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            teamChips(
              (team) => state.notesTeams.contains(team.id),
              (team, on) => send(
                AllowNotes([
                  for (final id in state.notesTeams)
                    if (id != team.id) id,
                  if (on) team.id,
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the teams with a notes field have written, e.g. bonus estimates.
class _NotesPanel extends StatelessWidget {
  const _NotesPanel({required this.state});

  final SessionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sticky_note_2_outlined, size: 18, color: theme.colorScheme.onTertiaryContainer),
                const SizedBox(width: 6),
                Text(context.l10n.notes, style: theme.textTheme.labelLarge),
              ],
            ),
            for (final id in state.notesTeams)
              if (state.team(id) case final team?)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SelectableText.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: "${team.name}:  ", style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: (state.notes[id] ?? '').trim().isEmpty ? "–" : state.notes[id]!.trim()),
                      ],
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// The teams' answers as they come in, for the gamemaster to read, show and
/// rate. Lives in the middle of the controller for as long as a round runs.
class _AnswersPanel extends StatelessWidget {
  const _AnswersPanel({
    required this.state,
    required this.round,
    required this.question,
    required this.send,
    required this.hostClock,
    this.backgroundImage,
  });

  final ImageProvider? backgroundImage;

  final SessionState state;
  final AnswerRound round;
  final Question question;
  final void Function(Command) send;
  final bool hostClock;

  Future<void> _customPoints(BuildContext context, Team team) async {
    final text = await promptText(
      context,
      title: context.l10n.pointsFor(team.name),
      initial: (pointsDue(state, question, team.id) ?? pointsIfRight(state, question, team.id)).toString(),
      label: context.l10n.pointsForAnswer,
    );
    final points = text == null ? null : int.tryParse(text);
    if (points != null) send(AwardAnswer(team.id, points));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spec = round.spec;
    final closest = closestTeams(spec, round.answers);
    // Matching and put in order show the solution above already.
    final ownSolution = question.type == QuestionType.matching || question.type == QuestionType.ordering;
    final solution = ownSolution ? null : switch (spec.kind) {
      CompanionKind.number || CompanionKind.slider => spec.solution == null ? null : formatNumber(spec.solution!, unit: spec.unit),
      CompanionKind.order => spec.options.map(context.l10n.deviceLabel).join("  →  "),
      CompanionKind.match => [
        for (final (i, left) in spec.options.indexed) "${context.l10n.deviceLabel(left)} → ${context.l10n.deviceLabel(spec.targets.elementAtOrNull(i) ?? "?")}",
      ].join(" · "),
      CompanionKind.connections => [for (final group in spec.groups) group.name].join(" · "),
      _ => null,
    };
    final connections = spec.kind == CompanionKind.connections;
    final top = question.type == QuestionType.topAnswers ? question.topAnswers : null;
    final automatic = autoRating(state, round, question);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (automatic.isNotEmpty || (spec.solution != null && !question.byCloseness))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (automatic.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.auto_fix_high, size: 18),
                    label: Text(context.l10n.rateAutomatically),
                    onPressed: () => automatic.forEach(send),
                  ),
                // By closeness the places give the points already.
                if (spec.solution != null && !question.byCloseness)
                  for (final scoring in EstimateScoring.values)
                    ActionChip(
                      avatar: const Icon(Icons.adjust, size: 18),
                      label: Text(context.l10n.estimateScoring(scoring)),
                      onPressed: () => estimateRating(state, round, question, scoring).forEach(send),
                    ),
              ],
            ),
          ),
        if (!connections) _GiveBar(state: state, question: question, send: send),
        if (round.open && round.endsAtMillis != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RoundCountdown(openedAt: round.openedAtMillis, endsAt: round.endsAtMillis!, hostClock: hostClock),
          ),
        if (solution != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(context.l10n.solutionShown(solution), style: theme.textTheme.labelLarge),
          ),
        for (final team in state.roundTeams)
          Builder(
            builder: (context) {
              final answer = round.answers[team.id];
              final shown = round.revealed.contains(team.id);
              final verdict = state.results.verdicts[team.id];
              final partial = partialScore(spec, answer);
              final place = question.byCloseness ? closenessPlaces(state)[team.id] : null;
              final suggestion = connections || top != null || partial != null || question.byCloseness
                  ? null
                  : autoVerdict(spec, answer, choiceCorrect: question.answersCorrect) ?? (closest.contains(team.id) ? true : null);
              final found = foundBy(round, team.id);
              final suggested = top == null ? const <int?>[] : suggestionsFor(question, answer);
              final took = answer?.secondsTaken(round);
              final half = (pointsIfRight(state, question, team.id) / 2).round();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: shown ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            answer?.locked == true
                                ? Icons.lock
                                : (answer == null || answer.isEmpty)
                                ? Icons.hourglass_empty
                                : Icons.edit_outlined,
                            size: 16,
                            color: scheme.outline,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${team.name}${shown ? " · ${context.l10n.onScreen}" : ""}"
                              "${took == null ? "" : " · ${took.toStringAsFixed(1)} s"}",
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                          if (question.ranked && state.results.verdicts[team.id] != false)
                            _PlaceButton(state: state, question: question, teamId: team.id, send: send),
                          _PointsChip(state: state, question: question, teamId: team.id),
                          const SizedBox(width: 8),
                          // What rating automatically would make of it.
                          if (verdict == null && place != null)
                            Text(context.l10n.placeN(context.l10n.ordinal(place + 1)), style: theme.textTheme.labelMedium?.copyWith(color: scheme.outline)),
                          if (verdict == null && (partial != null || suggestion != null))
                            Text(
                              partial != null
                                  ? switch (spec.orderScoring) {
                                      _ when spec.kind != CompanionKind.order => context.l10n.partialRight(partial.right, partial.of),
                                      OrderScoring.exact => partial.right == partial.of ? context.l10n.looksRight : context.l10n.looksWrong,
                                      OrderScoring.pairs => context.l10n.partialPairs(partial.right, partial.of),
                                      OrderScoring.places => context.l10n.partialRight(partial.right, partial.of),
                                    }
                                  : (suggestion! ? context.l10n.looksRight : context.l10n.looksWrong),
                              style: theme.textTheme.labelMedium?.copyWith(color: scheme.outline),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // The answer on the left, and always the same four
                      // buttons in the same square on the right.
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 132),
                                // Long answers (ten pairs, a long list) scroll
                                // inside the card; a drawing is fitted instead.
                                child: spec.kind == CompanionKind.whiteboard
                                    ? AnswerView(spec: spec, answer: answer, fontSize: 16, backgroundImage: backgroundImage)
                                    : SingleChildScrollView(
                                        primary: false,
                                        child: AnswerView(spec: spec, answer: answer, fontSize: 16, backgroundImage: backgroundImage),
                                      ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 96,
                            child: Wrap(
                              children: [
                                IconButton(
                                  tooltip: shown ? context.l10n.takeOffScreen : context.l10n.showOnScreen,
                                  icon: Icon(shown ? Icons.visibility : Icons.visibility_outlined),
                                  color: shown ? scheme.primary : null,
                                  onPressed: () => send(RevealAnswer(team.id, show: !shown)),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: context.l10n.otherPoints,
                                  icon: const Icon(Icons.exposure_outlined),
                                  onSelected: (choice) =>
                                      choice == 'half' ? send(AwardAnswer(team.id, half)) : _customPoints(context, team),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(value: 'half', child: Text(context.l10n.halfPoints(half))),
                                    PopupMenuItem(value: 'other', child: Text(context.l10n.otherPointsMenu)),
                                  ],
                                ),
                                IconButton(
                                  tooltip: context.l10n.rapidRight,
                                  icon: Icon(verdict == true ? Icons.check_circle : Icons.check_circle_outline),
                                  color: verdict == true ? Colors.green : null,
                                  onPressed: () => send(RateAnswer(team.id, correct: verdict == true ? null : true)),
                                ),
                                IconButton(
                                  tooltip: context.l10n.rapidWrong,
                                  icon: Icon(verdict == false ? Icons.cancel : Icons.cancel_outlined),
                                  color: verdict == false ? scheme.error : null,
                                  onPressed: () => send(RateAnswer(team.id, correct: verdict == false ? null : false)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Top answers: tick what the team found; its points
                      // follow. Lines it typed that look like one are marked.
                      if (top != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final (i, item) in top.items.indexed)
                                FilterChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: !found.contains(i) && suggested.contains(i) ? const Icon(Icons.auto_awesome, size: 16) : null,
                                  label: Text("${i + 1}. ${item.answer}"),
                                  selected: found.contains(i),
                                  onSelected: (_) => send(MarkTopAnswers(team.id, toggled(found, i))),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        if (connections)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FilledButton.icon(
              onPressed: () => send(const AwardConnections()),
              icon: const Icon(Icons.emoji_events_outlined),
              label: Text(
                "${context.l10n.givePoints}: "
                "${[for (final team in state.teams) "${team.name} ${connectionsPoints(question.pointsPlus, round.answers[team.id]?.connections)}"].join(", ")}",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}
