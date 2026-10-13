import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/pages/game_editor_page.dart';

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
    final name = await promptText(context, title: "New game", label: "Name");
    if (name == null || !mounted) return;
    await guarded(context, () async {
      final id = await GameRepository.instance.createGame(name: name);
      if (mounted) _open(id);
    }, failure: "Could not create the game.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text("New game"),
      ),
      body: StreamBuilder<List<GameSummary>>(
        stream: _games,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Could not load your games."));
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
                    Text("No games yet", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                      "Create your first quiz, or ask a friend to invite you to theirs.",
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
                title: Text(game.name.isEmpty ? "Unnamed" : game.name),
                subtitle: Text(game.role.uiString),
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
