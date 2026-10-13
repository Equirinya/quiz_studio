import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/pages/category_editor_page.dart';
import 'package:quiz_show/features/games/pages/game_access_page.dart';
import 'package:quiz_show/features/games/pages/map_editor_page.dart';
import 'package:quiz_show/features/games/widgets/cards_dialog.dart';
import 'package:quiz_show/features/games/widgets/group_colors_dialog.dart';
import 'package:quiz_show/features/games/widgets/sounds_dialog.dart';
import 'package:quiz_show/game/game.dart';

extension BoardTypeIcon on BoardType {
  IconData get icon => switch (this) {
        BoardType.display => Icons.art_track_rounded,
        BoardType.wheel => Icons.pie_chart_outline,
        BoardType.map => Icons.route,
      };
}

/// The structure of one game: its category groups and their categories.
/// Questions are edited one level down, in [CategoryEditorPage].
class GameEditorPage extends StatefulWidget {
  const GameEditorPage({super.key, required this.gameId});

  final String gameId;

  @override
  State<GameEditorPage> createState() => _GameEditorPageState();
}

class _GameEditorPageState extends State<GameEditorPage> {
  late final Stream<GameSnapshot> _game = GameRepository.instance.watchGame(widget.gameId);

  GameRepository get _repo => GameRepository.instance;

  Future<void> _rename(GameContent game) async {
    final name = await promptText(context, title: "Rename game", initial: game.name, label: "Name");
    if (name == null || !mounted) return;
    await guarded(context, () => _repo.updateGame(game.id, {'name': name}));
  }

  Future<void> _delete(GameContent game) async {
    final sure = await confirm(
      context,
      title: "Delete game",
      message: "\"${game.name}\" and all of its questions will be deleted for everyone.",
      action: "Delete",
    );
    if (!sure || !mounted) return;
    Navigator.of(context).pop();
    await _repo.deleteGame(game);
  }

  Future<void> _leave(GameContent game) async {
    final sure = await confirm(
      context,
      title: "Leave game",
      message: "You will lose access to \"${game.name}\" until someone invites you again.",
      action: "Leave",
    );
    if (!sure || !mounted) return;
    Navigator.of(context).pop();
    await _repo.leaveGame(game.id);
  }

