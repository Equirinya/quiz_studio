import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/companion/answer_view.dart';
import 'package:quiz_show/features/games/pages/game_editor_page.dart' show BoardTypeIcon;
import 'package:quiz_show/features/games/widgets/cards_dialog.dart' show CardThumbnail;
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/features/session/widgets/team_colors.dart';
import 'package:quiz_show/game/game.dart';

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
              onSetup: _openSetup,
            ),
          ],
        );
      },
    );
  }

  // ── teams ──────────────────────────────────────────────────────────────────

  Future<void> _addTeam() async {
    final name = await promptText(context, title: "New team", label: "Name");
    if (name != null) _send(AddTeam(newTeamId(), name));
  }

  void _openTeam(String teamId) {
    _sheet((context, state, game) {
      final team = state.team(teamId);
      if (team == null) return const SizedBox(height: 80, child: Center(child: Text("This team was removed.")));
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
                label: const Text("Buzz for this team"),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () async {
                    final name = await promptText(context, title: "Rename team", initial: team.name, label: "Name");
                    if (name != null) _send(RenameTeam(team.id, name));
                  },
                  child: const Text("Rename"),
                ),
                TextButton(
                  onPressed: () async {
                    final text = await promptText(context, title: "Set points", initial: team.points.toString(), label: "Points");
                    final points = text == null ? null : int.tryParse(text);
                    if (points != null) _send(SetPoints(team.id, points));
                  },
                  child: const Text("Set points"),
                ),
                TextButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final sure = await confirm(
                      context,
                      title: "Remove team",
                      message: "${team.name} and its points are removed.",
                      action: "Remove",
                    );
                    if (!sure) return;
                    _send(RemoveTeam(team.id));
                    navigator.pop();
                  },
                  child: const Text("Remove"),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  // ── sheets ─────────────────────────────────────────────────────────────────

  void _openBoard() => _sheet((context, state, game) => game == null
      ? const SizedBox(height: 120, child: Center(child: Text("This session has no game yet.")))
      : _BoardSheet(state: state, game: game, send: _send));

  void _openEffects() => _sheet((context, state, game) => _EffectsSheet(state: state, game: game, send: _send));

  void _openAnswers() => _sheet((context, state, game) => _AnswersSheet(state: state, game: game, send: _send));

  void _openSetup() => _sheet((context, state, game) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Queue buzzers"),
                subtitle: const Text("Later buzzes line up behind the first"),
                value: state.queueBuzzers,
                onChanged: (value) => _send(SetQueueBuzzers(value)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Buzzer test"),
                subtitle: const Text("Buzzers light up their team; only from the board"),
                value: state.phase == Phase.buzzerTest,
                onChanged: state.phase == Phase.overview || state.phase == Phase.buzzerTest
                    ? (value) => _send(SetBuzzerTest(value))
                    : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.group_add_outlined),
                title: const Text("Add team"),
                onTap: _addTeam,
              ),
              if (widget.onConnectDevices != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.qr_code_2),
                  title: const Text("Connect devices"),
                  subtitle: const Text("Phones as buzzers, or another controller"),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onConnectDevices!();
                  },
                ),
              if (widget.onBuzzerSetup != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.usb),
                  title: const Text("Buzzers"),
                  subtitle: const Text("USB buzzer box, and a sound per team"),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onBuzzerSetup!();
                  },
                ),
            ],
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
            Builder(builder: (context) {
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
                          : BoxDecoration(border: Border(bottom: BorderSide(color: teamColor(team)!, width: 5))),
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
            }),
          IconButton.outlined(onPressed: onAdd, icon: const Icon(Icons.add), tooltip: "Add team"),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Middle: what is happening now
// ─────────────────────────────────────────────────────────────────────────────

