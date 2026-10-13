import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/pages/game_editor_page.dart' show BoardTypeIcon;
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/features/session/session_repository.dart';
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
  const ControllerView({super.key, required this.connection, this.games, this.onConnectDevices, this.onBuzzerSetup});

  final SessionConnection connection;

  /// The games to offer; the signed-in user's when left out.
  final Stream<List<GameSummary>>? games;

  /// Opens the screen with the join codes; hidden when null.
  final VoidCallback? onConnectDevices;

  /// Opens the setup of the USB buzzer box; hidden when null.
  final VoidCallback? onBuzzerSetup;

  @override
  State<ControllerView> createState() => _ControllerViewState();
}

class _ControllerViewState extends State<ControllerView> {
  late final Stream<List<GameSummary>> _games =
      (widget.games ?? GameRepository.instance.watchMyGames()).asBroadcastStream();

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
                child: _NowPanel(state: state, game: game, question: question, send: _send),
              ),
            ),
            const Divider(height: 1),
            _ActionPad(state: state, game: game, question: question, send: _send),
            _SheetRow(
              boardSuggested: game != null && state.current == null && state.phase != Phase.buzzerTest,
              answersActive: state.answerRound != null,
              musicActive: state.music != null,
              onBoard: game == null ? _openSetup : _openBoard,
              onSounds: _openSounds,
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
            const SizedBox(height: 12),
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
      ? const SizedBox(height: 120, child: Center(child: Text("Pick a game first.")))
      : _BoardSheet(state: state, game: game, send: _send));

  void _openSounds() => _sheet((context, state, game) => _SoundsSheet(state: state, game: game, send: _send));

  void _openAnswers() => _sheet((context, state, game) => _AnswersSheet(state: state, game: game, send: _send));

  void _openSetup() => _sheet((context, state, game) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _gamePicker(state),
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
                  title: const Text("USB buzzers"),
                  subtitle: const Text("Port, sensitivity and teams"),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onBuzzerSetup!();
                  },
                ),
            ],
          ),
        );
      });

  Widget _gamePicker(SessionState state) => StreamBuilder<List<GameSummary>>(
        stream: _games,
        builder: (context, snapshot) {
          final games = (snapshot.data ?? const <GameSummary>[]).where((g) => g.role.seesEverything).toList();
          return DropdownMenu<String>(
            key: ValueKey('${state.gameId}/${games.length}'),
            expandedInsets: EdgeInsets.zero,
            label: const Text("Game"),
            leadingIcon: const Icon(Icons.quiz_outlined),
            initialSelection: games.any((g) => g.id == state.gameId) ? state.gameId : null,
            dropdownMenuEntries: [for (final game in games) DropdownMenuEntry(value: game.id, label: game.name)],
            onSelected: (gameId) async {
              if (gameId == null || gameId == state.gameId) return;
              final sure = state.played.isEmpty && state.current == null ||
                  await confirm(
                    context,
                    title: "Switch game",
                    message: "The board starts over. Teams and points stay.",
                    action: "Switch",
                  );
              if (sure) _send(SetGame(gameId));
            },
          );
        },
      );
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
      return question?.buzzerable == false ? "Question open · no buzzers" : "Question open · waiting for a buzz";
    case Phase.buzzered:
      final next = state.buzzQueue.skip(1).map(name).join(", ");
      return "${name(state.buzzQueue.first)} is answering${next.isEmpty ? "" : " · then $next"}";
    case Phase.answerRevealed:
      return "Answer revealed";
  }
}

class _NowPanel extends StatelessWidget {
  const _NowPanel({required this.state, required this.game, required this.question, required this.send});

