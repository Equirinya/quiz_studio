import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/pages/game_editor_page.dart' show BoardTypeIcon;
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/game/game.dart';

/// The gamemaster's remote: everything that drives a running show.
///
/// It only ever sends commands. What it shows comes back from the presenting
/// device, so two controllers can never disagree about the state.
class ControllerView extends StatefulWidget {
  const ControllerView({super.key, required this.connection, this.games});

  final SessionConnection connection;

  /// The games to offer; the signed-in user's when left out.
  final Stream<List<GameSummary>>? games;

  @override
  State<ControllerView> createState() => _ControllerViewState();
}

class _ControllerViewState extends State<ControllerView> {
  /// The question tapped once on the board: shown to the gamemaster, opened
  /// for everyone on the second tap.
  QuestionRef? _preview;

  late final Stream<List<GameSummary>> _games = widget.games ?? GameRepository.instance.watchMyGames();

  SessionConnection get _c => widget.connection;

  void _send(Command command) => _c.send(command);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_c.state, _c.game]),
      builder: (context, _) {
        final state = _c.state.value;
        if (state == null) return const Center(child: CupertinoActivityIndicator());
        final game = _c.game.value;
        final question = state.current == null ? null : game?.question(state.current!);
        final previewed = _preview == null ? null : game?.question(_preview!);
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
          children: [
            _gamePicker(state),
            const SizedBox(height: 12),
            _TeamsBar(state: state, send: _send),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text("Queue buzzers"),
              subtitle: const Text("Later buzzes line up behind the first"),
              value: state.queueBuzzers,
              onChanged: (value) => _send(SetQueueBuzzers(value)),
            ),
            if (game == null)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: Text("Pick a game to play.")))
            else ...[
              _groupPicker(state, game),
              const SizedBox(height: 8),
              _board(state, game),
              const SizedBox(height: 16),
              if (question != null || previewed != null) _QuestionSheet(question: (question ?? previewed)!, state: state, live: question != null),
              const SizedBox(height: 12),
              _Actions(state: state, game: game, question: question, send: _send),
            ],
          ],
        );
      },
    );
  }

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
              if (sure) {
                setState(() => _preview = null);
                _send(SetGame(gameId));
              } else {
                setState(() {});
              }
            },
          );
        },
      );

  Widget _groupPicker(SessionState state, GameContent game) {
    if (game.groups.length < 2) return const SizedBox();
    final selected = game.group(state.groupId) ?? game.groups.first;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<String>(
        segments: [
          for (final group in game.groups)
            ButtonSegment(
              value: group.id,
              icon: Icon(group.type.icon),
              label: Text(group.isUngrouped ? "Ungrouped" : group.name),
            ),
        ],
        selected: {selected.id},
        // The board cannot change under an open question.
        onSelectionChanged: state.current != null
            ? null
            : (ids) {
                setState(() => _preview = null);
                _send(SelectGroup(ids.first));
              },
      ),
    );
  }

  Widget _board(SessionState state, GameContent game) {
    final scheme = Theme.of(context).colorScheme;
    final group = game.group(state.groupId) ?? game.groups.firstOrNull;
    if (group == null || group.categories.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: Text("This group has no categories.")));
    }
    return Row(
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
                    child: Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  ),
                  for (final question in category.questions)
                    Builder(builder: (context) {
                      final ref = QuestionRef(category.id, question.id);
                      final open = state.current == ref;
                      final played = state.played.contains(ref.key);
                      final previewing = _preview == ref;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.all(8),
                            backgroundColor: open
                                ? scheme.primary
                                : played
                                    ? scheme.surfaceContainerLow
                                    : previewing
                                        ? scheme.tertiaryContainer
                                        : scheme.surfaceContainerHighest,
                            foregroundColor: open
                                ? scheme.onPrimary
                                : played
                                    ? scheme.outline
                                    : scheme.onSurface,
                          ),
                          onPressed: () {
                            if (open) {
                              // Opened by mistake: back to the board, still playable.
                              _send(const CloseQuestion(markPlayed: false));
                            } else if (played) {
                              _send(UnmarkPlayed(ref));
                            } else if (!previewing) {
                              setState(() => _preview = ref);
                            } else {
                              setState(() => _preview = null);
                              _send(OpenQuestion(ref));
                            }
                          },
                          child: Text(question.pointsPlus.toString()),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TeamsBar extends StatelessWidget {
  const _TeamsBar({required this.state, required this.send});

  final SessionState state;
  final void Function(Command) send;

  Future<void> _add(BuildContext context) async {
    final name = await promptText(context, title: "New team", label: "Name");
    if (name != null) send(AddTeam(newTeamId(), name));
  }

  Future<void> _edit(BuildContext context, Team team) async {
    final points = TextEditingController(text: team.points.toString());
    final name = TextEditingController(text: team.name);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit team"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: "Name")),
            const SizedBox(height: 12),
            TextField(
              controller: points,
              decoration: const InputDecoration(labelText: "Points"),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final sure = await confirm(context, title: "Remove team", message: "${team.name} and its points are removed.", action: "Remove");
              if (!sure) return;
              send(RemoveTeam(team.id));
              navigator.pop();
            },
            child: const Text("Remove team"),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim() != team.name) send(RenameTeam(team.id, name.text));
              final value = int.tryParse(points.text.trim());
              if (value != null && value != team.points) send(SetPoints(team.id, value));
              Navigator.of(context).pop();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final team in state.teams)
          Card(
            margin: EdgeInsets.zero,
            color: state.buzzQueue.firstOrNull == team.id
                ? theme.colorScheme.primaryContainer
                : state.buzzQueue.contains(team.id)
                    ? theme.colorScheme.secondaryContainer
                    : null,
            child: InkWell(
              onTap: () => _edit(context, team),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(team.name, style: theme.textTheme.bodySmall),
                        Text(team.points.toString(), style: theme.textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(onPressed: () => send(AdjustPoints(team.id, 100)), child: const Text("+100")),
                        TextButton(onPressed: () => send(AdjustPoints(team.id, -100)), child: const Text("−100")),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ActionChip(avatar: const Icon(Icons.add), label: const Text("Team"), onPressed: () => _add(context)),
      ],
    );
  }
}