String _status(SessionState state, Question? question) {
  String name(String id) => state.team(id)?.name ?? "?";
  switch (state.phase) {
    case Phase.buzzerTest:
      return state.buzzQueue.isEmpty ? "Buzzer test" : "Buzzer test · ${name(state.buzzQueue.first)}";
    case Phase.overview:
      return "Board";
    case Phase.question:
      if (question?.rapidFire?.mode == RapidMode.devices) return "Teams pick right or wrong on their devices";
      return question?.buzzerable == false ? "Question open · no buzzers" : "Question open · waiting for a buzz";
    case Phase.buzzered:
      final next = state.buzzQueue.skip(1).map(name).join(", ");
      return "${name(state.buzzQueue.first)} is answering${next.isEmpty ? "" : " · then $next"}";
    case Phase.answerRevealed:
      return "Answer revealed";
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
    final status = Text(
      _status(state, q),
      style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
    );
    if (game == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [status, const SizedBox(height: 24), const Center(child: Text("No game picked yet. Choose one for this session in the sessions list.", textAlign: TextAlign.center))],
      );
    }
    if (q == null) {
      final group = game!.group(state.groupId) ?? game!.groups.firstOrNull;
      final all = [for (final c in group?.categories ?? const <Category>[]) for (final q in c.questions) QuestionRef(c.id, q.id)];
      final played = all.where((ref) => state.played.contains(ref.key)).length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          status,
          const SizedBox(height: 24),
          Center(
            child: Text(
              all.isEmpty ? "This group has no questions." : "$played of ${all.length} questions played",
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
        Text("${q.type.uiString} · +${q.pointsPlus} / −${q.pointsMinus}", style: theme.textTheme.labelMedium),
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
        if (q.type == QuestionType.rapidFire) _RapidPanel(state: state, question: q),
        // Matching: the solution, as the big screen names the pieces.
        if (q.type == QuestionType.matching)
          Builder(builder: (context) {
            final matching = q.matching ?? const Matching();
            final numbers = matching.rightNumbers(q.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < matching.pairs.length; i++)
                    Text("${matching.leftLabel(i)}  →  ${matching.rightLabel(i, numbers)}", style: theme.textTheme.bodyMedium),
                ],
              ),
            );
          }),
        if (q.type == QuestionType.topAnswers) _TopAnswersPanel(state: state, question: q, send: send),
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
                    child: Text(
                      "${String.fromCharCode(0x41 + i)}  $answer",
                      style: i < state.revealed ? theme.textTheme.bodyLarge : muted,
                    ),
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
                  Expanded(
                    child: Text("${i + 1}. $information", style: i < state.revealed ? theme.textTheme.bodyLarge : muted),
                  ),
                  if (state.imageFocus == i + 1) Icon(Icons.zoom_in, size: 18, color: scheme.primary),
                  if (i < state.revealed) Icon(Icons.visibility, size: 16, color: scheme.outline),
                ],
              ),
            ),
          if (q.hasInformationImages)
            Row(
              children: [
                const Text("Enlarged image"),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: state.imageFocus > 0 ? () => send(const ImageFocus(-1)) : null,
                ),
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
              Text(state.wrongAttempts == 0 ? "No strikes" : "Strikes", style: theme.textTheme.labelLarge),
              for (var i = 0; i < state.wrongAttempts; i++) Icon(Icons.close, color: scheme.error, size: 22),
              const Spacer(),
              TextButton(
                onPressed: state.phase == Phase.buzzered && state.wrongAttempts > 0 ? () => send(const FeudResetWrong()) : null,
                child: const Text("Reset strikes"),
              ),
            ],
          ),
          if (state.phase == Phase.question) Text("A team has to buzz before answers can be uncovered.", style: muted),
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

/// Fragenhagel: every item with its answer for the gamemaster, the one being
/// asked highlighted; in devices mode what each team has picked for it.
class _RapidPanel extends StatelessWidget {
  const _RapidPanel({required this.state, required this.question});