  final SessionState state;
  final GameContent? game;
  final Question? question;
  final void Function(Command) send;

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
        children: [status, const SizedBox(height: 24), const Center(child: Text("No game picked yet. Open Setup below."))],
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
        if (round != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "Answers: ${round.answers.length} of ${state.teams.length} in${round.revealed ? " · on screen" : round.open ? "" : " · locked"}",
              style: theme.textTheme.labelLarge,
            ),
          ),
        const SizedBox(height: 8),
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
    final Command? right = !answering || q == null
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
    final canReveal = q != null && q.maxReveal > 0 && state.current != null;
    final Command? back = canReveal && state.revealed > 0 ? const Reveal(-1) : null;
    final Command? next = canReveal && state.revealed < q.maxReveal ? const Reveal(1) : null;
    final playing = state.media == MediaPlayback.playing;
    final Command? sound = q != null && q.hasMusic && listening
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
    Widget small(String label, IconData icon, Command? command) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              height: 52,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: command == null ? null : () => send(command),
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
                q?.type == QuestionType.abcd && state.revealed == q!.answers.length ? "Solution" : "Reveal",
                Icons.navigate_next,
                next,
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
    required this.musicActive,
    required this.onBoard,
    required this.onSounds,
    required this.onAnswers,
    required this.onSetup,
  });

  /// Nothing is open: picking a question is the next thing to do.
  final bool boardSuggested;
  final bool answersActive;
  final bool musicActive;
  final VoidCallback onBoard;
  final VoidCallback onSounds;
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
          tab("Sounds", Icons.music_note_outlined, onSounds, dot: musicActive),
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
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  category.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelMedium,
                                ),
                              ),
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
          // The preview keeps its height, so the button below never jumps.
          Container(
            height: 112,
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

const Map<String, String> _slotNames = {musicBackground: "Background", musicCalm: "Calm", musicExciting: "Exciting"};

const Map<String, String> _effectNames = {
  effectAnswerCorrect: "Right",
  effectAnswerWrong: "Wrong",
  effectAnswerClosed: "Closed",
  effectReveal: "Reveal",
};

class _SoundsSheet extends StatelessWidget {
  const _SoundsSheet({required this.state, required this.game, required this.send});

  final SessionState state;
  final GameContent? game;
  final void Function(Command) send;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sounds = game?.soundsFor(ref: state.current, groupId: state.groupId) ?? MusicConfig.empty;
    final question = state.current == null ? null : game?.question(state.current!);
    final listening = state.phase == Phase.question || state.phase == Phase.buzzered;
    Widget header(String text) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header("Music"),
          if (sounds.slots.isEmpty) const Text("This game has no music. Add some in the editor."),
          Wrap(
            spacing: 8,
            children: [
              for (final slot in musicSlots)
                if (sounds.slots.containsKey(slot))
                  FilterChip(
                    label: Text(_slotNames[slot]!),
                    selected: state.music == slot,
                    onSelected: (on) => send(SetMusic(on ? slot : null)),
                  ),
            ],
          ),
          header("Effects"),
          if (sounds.effects.isEmpty) const Text("This game has no sound effects."),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
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

/// Answers typed, chosen or drawn on the players' own devices.
class _AnswersSheet extends StatelessWidget {
  const _AnswersSheet({required this.state, required this.game, required this.send});

  final SessionState state;
  final GameContent? game;
  final void Function(Command) send;

  static String _describe(PlayerAnswer? answer) {
    if (answer == null) return "Nothing yet";
    if (answer.text != null) return answer.text!;
    if (answer.choice != null) return "Chose ${String.fromCharCode(0x41 + answer.choice!)}";
    return "Sent a drawing";
  }

  @override
  Widget build(BuildContext context) {
    final round = state.answerRound;
    final question = state.current == null ? null : game?.question(state.current!);
    Widget action(String label, IconData icon, Command? command) => Padding(
          padding: const EdgeInsets.only(right: 8, top: 8),
          child: FilledButton.tonalIcon(
            onPressed: command == null ? null : () => send(command),
            icon: Icon(icon),
            label: Text(label),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Answers from players' devices", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (state.current == null)
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text("Open a question first."))
          else if (round == null) ...[
            const Text("Every team answers on its own device. Nobody sees the answers until you show them."),
            Wrap(
              children: [
                action("Text", Icons.short_text, const OpenAnswers(AnswerKind.text)),
                action("Drawing", Icons.draw_outlined, const OpenAnswers(AnswerKind.drawing)),
                action("Choice", Icons.checklist, question?.type == QuestionType.abcd ? const OpenAnswers(AnswerKind.choice) : null),
              ],
            ),
          ] else ...[
            for (final team in state.teams)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(round.answers.containsKey(team.id) ? Icons.check_circle : Icons.hourglass_empty),
                title: Text(team.name),
                subtitle: Text(_describe(round.answers[team.id])),
              ),
            Wrap(
              children: [
                action("Lock", Icons.lock_outline, round.open ? const LockAnswers() : null),
                action("Show on screen", Icons.tv, round.revealed ? null : const RevealAnswers()),
                action("Discard", Icons.delete_outline, const ClearAnswers()),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
