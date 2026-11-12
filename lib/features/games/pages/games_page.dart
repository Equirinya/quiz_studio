import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/pages/game_access_page.dart';
import 'package:quiz_show/features/games/pages/game_editor_page.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// The user's games: open one to edit it, or create a new one.
class GamesPage extends StatefulWidget {
  const GamesPage({super.key});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  late final Stream<List<GameSummary>> _games = GameRepository.instance.watchMyGames();

  void _open(String gameId) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameEditorPage(gameId: gameId)));
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    final name = await promptText(context, title: l10n.newGame, label: l10n.name);
    if (name == null || !mounted) return;
    await guarded(context, () async {
      final id = await GameRepository.instance.createGame(name: name);
      if (mounted) _open(id);
    }, failure: l10n.couldNotCreateGame);
  }

  Future<void> _join() async {
    final gameId = await showJoinGameDialog(context);
    if (gameId != null && mounted) _open(gameId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'join',
            onPressed: _join,
            tooltip: context.l10n.joinWithInviteLink,
            child: const Icon(Icons.group_add_outlined),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.newGame),
          ),
        ],
      ),
      body: StreamBuilder<List<GameSummary>>(
        stream: _games,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(context.l10n.couldNotLoadGames));
          final games = snapshot.data;
          if (games == null) return const Center(child: CupertinoActivityIndicator());
          if (games.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.quiz_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(context.l10n.noGamesYet, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.noGamesYetText,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              return ListTile(
                leading: const Icon(Icons.quiz_outlined),
                title: Text(game.name.isEmpty ? context.l10n.unnamed : game.name),
                subtitle: Text(context.l10n.gameRole(game.role)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(game.id),
              );
            },
          );
        },
      ),
    );
  }
}