  final SessionState state;
  final Question question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rapid = question.rapidFire ?? const RapidFire();
    final devices = rapid.mode == RapidMode.devices;
    final round = state.answerRound;
    if (rapid.items.isEmpty) return Text("This Fragenhagel has no items yet.", style: TextStyle(color: scheme.outline));
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
                        Text("Answer: ${current.answer}", style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Text(
          state.revealed >= rapid.items.length ? "All ${rapid.items.length} done" : "Item ${state.revealed + 1} of ${rapid.items.length}",
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
                    devices ? (item.isTrue ? "Right" : "Wrong") : item.answer,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: devices ? (item.isTrue ? Colors.green.shade700 : scheme.error) : null,
                    ),
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
                          Builder(builder: (context) {
                            final answer = round.answers[team.id];
                            final choice = answer?.choice;
                            return Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: Icon(answer?.locked == true ? Icons.lock : Icons.lock_open, size: 16),
                              label: Text(
                                "${team.name}: ${choice == null ? "–" : rapidChoices.elementAtOrNull(choice) ?? "?"}",
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
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
    if (top.items.isEmpty) return Text("This question has no answers on its list yet.", style: TextStyle(color: scheme.outline));
    final answering = !top.onDevices && state.phase == Phase.buzzered && state.buzzQueue.isNotEmpty ? state.team(state.buzzQueue.first) : null;
    final round = state.answerRound;
    final hint = top.onDevices
        ? "Tap an answer to uncover it on the big screen."
        : answering != null
            ? "Tap the answer ${answering.name} named. Wrong if it is not on the list."
            : "When a team buzzes, tap the answer it names.";
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(hint, style: theme.textTheme.bodyMedium?.copyWith(color: answering != null ? scheme.primary : scheme.outline)),
          const SizedBox(height: 4),
          for (final (i, item) in top.items.indexed)
            Builder(builder: (context) {
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
            }),
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

    // Top row: the verdict, and closing the question.
    // Top answers: a right answer is the one tapped on the list.
    final Command? right = !answering || q == null || q.type == QuestionType.topAnswers
        ? null
        : feud
            ? (steal ? const FeudSteal(success: true) : null)
            : const Judge(correct: true);
    final Command? wrong = !answering || q == null
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
    final answerSteps = !canReveal && round != null;
    final rapid = q?.type == QuestionType.rapidFire;
    // On the devices an item is scored when moving on, so there is no way back.
    final rapidBackLocked = rapid && q!.rapidFire?.mode == RapidMode.devices;
    final Command? back = answerSteps
        ? (round.revealed.isEmpty ? null : RevealAnswer(round.revealed.last, show: false))
        : canReveal && state.revealed > 0 && !rapidBackLocked
            ? const Reveal(-1)
            : null;
    final Command? next = answerSteps
        ? (state.teams.any((team) => !round.revealed.contains(team.id)) ? const RevealNextAnswer() : null)
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
                  children: [Icon(icon), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)],
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
          title: "Reveal a group now?",
          message: "The teams are still playing and will see this group on their devices too. Their time keeps running.",
          action: "Reveal",
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
              big(steal ? "Steal worked" : "Right", Icons.check, right, Colors.green.shade700, Colors.white),
              big(
                steal ? "Steal failed" : (feud ? "Strike" : "Wrong"),
                Icons.close,
                wrong,
                scheme.error,
                scheme.onError,
              ),
              big("Close", Icons.close_fullscreen, close, scheme.secondaryContainer, scheme.onSecondaryContainer),
            ],
          ),
          Row(
            children: [
              small("Hide", Icons.navigate_before, back),
              small(
                answerSteps
                    ? "Show answer"
                    : rapid
                        ? (state.revealed >= q!.maxReveal - 1 ? "Finish" : "Next item")
                        : q?.type == QuestionType.abcd && state.revealed == q!.answers.length
                            ? "Solution"
                            : q?.type == QuestionType.connections
                                ? "Reveal group"
                                : "Reveal",
                Icons.navigate_next,
                next,
                ask: revealEarly ? askReveal : null,
              ),
              small(playing ? "Pause" : "Play", playing ? Icons.pause : Icons.play_arrow, sound),
              small(queued ? "Next team" : "Reopen", queued ? Icons.skip_next : Icons.undo, pass),
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
                    Text(label, style: const TextStyle(fontSize: 12)),
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
          tab("Board", Icons.grid_view_rounded, onBoard, highlight: boardSuggested),
          tab("Effects", Icons.auto_awesome_outlined, onEffects, dot: effectsActive),
          tab("Answers", Icons.draw_outlined, onAnswers, dot: answersActive),
          tab("Setup", Icons.settings_outlined, onSetup),
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
                    ButtonSegment(value: g.id, icon: Icon(g.type.icon), label: Text(g.isUngrouped ? "Ungrouped" : g.name)),
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
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text("This group has no categories.")))
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
                              Builder(builder: (context) {
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
                                  message: "Show this category in the middle",
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => widget.send(FocusCategory(category.id)),
                                    child: label,
                                  ),
                                );
                              }),
                              for (final q in category.questions)
                                Builder(builder: (context) {
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
                                      child: Text(q.pointsPlus.toString()),
                                    ),
                                  );
                                }),
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
                ? Center(child: Text("Tap a field to read its question.", style: TextStyle(color: scheme.outline)))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${question.type.uiString} · +${question.pointsPlus} / −${question.pointsMinus}"
                          "${open ? " · on screen" : played ? " · played" : ""}",
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
              icon: Icon(open ? Icons.undo : played ? Icons.replay : Icons.play_arrow),
              label: Text(open
                  ? "Take off screen, keep playable"
                  : played
                      ? "Mark as not played"
                      : "Open question"),
            ),
          ),
        ],
      ),
    );
  }
}