/// The question as the gamemaster sees it: everything, including the answer
/// hint and what is not revealed yet.
class _QuestionSheet extends StatelessWidget {
  const _QuestionSheet({required this.question, required this.state, required this.live});

  final Question question;
  final SessionState state;

  /// False while it is only previewed and not on the big screen yet.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline);
    final revealed = live ? state.revealed : 0;
    return Card(
      margin: EdgeInsets.zero,
      color: live ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${live ? "On screen" : "Preview · tap again to open"} · ${question.type.uiString} · +${question.pointsPlus} / −${question.pointsMinus}",
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Text(question.text, style: theme.textTheme.titleMedium),
            if (question.answerHint != null) ...[
              const SizedBox(height: 8),
              Text(question.answerHint!, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
            ],
            if (question.type == QuestionType.abcd)
              for (final (i, answer) in question.answers.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        question.answersCorrect.elementAtOrNull(i) == true ? Icons.check : Icons.close,
                        size: 18,
                        color: revealed > question.answers.length ? null : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text("${String.fromCharCode(0x41 + i)}  $answer", style: i < revealed ? null : muted),
                      ),
                    ],
                  ),
                ),
            if (question.type == QuestionType.progressingReveal)
              for (final (i, information) in question.information.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "${i + 1}. $information${state.imageFocus == i + 1 && live ? "  · enlarged" : ""}",
                    style: i < revealed ? null : muted,
                  ),
                ),
            if (!question.buzzerable)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text("Buzzers are disabled for this question.", style: muted)),
          ],
        ),
      ),
    );
  }
}

/// Every button that depends on the phase and the open question.
class _Actions extends StatelessWidget {
  const _Actions({required this.state, required this.game, required this.question, required this.send});

  final SessionState state;
  final GameContent game;
  final Question? question;
  final void Function(Command) send;

