import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/companion/answer_view.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/features/session/widgets/team_colors.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// Asks first, then starts [session] over with the same teams: points to 0,
/// nothing played, the kept answers gone.
Future<void> clearSessionData(BuildContext context, SessionSummary session) async {
  final sure = await confirm(
    context,
    title: context.l10n.clearSessionData,
    message: context.l10n.clearSessionDataText,
    action: context.l10n.clear,
  );
  if (!sure || !context.mounted) return;
  await guarded(context, () => SessionRepository.instance.clearSessionData(session));
}

/// What a session has stored: the teams' points, the questions played, and
/// what each team answered on them, as kept when they were closed.
class StoredDataPage extends StatefulWidget {
  const StoredDataPage({super.key, required this.session, required this.title});

  final SessionSummary session;
  final String title;

  @override
  State<StoredDataPage> createState() => _StoredDataPageState();
}

class _StoredDataPageState extends State<StoredDataPage> {
  late Future<_Stored> _stored = _load();

  Future<_Stored> _load() async {
    final repo = SessionRepository.instance;
    final gameId = widget.session.gameId;
    final (state, rounds, game) = await (
      FirestoreHostLink.loadState(widget.session.id),
      repo.loadRounds(widget.session.id).catchError((Object _) => <String, PlayedRound>{}),
      _game(gameId),
    ).wait;
    return (state: state, rounds: rounds, game: game);
  }

  static Future<GameContent?> _game(String? gameId) async {
    if (gameId == null) return null;
    try {
      return (await GameRepository.instance.watchGame(gameId).first.timeout(const Duration(seconds: 15))).content;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clear() async {
    await clearSessionData(context, widget.session);
    if (mounted) setState(() => _stored = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${context.l10n.storedData} · ${widget.title}", overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: context.l10n.clearSessionData,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clear,
          ),
        ],
      ),
      body: FutureBuilder<_Stored>(
        future: _stored,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(context.l10n.thatDidntWork));
          final stored = snapshot.data;
          if (stored == null) return const Center(child: CupertinoActivityIndicator());
          return StoredDataView(state: stored.state, rounds: stored.rounds, game: stored.game);
        },
      ),
    );
  }
}

typedef _Stored = ({SessionState state, Map<String, PlayedRound> rounds, GameContent? game});

/// The stored data itself; plain data in, so it shows without a backend.
class StoredDataView extends StatelessWidget {
  const StoredDataView({super.key, required this.state, required this.rounds, this.game});

  final SessionState state;
  final Map<String, PlayedRound> rounds;
  final GameContent? game;

  /// Played questions in the game's order; ones no longer in it last.
  List<QuestionRef> get _played {
    final keys = {...state.played, ...rounds.keys};
    final ordered = <QuestionRef>[
      for (final group in game?.groups ?? const <CategoryGroup>[])
        for (final category in group.categories)
          for (final question in category.questions)
            if (keys.contains('${category.id}/${question.id}')) QuestionRef(category.id, question.id),
    ];
    final known = {for (final ref in ordered) ref.key};
    return [
      ...ordered,
      for (final key in keys.toList()..sort())
        if (!known.contains(key)) ?QuestionRef.tryParse(key),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final played = _played;
    final teams = [...state.teams]..sort((a, b) => b.points.compareTo(a.points));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(context.l10n.teams, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final team in teams)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(radius: 8, backgroundColor: teamColor(team) ?? theme.colorScheme.primary),
            title: Text(team.name),
            trailing: Text("${team.points}", style: theme.textTheme.titleMedium),
          ),
        const SizedBox(height: 16),
        Text(context.l10n.playedQuestions, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        if (played.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(context.l10n.storedDataEmpty, style: TextStyle(color: theme.colorScheme.outline)),
          ),
        for (final ref in played) _PlayedTile(ref: ref, question: game?.question(ref), category: game?.category(ref.categoryId), round: rounds[ref.key], teams: state.teams),
      ],
    );
  }
}

class _PlayedTile extends StatelessWidget {
  const _PlayedTile({required this.ref, required this.question, required this.category, required this.round, required this.teams});

  final QuestionRef ref;
  final Question? question;
  final Category? category;
  final PlayedRound? round;
  final List<Team> teams;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final question = this.question;
    final round = this.round;
    final subtitle = [
      ?category?.name,
      if (question != null) "${question.boardPoints}",
      if (question == null) context.l10n.questionNoLongerInGame,
      if (round != null) context.l10n.answersKept,
    ].join(" · ");
    final title = Text(question?.text ?? ref.key, maxLines: 2, overflow: TextOverflow.ellipsis);
    if (round == null) {
      return ListTile(contentPadding: EdgeInsets.zero, title: title, subtitle: Text(subtitle));
    }
    final answers = round.answerRound;
    final shown = [
      for (final team in teams)
        if (answers?.answers.containsKey(team.id) == true ||
            round.results.verdicts.containsKey(team.id) ||
            round.results.given.containsKey(team.id) ||
            round.betting?.bets.containsKey(team.id) == true)
          team,
    ];
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: title,
      subtitle: Text(subtitle),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final team in shown)
          Card.outlined(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 6, backgroundColor: teamColor(team) ?? scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(team.name, style: theme.textTheme.titleSmall)),
                      switch (round.results.verdicts[team.id]) {
                        true => Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                        false => Icon(Icons.cancel, color: scheme.error, size: 20),
                        null => Text(context.l10n.notRated, style: theme.textTheme.labelMedium?.copyWith(color: scheme.outline)),
                      },
                      if (round.results.given[team.id] case final points?) ...[
                        const SizedBox(width: 8),
                        Text(points > 0 ? "+$points" : "$points", style: theme.textTheme.titleSmall),
                      ],
                    ],
                  ),
                  if (answers != null && answers.answers.containsKey(team.id)) ...[
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: answers.spec.kind == CompanionKind.whiteboard
                          ? AnswerView(spec: answers.spec, answer: answers.answers[team.id], fontSize: 16)
                          : SingleChildScrollView(
                              primary: false,
                              child: AnswerView(spec: answers.spec, answer: answers.answers[team.id], fontSize: 16),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