const Map<String, String> _slotNames = {musicBackground: "Board", musicCalm: "Calm", musicExciting: "Thrilling"};

const Map<String, String> _effectNames = {
  effectAnswerCorrect: "Right",
  effectAnswerWrong: "Wrong",
  effectAnswerClosed: "Closed",
  effectReveal: "Reveal",
  effectQuestionOpen: "Question",
  effectLockIn: "Locked in",
  effectNextItem: "Next item",
  effectCountdown: "Countdown",
  effectTimesUp: "Time's up",
  effectSteal: "Steal",
  effectFanfare: "Fanfare",
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
              Expanded(child: header("On screen")),
              // Kept with the session: every card comes on this way until it is changed.
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DropdownMenu<CardAnimation>(
                  key: const ValueKey('card-animation'),
                  label: const Text("Animation"),
                  width: 210,
                  initialSelection: state.cardAnimation,
                  dropdownMenuEntries: [
                    for (final animation in CardAnimation.values)
                      DropdownMenuEntry(value: animation, label: animation.uiString),
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
            const Text("No cards. Prepare some in the editor.")
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
                        onTap: () => send(ShowCard(OverlayCard(
                          title: card.title.isEmpty ? null : card.title,
                          text: card.text.isEmpty ? null : card.text,
                          image: card.image,
                          video: card.video,
                          style: card.style,
                        ))),
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
                label: const Text("Confetti"),
                onPressed: () => send(const ScreenEffect(screenEffectConfetti)),
              ),
              ActionChip(
                avatar: const Icon(Icons.flash_on_outlined, size: 18),
                label: const Text("Flash"),
                onPressed: () => send(const ScreenEffect(screenEffectFlash)),
              ),
              ActionChip(
                avatar: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text("Fireworks"),
                onPressed: () => send(const ScreenEffect(screenEffectFireworks)),
              ),
              ActionChip(
                avatar: const Icon(Icons.bubble_chart_outlined, size: 18),
                label: const Text("Balloons"),
                onPressed: () => send(const ScreenEffect(screenEffectBalloons)),
              ),
              ActionChip(
                avatar: const Icon(Icons.star_outline, size: 18),
                label: const Text("Stars"),
                onPressed: () => send(const ScreenEffect(screenEffectStars)),
              ),
              ActionChip(
                avatar: const Icon(Icons.highlight_outlined, size: 18),
                label: const Text("Spotlight"),
                onPressed: () => send(const ScreenEffect(screenEffectSpotlight)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  decoration: const InputDecoration(labelText: "Text to show", isDense: true),
                  onSubmitted: (text) => send(ShowCard(OverlayCard(text: text.trim()))),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => send(ShowCard(OverlayCard(text: _text.text.trim()))),
                child: const Text("Show"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.overlay == null ? null : () => send(const HideCard()),
              icon: const Icon(Icons.visibility_off_outlined),
              label: Text(state.overlay == null ? "No card on screen" : "Take card off screen"),
            ),
          ),
          header("Music"),

          Wrap(
            spacing: 8,
            children: [
              for (final slot in musicSlots)
                  FilterChip(
                    label: Text(_slotNames[slot]!),
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
                  title: const Text("Keep speakers awake"),
                  secondary: IconButton(
                    icon: Icon(_awakeDetails ? Icons.expand_less : Icons.expand_more),
                    tooltip: _awakeDetails ? "Fewer details" : "What is this?",
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
                          "Many speakers switch themselves off after a few minutes of silence and miss the start of the next sound. "
                          "This plays a very quiet noise whenever nothing else plays; music and question sounds take over as they start.",
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: ambienceSoftNoise, label: Text("Soft noise")),
                            ButtonSegment(value: ambienceWhiteNoise, label: Text("White noise")),
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
                                label: "Noise ${(_ambienceVolume ?? state.ambienceVolume).round()} %",
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
          header("Sound effects"),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Come with the app, in every game.
              for (final sound in builtinSounds.where((s) => handSoundMoments.contains(s.id.split('/').first)))
                ActionChip(
                  avatar: const Icon(Icons.graphic_eq, size: 18),
                  label: Text(sound.label),
                  onPressed: () => send(PlayEffect(sound.key)),
                ),
              for (final key in sounds.effects.keys)
                ActionChip(
                  avatar: const Icon(Icons.volume_up_outlined, size: 18),
                  label: Text(_effectNames[key] ?? key),
                  onPressed: () => send(PlayEffect(key)),
                ),
            ],
          ),
          if (question != null && question.hasMusic) ...[
            header("Question sound"),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.play_arrow, size: 18),
                  label: const Text("Play"),
                  onPressed: listening && state.media != MediaPlayback.playing ? () => send(const SetMedia(MediaPlayback.playing)) : null,
                ),
                ActionChip(
                  avatar: const Icon(Icons.pause, size: 18),
                  label: const Text("Pause"),
                  onPressed: state.media == MediaPlayback.playing ? () => send(const SetMedia(MediaPlayback.paused)) : null,
                ),
                ActionChip(
                  avatar: const Icon(Icons.stop, size: 18),
                  label: const Text("Stop"),
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
      message: label ?? builtin?.label ?? (card.video != null ? "Video" : "Picture"),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final send = widget.send;
    final round = state.answerRound;
    final question = state.current == null ? null : widget.game?.question(state.current!);
    Widget action(String label, IconData icon, VoidCallback? onPressed) => Padding(
          padding: const EdgeInsets.only(right: 8, top: 8),
          child: FilledButton.tonalIcon(onPressed: onPressed, icon: Icon(icon), label: Text(label)),
        );
    void open(CompanionKind kind) {
      send(OpenAnswers(CompanionSpec(kind: kind, timerSeconds: _timer)));
      Navigator.of(context).pop();
    }

    final automatic = round == null || question == null ? const <Command>[] : autoRating(state, round, question);
    final estimates = round == null || question == null || round.spec.solution == null
        ? const <EstimateScoring>[]
        : EstimateScoring.values;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Answers on the teams' devices", style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          if (state.current == null)
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text("Open a question first."))
          else if (round == null) ...[
            const Text("Every team answers on its own device. You see the answers as they come in; the audience only when you show them."),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text("Timer"),
                for (final seconds in [null, 20, 30, 60, 120])
                  ChoiceChip(
                    label: Text(seconds == null ? "None" : "$seconds s"),
                    selected: _timer == seconds,
                    onSelected: (_) => setState(() => _timer = seconds),
                  ),
              ],
            ),
            Wrap(
              children: [
                action("Whiteboard", Icons.draw_outlined, () => open(CompanionKind.whiteboard)),
                action("Text", Icons.short_text, () => open(CompanionKind.text)),
                action("Number", Icons.pin_outlined, () => open(CompanionKind.number)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Sliders, sorting, matching and prepared whiteboards are set up per question in the editor and start by themselves.",
              style: theme.textTheme.bodySmall,
            ),
          ] else ...[
            Text(
              "${round.kind.uiString} · ${round.open ? "open" : "locked"} · "
              "${round.answers.values.where((a) => !a.isEmpty).length} of ${state.teams.length} in",
            ),
            Wrap(
              children: [
                if (round.open)
                  action("Lock all", Icons.lock_outline, () => send(const LockAnswers()))
                else
                  action("Let them edit again", Icons.lock_open, () => send(const UnlockAnswers())),
                action(
                  "Show all",
                  Icons.tv,
                  state.teams.every((team) => round.revealed.contains(team.id)) ? null : () => send(const RevealAnswers()),
                ),
                if (automatic.isNotEmpty) action("Rate automatically", Icons.auto_fix_high, () => automatic.forEach(send)),
                for (final scoring in estimates)
                  action(scoring.uiString, Icons.adjust, () => estimateRating(round, question!, scoring).forEach(send)),
                if (round.kind == CompanionKind.connections)
                  action("Give points for groups", Icons.emoji_events_outlined, () => send(const AwardConnections())),
                action("Discard", Icons.delete_outline, () => send(const ClearAnswers())),
              ],
            ),
          ],
        ],
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
      title: "Points for ${team.name}",
      initial: (round.awarded[team.id] ?? question.pointsPlus).toString(),
      label: "Points for this answer",
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
    final solution = switch (spec.kind) {
      CompanionKind.number || CompanionKind.slider => spec.solution == null ? null : formatNumber(spec.solution!, unit: spec.unit),
      CompanionKind.order => spec.options.join("  →  "),
      CompanionKind.match => [for (final (i, left) in spec.options.indexed) "$left → ${spec.targets.elementAtOrNull(i) ?? "?"}"].join(" · "),
      CompanionKind.connections => [for (final group in spec.groups) group.name].join(" · "),
      _ => null,
    };
    final connections = spec.kind == CompanionKind.connections;
    final top = question.type == QuestionType.topAnswers ? question.topAnswers : null;
    final automatic = autoRating(state, round, question);
    final half = (question.pointsPlus / 2).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (automatic.isNotEmpty || spec.solution != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (automatic.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text("Rate automatically"),
                    onPressed: () => automatic.forEach(send),
                  ),
                if (spec.solution != null)
                  for (final scoring in EstimateScoring.values)
                    ActionChip(
                      avatar: const Icon(Icons.adjust, size: 18),
                      label: Text(scoring.uiString),
                      onPressed: () => estimateRating(round, question, scoring).forEach(send),
                    ),
              ],
            ),
          ),
        if (round.open && round.endsAtMillis != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RoundCountdown(openedAt: round.openedAtMillis, endsAt: round.endsAtMillis!, hostClock: hostClock),
          ),
        if (solution != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text("Solution: $solution", style: theme.textTheme.labelLarge),
          ),
        for (final team in state.teams)
          Builder(builder: (context) {
            final answer = round.answers[team.id];
            final shown = round.revealed.contains(team.id);
            final verdict = round.verdicts[team.id];
            final partial = partialScore(spec, answer);
            final suggestion = connections || top != null || partial != null
                ? null
                : autoVerdict(spec, answer, choiceCorrect: question.answersCorrect) ?? (closest.contains(team.id) ? true : null);
            final found = foundBy(round, team.id);
            final suggested = top == null ? const <int?>[] : suggestionsFor(question, answer);
            final awarded = round.awarded[team.id];
            final took = answer?.secondsTaken(round);
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
                            "${team.name}${shown ? " · on screen" : ""}"
                            "${took == null ? "" : " · ${took.toStringAsFixed(1)} s"}"
                            "${awarded == null ? "" : " · ${awarded >= 0 ? "+" : ""}$awarded"}",
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        // What rating automatically would make of it.
                        if (verdict == null && (partial != null || suggestion != null))
                          Text(
                            partial != null ? "${partial.right} of ${partial.of} right" : (suggestion! ? "Looks right" : "Looks wrong"),
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
                              child: AnswerView(spec: spec, answer: answer, fontSize: 16, backgroundImage: backgroundImage),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 96,
                          child: Wrap(
                            children: [
                              IconButton(
                                tooltip: shown ? "Take off screen" : "Show on screen",
                                icon: Icon(shown ? Icons.visibility : Icons.visibility_outlined),
                                color: shown ? scheme.primary : null,
                                onPressed: () => send(RevealAnswer(team.id, show: !shown)),
                              ),
                              PopupMenuButton<String>(
                                tooltip: "Other points",
                                icon: const Icon(Icons.exposure_outlined),
                                onSelected: (choice) =>
                                    choice == 'half' ? send(AwardAnswer(team.id, half)) : _customPoints(context, team),
                                itemBuilder: (context) => [
                                  PopupMenuItem(value: 'half', child: Text("Half points (+$half)")),
                                  const PopupMenuItem(value: 'other', child: Text("Other points…")),
                                ],
                              ),
                              IconButton(
                                tooltip: "Right",
                                icon: Icon(verdict == true ? Icons.check_circle : Icons.check_circle_outline),
                                color: verdict == true ? Colors.green : null,
                                onPressed: () => send(RateAnswer(team.id, correct: verdict == true ? null : true)),
                              ),
                              IconButton(
                                tooltip: "Wrong",
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
          }),
        if (connections)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FilledButton.icon(
              onPressed: () => send(const AwardConnections()),
              icon: const Icon(Icons.emoji_events_outlined),
              label: Text(
                "Give points: "
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