  void _reorderGroups(GameContent game, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final ids = [for (final group in game.groups) group.id];
    // The ungrouped categories always stay on top and have no document.
    final pinned = game.groups.isNotEmpty && game.groups.first.isUngrouped ? 1 : 0;
    if (oldIndex < pinned || newIndex < pinned) return;
    ids.insert(newIndex, ids.removeAt(oldIndex));
    guarded(context, () => _repo.reorderGroups(game.id, ids.sublist(pinned)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameSnapshot>(
      stream: _game,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text("This game is not available.")));
        }
        final data = snapshot.data;
        if (data == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CupertinoActivityIndicator()));
        }
        final game = data.content;
        final canEditStructure = data.role.seesEverything;
        return Scaffold(
          appBar: AppBar(
            title: Text(game.name.isEmpty ? "Unnamed" : game.name),
            actions: [
              if (canEditStructure)
                IconButton(
                  icon: const Icon(Icons.queue_music),
                  tooltip: "Music and effects",
                  onPressed: () => showSoundsDialog(
                    context,
                    gameId: game.id,
                    title: "Sounds for the whole game",
                    data: data.data,
                    save: (update) => guarded(context, () => _repo.updateGame(game.id, update)),
                  ),
                ),
              if (canEditStructure)
                IconButton(
                  icon: const Icon(Icons.article_outlined),
                  tooltip: "Cards to show on screen",
                  onPressed: () => showCardsDialog(
                    context,
                    gameId: game.id,
                    cards: game.cards,
                    save: (cards) => guarded(context, () => _repo.updateGame(game.id, {'cards': cards})),
                  ),
                ),
              if (canEditStructure)
                IconButton(icon: const Icon(Icons.edit_outlined), tooltip: "Rename", onPressed: () => _rename(game)),
              if (data.role == GameRole.admin)
                IconButton(
                  icon: const Icon(Icons.group_outlined),
                  tooltip: "Access",
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => GameAccessPage(gameId: game.id)),
                  ),
                ),
              if (data.role == GameRole.admin)
                IconButton(icon: const Icon(Icons.delete_outline), tooltip: "Delete game", onPressed: () => _delete(game))
              else
                IconButton(icon: const Icon(Icons.logout), tooltip: "Leave game", onPressed: () => _leave(game)),
            ],
          ),
          body: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
            buildDefaultDragHandles: false,
            itemCount: game.groups.length,
            // onReorderItem replaces this from Flutter 3.41 on; kept for older SDKs in CI.
            // ignore: deprecated_member_use
            onReorder: (oldIndex, newIndex) => _reorderGroups(game, oldIndex, newIndex),
            itemBuilder: (context, index) => _GroupCard(
              key: ValueKey(game.groups[index].id),
              game: game,
              group: game.groups[index],
              listIndex: index,
              canEditStructure: canEditStructure,
            ),
            footer: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canEditStructure)
                    for (final type in BoardType.values)
                      OutlinedButton.icon(
                        onPressed: () => guarded(
                          context,
                          () => _repo.addGroup(game.id, type, game.groups.where((g) => !g.isUngrouped).length),
                        ),
                        icon: Icon(type.icon),
                        label: Text("Add ${type.uiString}"),
                      )
                  else if (game.groups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text("Nothing here yet. Ask an admin to share a category with you.", textAlign: TextAlign.center),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    super.key,
    required this.game,
    required this.group,
    required this.listIndex,
    required this.canEditStructure,
  });

  final GameContent game;
  final CategoryGroup group;
  final int listIndex;
  final bool canEditStructure;

  GameRepository get _repo => GameRepository.instance;

  Future<void> _rename(BuildContext context) async {
    final name = await promptText(context, title: "Rename group", initial: group.name, label: "Name");
    if (name == null || !context.mounted) return;
    await guarded(context, () => _repo.updateGroup(game.id, group.id, {'name': name}));
  }

  Future<void> _editDisplayText(BuildContext context) async {
    final text = await promptText(context, title: "Display text", initial: group.text ?? '', label: "Shown on the board");
    if (text == null || !context.mounted) return;
    await guarded(context, () => _repo.updateGroup(game.id, group.id, {'text': text}));
  }

  Future<void> _addCategory(BuildContext context) async {
    await guarded(context, () async {
      final id = await _repo.addCategory(game.id, groupId: group.id, index: group.categories.length);
      if (context.mounted) _openCategory(context, id);
    });
  }

  void _openCategory(BuildContext context, String categoryId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CategoryEditorPage(gameId: game.id, categoryId: categoryId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editable = canEditStructure && !group.isUngrouped;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(group.type.icon, color: theme.colorScheme.onSurfaceVariant),
            title: Text(
              group.isUngrouped ? "Ungrouped categories" : (group.name.isEmpty ? "Unnamed" : group.name),
              style: theme.textTheme.titleMedium,
            ),
            subtitle: group.isUngrouped ? null : Text(group.type.uiString),
            onTap: editable ? () => _rename(context) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (editable)
                  IconButton(
                    icon: const Icon(Icons.queue_music),
                    tooltip: "Music and effects",
                    onPressed: () => showSoundsDialog(
                      context,
                      gameId: game.id,
                      title: "Sounds for this group",
                      data: group.data,
                      save: (update) => guarded(context, () => _repo.updateGroup(game.id, group.id, update)),
                    ),
                  ),
                if (editable)
                  IconButton(
                    icon: Icon(Icons.palette_outlined, color: group.color == null ? null : Color(group.color!)),
                    tooltip: "Board colours",
                    onPressed: () => showGroupColorsDialog(
                      context,
                      group: group,
                      save: (color, accent) => guarded(
                        context,
                        () => _repo.updateGroup(game.id, group.id, {'color': color, 'accentColor': accent}),
                      ),
                    ),
                  ),
                if (editable && group.categories.isEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: "Delete group",
                    onPressed: () => guarded(context, () => _repo.deleteGroup(game.id, group.id)),
                  ),
                if (editable)
                  ReorderableDragStartListener(
                    index: listIndex,
                    child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle)),
                  ),
              ],
            ),
          ),
          if (editable && group.type == BoardType.display)
            ListTile(
              dense: true,
              leading: const Icon(Icons.short_text),
              title: Text(group.text ?? "No display text"),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => _editDisplayText(context),
            ),
          if (editable && group.type == BoardType.wheel)
            SwitchListTile(
              dense: true,
              title: const Text("Split point fields when a value appears more than once"),
              value: group.splitPointFields,
              onChanged: (value) => guarded(context, () => _repo.updateGroup(game.id, group.id, {'splitPointFields': value})),
            ),
          if (editable && group.type == BoardType.map)
            ListTile(
              dense: true,
              leading: const Icon(Icons.open_with),
              title: const Text("Arrange the map"),
              subtitle: const Text("Place bubbles, connect them, add titles, pictures and lines"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MapEditorPage(gameId: game.id, groupId: group.id)),
              ),
            ),
          if (editable && group.type == BoardType.map)
            SwitchListTile(
              dense: true,
              title: const Text("Show each question's label instead of its points"),
              subtitle: const Text("Questions without a label still show their points"),
              value: mapShowsLabels(group),
              onChanged: (value) =>
                  guarded(context, () => _repo.updateGroup(game.id, group.id, {'mapLabels': value ? 'label' : 'points'})),
            ),
          for (final (index, category) in group.categories.indexed)
            _CategoryTile(
              game: game,
              group: group,
              category: category,
              index: index,
              canEditStructure: canEditStructure,
              onOpen: () => _openCategory(context, category.id),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: TextButton.icon(
                onPressed: () => _addCategory(context),
                icon: const Icon(Icons.add),
                label: const Text("Add category"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _CategoryAction { up, down, move, follows, delete }

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.game,
    required this.group,
    required this.category,
    required this.index,
    required this.canEditStructure,
    required this.onOpen,
  });

  final GameContent game;
  final CategoryGroup group;
  final Category category;
  final int index;
  final bool canEditStructure;
  final VoidCallback onOpen;

  GameRepository get _repo => GameRepository.instance;

  Future<void> _moveToGroup(BuildContext context) async {
    final target = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Move to group"),
        children: [
          for (final other in game.groups.where((g) => g.id != group.id && !g.isUngrouped))
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(other.id),
              child: Row(children: [Icon(other.type.icon), const SizedBox(width: 12), Expanded(child: Text(other.name))]),
            ),
        ],
      ),
    );
    if (target == null || !context.mounted) return;
    final end = game.group(target)?.categories.length ?? 0;
    await guarded(context, () => _repo.moveCategory(game, category.id, target, end));
  }

  /// Map boards: which bubble this category is drawn after. Several
  /// categories after the same one make a branch.
  Future<void> _chooseFollows(BuildContext context) async {
    const previous = '\u0000previous';
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text("\"${category.name}\" comes after"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(previous),
            child: const Text("The category before it (default)"),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text("Nothing: it starts a new chain"),
          ),
          for (final other in group.categories.where((c) => c.id != category.id))
            SimpleDialogOption(onPressed: () => Navigator.of(context).pop(other.id), child: Text(other.name)),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    final layout = Map<String, dynamic>.from(group.data['mapLayout'] as Map? ?? const {});
    final follows = Map<String, dynamic>.from(layout['follows'] as Map? ?? const {});
    choice == previous ? follows.remove(category.id) : follows[category.id] = choice;
    layout['follows'] = follows;
    await guarded(context, () => _repo.updateGroup(game.id, group.id, {'mapLayout': layout}));
  }

  Future<void> _delete(BuildContext context) async {
    final sure = await confirm(
      context,
      title: "Delete category",
      message: "\"${category.name}\" and its ${category.questions.length} questions will be deleted.",
      action: "Delete",
    );
    if (!sure || !context.mounted) return;
    await guarded(context, () => _repo.deleteCategory(game.id, category));
  }

  @override
  Widget build(BuildContext context) {
    final questions = category.questions.length;
    final hasOtherGroups = game.groups.any((g) => g.id != group.id && !g.isUngrouped);
    return ListTile(
      leading: Checkbox(
        value: category.active,
        onChanged: (value) => guarded(context, () => _repo.updateCategory(game.id, category.id, {'active': value ?? true})),
      ),
      title: Text(category.name.isEmpty ? "Unnamed" : category.name),
      subtitle: Text(
        "${questions == 1 ? "1 question" : "$questions questions"}${category.active ? "" : " · not in play"}",
      ),
      onTap: onOpen,
      trailing: PopupMenuButton<_CategoryAction>(
        onSelected: (action) {
          switch (action) {
            case _CategoryAction.up:
              guarded(context, () => _repo.moveCategory(game, category.id, group.id, index - 1));
            case _CategoryAction.down:
              guarded(context, () => _repo.moveCategory(game, category.id, group.id, index + 1));
            case _CategoryAction.move:
              _moveToGroup(context);
            case _CategoryAction.follows:
              _chooseFollows(context);
            case _CategoryAction.delete:
              _delete(context);
          }
        },
        itemBuilder: (context) => [
          if (canEditStructure && index > 0) const PopupMenuItem(value: _CategoryAction.up, child: Text("Move up")),
          if (canEditStructure && index < group.categories.length - 1)
            const PopupMenuItem(value: _CategoryAction.down, child: Text("Move down")),
          if (canEditStructure && hasOtherGroups)
            const PopupMenuItem(value: _CategoryAction.move, child: Text("Move to group…")),
          if (canEditStructure && group.type == BoardType.map && group.categories.length > 1)
            const PopupMenuItem(value: _CategoryAction.follows, child: Text("Comes after…")),
          const PopupMenuItem(value: _CategoryAction.delete, child: Text("Delete")),
        ],
      ),
    );
  }
}
