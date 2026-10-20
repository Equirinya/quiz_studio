import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/pages/category_editor_page.dart';
import 'package:quiz_show/features/games/pages/game_access_page.dart';
import 'package:quiz_show/features/games/pages/map_editor_page.dart';
import 'package:quiz_show/features/games/widgets/cards_dialog.dart';
import 'package:quiz_show/features/games/widgets/group_colors_dialog.dart';
import 'package:quiz_show/features/games/widgets/settings_strip.dart';
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameSnapshot>(
      stream: _game,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text("This game is not available.")),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CupertinoActivityIndicator()),
          );
        }
        return GameEditorView(snapshot: data);
      },
    );
  }
}

/// [GameEditorPage] once the game is loaded: the game's own settings as
/// labelled tiles, then its boards with their categories.
class GameEditorView extends StatefulWidget {
  const GameEditorView({super.key, required this.snapshot});

  final GameSnapshot snapshot;

  @override
  State<GameEditorView> createState() => _GameEditorViewState();
}

class _GameEditorViewState extends State<GameEditorView> {
  GameRepository get _repo => GameRepository.instance;

  /// Everything in the game, answers included, for pasting elsewhere.
  Future<void> _copyAsText(GameContent game) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: gameAsText(game)));
    messenger.showSnackBar(const SnackBar(content: Text("Copied the game with its answers.")));
  }

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
    final data = widget.snapshot;
    final game = data.content;
    final canEditStructure = data.role.seesEverything;
    final settings = [
      if (canEditStructure)
        SettingTile(
          icon: Icons.queue_music,
          title: "Music & sounds",
          summary: soundsSummary(game.sounds, inherited: "None yet"),
          isSet: game.sounds.slots.isNotEmpty || game.sounds.effects.isNotEmpty,
          onTap: () => showSoundsDialog(
            context,
            gameId: game.id,
            title: "Sounds for the whole game",
            isGame: true,
            data: data.data,
            save: (update) => guarded(context, () => _repo.updateGame(game.id, update)),
          ),
        ),
      if (canEditStructure)
        SettingTile(
          icon: Icons.style_outlined,
          title: "Cards",
          summary: cardsSummary(game.cards),
          isSet: CueCard.listFrom(data.data['cards']).isNotEmpty,
          onTap: () => showCardsDialog(
            context,
            gameId: game.id,
            title: "Cards for the whole game",
            cards: game.cards,
            save: (cards) => guarded(context, () => _repo.updateGame(game.id, {'cards': cards})),
          ),
        ),
      if (data.role == GameRole.admin)
        SettingTile(
          icon: Icons.group_outlined,
          title: "People",
          summary: _peopleSummary(data.data),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameAccessPage(gameId: game.id))),
        ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(game.name.isEmpty ? "Unnamed" : game.name),
        actions: [
          // The rarely needed ones, so the title keeps its room on a phone.
          PopupMenuButton<VoidCallback>(
            tooltip: "More",
            onSelected: (action) => action(),
            itemBuilder: (context) => [
              if (canEditStructure)
                PopupMenuItem(
                  value: () => _rename(game),
                  child: const ListTile(leading: Icon(Icons.edit_outlined), title: Text("Rename")),
                ),
              PopupMenuItem(
                value: () => _copyAsText(game),
                child: const ListTile(leading: Icon(Icons.copy_all_outlined), title: Text("Copy as text")),
              ),
              if (data.role == GameRole.admin)
                PopupMenuItem(
                  value: () => _delete(game),
                  child: const ListTile(leading: Icon(Icons.delete_outline), title: Text("Delete game")),
                )
              else
                PopupMenuItem(
                  value: () => _leave(game),
                  child: const ListTile(leading: Icon(Icons.logout), title: Text("Leave game")),
                ),
            ],
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        buildDefaultDragHandles: false,
        header: settings.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: SettingsStrip(tiles: settings),
              ),
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
                    onPressed: () => guarded(context, () => _repo.addGroup(game.id, type, game.groups.where((g) => !g.isUngrouped).length)),
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
  }

  static String _peopleSummary(Map<String, dynamic> game) {
    int count(String key) => game[key] is List ? (game[key] as List).length : 0;
    final total = count('admin') + count('full') + count('limited');
    return total == 1 ? "Only you" : "$total members";
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({super.key, required this.game, required this.group, required this.listIndex, required this.canEditStructure});

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

  /// "Wheel · 3 categories · own music · 2 cards"
  String get _summary {
    final count = group.categories.length;
    return [
      group.type.uiString,
      count == 1 ? "1 category" : "$count categories",
      if (group.sounds.slots.isNotEmpty || group.sounds.effects.isNotEmpty) "own sounds",
      if (group.cards.isNotEmpty) group.cards.length == 1 ? "1 card" : "${group.cards.length} cards",
    ].join(" · ");
  }

  void _arrangeMap(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MapEditorPage(gameId: game.id, groupId: group.id),
    ),
  );

  void _update(BuildContext context, Map<String, dynamic> data) => guarded(context, () => _repo.updateGroup(game.id, group.id, data));

  /// Everything about this board in one list, each with what is set now.
  Future<void> _openSettings(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      // The sheet keeps the board as it was opened; switches remember
      // their own state until the list below catches up.
      var splitFields = group.splitPointFields;
      var mapLabels = mapShowsLabels(group);
      void close() => Navigator.of(sheet).pop();
      return StatefulBuilder(
        builder: (sheet, setSheet) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text("${group.name.isEmpty ? "Unnamed" : group.name} · ${group.type.uiString}", style: theme.textTheme.titleLarge),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text("Name"),
              subtitle: Text(group.name.isEmpty ? "Unnamed" : group.name),
              onTap: () {
                close();
                _rename(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text("Music & sounds"),
              subtitle: Text(soundsSummary(group.sounds, inherited: "Uses the game's")),
              onTap: () {
                close();
                showSoundsDialog(
                  context,
                  gameId: game.id,
                  title: "Sounds for this board",
                  data: group.data,
                  save: (update) => _update(context, update),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: const Text("Cards"),
              subtitle: Text(cardsSummary(group.cards, none: "Only the game's")),
              onTap: () {
                close();
                showCardsDialog(
                  context,
                  gameId: game.id,
                  title: "Cards for this board",
                  cards: group.cards,
                  save: (cards) => _update(context, {'cards': cards}),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.palette_outlined, color: group.color == null ? null : Color(group.color!)),
              title: const Text("Colours"),
              subtitle: Text(group.color == null ? "The app's colours" : "Own colours"),
              onTap: () {
                close();
                showGroupColorsDialog(
                  context,
                  group: group,
                  save: (color, accent) => _update(context, {'color': color, 'accentColor': accent}),
                );
              },
            ),
            if (group.type == BoardType.display)
              ListTile(
                leading: const Icon(Icons.short_text),
                title: const Text("Text on the board"),
                subtitle: Text((group.text ?? '').isEmpty ? "None" : group.text!, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () {
                  close();
                  _editDisplayText(context);
                },
              ),
            if (group.type == BoardType.wheel)
              SwitchListTile(
                secondary: const Icon(Icons.call_split),
                title: const Text("Split point fields"),
                subtitle: const Text("When a value appears more than once in a ring"),
                value: splitFields,
                onChanged: (value) {
                  setSheet(() => splitFields = value);
                  _update(context, {'splitPointFields': value});
                },
              ),
            if (group.type == BoardType.map) ...[
              ListTile(
                leading: const Icon(Icons.open_with),
                title: const Text("Arrange the map"),
                subtitle: const Text("Bubbles, arrows, titles, pictures and lines"),
                onTap: () {
                  close();
                  _arrangeMap(context);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.label_outline),
                title: const Text("Labels instead of points"),
                subtitle: const Text("Questions without a label still show their points"),
                value: mapLabels,
                onChanged: (value) {
                  setSheet(() => mapLabels = value);
                  _update(context, {'mapLabels': value ? 'label' : 'points'});
                },
              ),
            ],
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete_outline, color: group.categories.isEmpty ? theme.colorScheme.error : null),
              title: const Text("Delete board"),
              subtitle: group.categories.isEmpty ? null : const Text("Move or delete its categories first"),
              enabled: group.categories.isEmpty,
              onTap: () {
                close();
                guarded(context, () => _repo.deleteGroup(game.id, group.id));
              },
            ),
          ],
        ),
      );
    },
  );

  Future<void> _addCategory(BuildContext context) async {
    await guarded(context, () async {
      final id = await _repo.addCategory(game.id, groupId: group.id, index: group.categories.length);
      if (context.mounted) _openCategory(context, id);
    });
  }

  void _openCategory(BuildContext context, String categoryId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryEditorPage(gameId: game.id, categoryId: categoryId),
      ),
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
            leading: Icon(group.type.icon, color: group.color == null ? theme.colorScheme.onSurfaceVariant : Color(group.color!)),
            title: Text(
              group.isUngrouped ? "Ungrouped categories" : (group.name.isEmpty ? "Unnamed" : group.name),
              style: theme.textTheme.titleMedium,
            ),
            subtitle: group.isUngrouped ? null : Text(_summary),
            onTap: editable ? () => _openSettings(context) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Labelled where there is room; a phone gets the icon alone.
                if (editable && MediaQuery.sizeOf(context).width >= 600)
                  TextButton.icon(
                    onPressed: () => _openSettings(context),
                    icon: const Icon(Icons.tune),
                    label: const Text("Board settings"),
                  )
                else if (editable)
                  IconButton.filledTonal(
                    onPressed: () => _openSettings(context),
                    icon: const Icon(Icons.tune),
                    tooltip: "Board settings",
                  ),
                if (editable)
                  ReorderableDragStartListener(
                    index: listIndex,
                    child: const Tooltip(
                      message: "Move board",
                      child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle)),
                    ),
                  ),
              ],
            ),
          ),
          // Laid out by hand, so it stays one tap away.
          if (editable && group.type == BoardType.map)
            ListTile(
              dense: true,
              leading: const Icon(Icons.open_with),
              title: const Text("Arrange the map"),
              subtitle: const Text("Place bubbles, connect them, add titles, pictures and lines"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _arrangeMap(context),
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
          _CategoryDropZone(
            enabled: canEditStructure,
            onDrop: (dragged) =>
                guarded(context, () => _repo.moveCategory(game, dragged.id, group.id, _dropIndex(dragged, group, group.categories.length))),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => _addCategory(context),
                  icon: const Icon(Icons.add),
                  label: const Text("Add category"),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A category on its way to another place, on its board or another one.
class _DraggedCategory {
  const _DraggedCategory(this.id, this.groupId, this.index, this.name);

  final String id;
  final String groupId;
  final int index;
  final String name;
}

/// Where [dragged] ends up when dropped in front of place [before] of
/// [group]: on its own board it first leaves its old place.
int _dropIndex(_DraggedCategory dragged, CategoryGroup group, int before) =>
    dragged.groupId == group.id && dragged.index < before ? before - 1 : before;

/// Takes a dragged category; shows a line where it will land.
class _CategoryDropZone extends StatelessWidget {
  const _CategoryDropZone({required this.enabled, required this.onDrop, required this.child});

  final bool enabled;
  final void Function(_DraggedCategory dragged) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return DragTarget<_DraggedCategory>(
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(width: 3, color: candidates.isEmpty ? Colors.transparent : Theme.of(context).colorScheme.primary)),
        ),
        child: child,
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
        title: const Text("Move to another board"),
        children: [
          for (final other in game.groups.where((g) => g.id != group.id && !g.isUngrouped))
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(other.id),
              child: Row(
                children: [
                  Icon(other.type.icon),
                  const SizedBox(width: 12),
                  Expanded(child: Text(other.name)),
                ],
              ),
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
          SimpleDialogOption(onPressed: () => Navigator.of(context).pop(previous), child: const Text("The category before it (default)")),
          SimpleDialogOption(onPressed: () => Navigator.of(context).pop(''), child: const Text("Nothing: it starts a new chain")),
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
    final checkbox = Tooltip(
      message: category.active ? "In play: tap to take it out of the game" : "Not in play: tap to put it back",
      child: Checkbox(
        value: category.active,
        onChanged: (value) => guarded(context, () => _repo.updateCategory(game.id, category.id, {'active': value ?? true})),
      ),
    );
    final dragged = _DraggedCategory(category.id, group.id, index, category.name.isEmpty ? "Unnamed" : category.name);
    final tile = ListTile(
      // Grabbed by the handle and dropped on another place, on this board or
      // on another one.
      leading: !canEditStructure
          ? checkbox
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Draggable<_DraggedCategory>(
                  data: dragged,
                  feedback: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(dragged.name, style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Icon(Icons.drag_indicator, semanticLabel: "Move category", color: Theme.of(context).colorScheme.outline),
                  ),
                ),
                checkbox,
              ],
            ),
      title: Text(category.name.isEmpty ? "Unnamed" : category.name),
      subtitle: Text("${questions == 1 ? "1 question" : "$questions questions"}${category.active ? "" : " · not in play"}"),
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
          if (canEditStructure && index > 0) const PopupMenuItem(value: _CategoryAction.up, child: ListTile(leading: Icon(Icons.arrow_upward), title: Text("Move up"))),
          if (canEditStructure && index < group.categories.length - 1)
            const PopupMenuItem(value: _CategoryAction.down, child: ListTile(leading: Icon(Icons.arrow_downward), title: Text("Move down"))),
          if (canEditStructure && hasOtherGroups) const PopupMenuItem(value: _CategoryAction.move, child: ListTile(leading: Icon(Icons.drive_file_move_outlined), title: Text("Move to another board…"))),
          if (canEditStructure && group.type == BoardType.map && group.categories.length > 1)
            const PopupMenuItem(value: _CategoryAction.follows, child: ListTile(leading: Icon(Icons.account_tree_outlined), title: Text("Comes after…"))),
          const PopupMenuItem(value: _CategoryAction.delete, child: ListTile(leading: Icon(Icons.delete_outline), title: Text("Delete"))),
        ],
      ),
    );
    return _CategoryDropZone(
      enabled: canEditStructure,
      onDrop: (dropped) {
        if (dropped.id == category.id) return;
        guarded(context, () => _repo.moveCategory(game, dropped.id, group.id, _dropIndex(dropped, group, index)));
      },
      child: tile,
    );
  }
}