  Widget _button(String label, IconData icon, Command? command, {Color? color, Color? onColor}) => FilledButton.tonalIcon(
        style: color == null ? null : FilledButton.styleFrom(backgroundColor: color, foregroundColor: onColor),
        onPressed: command == null ? null : () => send(command),
        icon: Icon(icon),
        label: Text(label),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final q = question;
    final phase = state.phase;
    final answering = phase == Phase.buzzered;
    final listening = phase == Phase.question || answering;
    final sounds = game.soundsFor(ref: state.current, groupId: state.groupId);
    Widget header(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
        );
    Widget row(List<Widget> children) => Wrap(spacing: 8, runSpacing: 8, children: children);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row([
          if (phase == Phase.overview) _button("Buzzer test", Icons.tune, const SetBuzzerTest(true)),
          if (phase == Phase.buzzerTest) _button("Stop buzzer test", Icons.stop, const SetBuzzerTest(false)),
          if (answering && q != null && q.defaultJudging) ...[
            _button("Right", Icons.check, const Judge(correct: true),
                color: Colors.green.shade700, onColor: Colors.white),
            _button("Wrong", Icons.close, const Judge(correct: false),
                color: scheme.errorContainer, onColor: scheme.onErrorContainer),
          ],
          if (answering && state.buzzQueue.length > 1) _button("Next buzzer", Icons.skip_next, const SkipBuzzer()),
          if (answering) _button("Reopen", Icons.undo, const ReopenQuestion()),
          if (state.current != null) _button("Close question", Icons.close_fullscreen, const CloseQuestion()),
        ]),
        if (q != null && buzzersOpen(state, game)) ...[
          header("Buzz for a team"),
          row([
            for (final team in state.teams)
              if (canBuzz(state, game, team.id)) _button(team.name, Icons.touch_app_outlined, Buzz(team.id)),
          ]),
        ],
        if (q != null && q.maxReveal > 0) ...[
          header("Reveal"),
          row([
            _button("Back", Icons.navigate_before, state.revealed > 0 ? const Reveal(-1) : null),
            _button(
              state.revealed == q.maxReveal - 1 && q.type == QuestionType.abcd ? "Show solution" : "Reveal next",
              Icons.navigate_next,
              state.revealed < q.maxReveal ? const Reveal(1) : null,
            ),
            if (q.type == QuestionType.progressingReveal && q.hasInformationImages) ...[
              _button("Image back", Icons.photo_size_select_large, state.imageFocus > 0 ? const ImageFocus(-1) : null),
              _button("Image next", Icons.photo_size_select_actual_outlined,
                  state.imageFocus < state.revealed ? const ImageFocus(1) : null),
            ],
          ]),
        ],
        if (q != null && q.type == QuestionType.feud) ...[
          header("Answers · ${"✕" * state.wrongAttempts}${state.wrongAttempts == 0 ? "no strikes" : ""}"),
          if (!answering && phase != Phase.answerRevealed)
            Text("A team has to buzz before answers can be uncovered.", style: theme.textTheme.bodySmall),
          row([
            for (final (i, answer) in q.information.indexed)
              FilterChip(
                label: Text("${_feudValue(q, i)}  $answer"),
                selected: state.feudRevealed.contains(i),
                onSelected: answering ? (_) => send(FeudToggle(i)) : null,
              ),
          ]),
          const SizedBox(height: 8),
          row([
            if (answering && state.wrongAttempts < 3)
              _button(state.wrongAttempts == 2 ? "Wrong · other team may steal" : "Wrong answer", Icons.close, const FeudWrong()),
            if (answering && state.wrongAttempts >= 3) ...[
              _button("Steal succeeded", Icons.check, const FeudSteal(success: true)),
              _button("Steal failed", Icons.close, const FeudSteal(success: false)),
            ],
            if (answering && state.wrongAttempts > 0) _button("Reset strikes", Icons.refresh, const FeudResetWrong()),
          ]),
        ],
        if (q != null && q.hasMusic && listening) ...[
          header("Question sound"),
          row([
            if (state.media != MediaPlayback.playing)
              _button("Play", Icons.play_circle_outline, const SetMedia(MediaPlayback.playing)),
            if (state.media == MediaPlayback.playing)
              _button("Pause", Icons.pause_circle_outline, const SetMedia(MediaPlayback.paused)),
            if (state.media != MediaPlayback.stopped)
              _button("Stop", Icons.stop_circle_outlined, const SetMedia(MediaPlayback.stopped)),
          ]),
        ],
        if (state.current != null) ...[
          header("Answers from players' devices"),
          _AnswerRound(state: state, send: send, choices: q?.type == QuestionType.abcd),
        ],
        if (sounds.slots.isNotEmpty) ...[
          header("Music"),
          row([
            for (final slot in musicSlots)
              if (sounds.slots.containsKey(slot))
                FilterChip(
                  label: Text(_slotNames[slot]!),
                  selected: state.music == slot,
                  onSelected: (on) => send(SetMusic(on ? slot : null)),
                ),
          ]),
        ],
        if (sounds.effects.isNotEmpty) ...[
          header("Effects"),
          row([
            for (final key in sounds.effects.keys)
              ActionChip(
                avatar: const Icon(Icons.volume_up_outlined, size: 18),
                label: Text(_effectNames[key] ?? key),
                onPressed: () => send(PlayEffect(key)),
              ),
          ]),
        ],
      ],
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

String _feudValue(Question question, int index) {
  final value = question.percentages.elementAtOrNull(index) ?? 0;
  final text = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  return question.absoluteValues ? text : "$text%";
}

class _AnswerRound extends StatelessWidget {
  const _AnswerRound({required this.state, required this.send, required this.choices});

  final SessionState state;
  final void Function(Command) send;

  /// Whether the open question has options to choose from.
  final bool choices;

  @override
  Widget build(BuildContext context) {
    final round = state.answerRound;
    if (round == null) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.short_text, size: 18),
            label: const Text("Collect text"),
            onPressed: () => send(const OpenAnswers(AnswerKind.text)),
          ),
          ActionChip(
            avatar: const Icon(Icons.draw_outlined, size: 18),
            label: const Text("Collect drawings"),
            onPressed: () => send(const OpenAnswers(AnswerKind.drawing)),
          ),
          if (choices)
            ActionChip(
              avatar: const Icon(Icons.checklist, size: 18),
              label: const Text("Collect choices"),
              onPressed: () => send(const OpenAnswers(AnswerKind.choice)),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final team in state.teams)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(round.answers.containsKey(team.id) ? Icons.check_circle : Icons.hourglass_empty),
            title: Text(team.name),
            subtitle: Text(_describe(round.answers[team.id])),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (round.open) ActionChip(label: const Text("Lock"), onPressed: () => send(const LockAnswers())),
            if (!round.revealed) ActionChip(label: const Text("Show on screen"), onPressed: () => send(const RevealAnswers())),
            ActionChip(label: const Text("Discard"), onPressed: () => send(const ClearAnswers())),
          ],
        ),
      ],
    );
  }

  static String _describe(PlayerAnswer? answer) {
    if (answer == null) return "Nothing yet";
    if (answer.text != null) return answer.text!;
    if (answer.choice != null) return "Chose ${String.fromCharCode(0x41 + answer.choice!)}";
    return "Sent a drawing";
  }
}
